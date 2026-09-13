#include "upscaler_bridge.h"
#include <android/log.h>
#include <cstring>
#include <algorithm>
#include <cmath>
#include <mutex>

#define LOG_TAG "UpscalerBridge"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#if HAVE_NCNN
#include "ncnn/net.h"
#include "ncnn/gpu.h"
#include "ncnn/mat.h"
#include "ncnn/cpu.h"

static std::mutex g_net_mutex;
static ncnn::Net* g_net = nullptr;
static int g_scale = 2;
static int g_tilesize = 128;
static int g_gpuid = 0;
static bool g_gpu_instance_created = false;
#endif

extern "C" int is_vulkan_available() {
#if HAVE_NCNN
    std::lock_guard<std::mutex> lock(g_net_mutex);
    if (!g_gpu_instance_created) {
        ncnn::create_gpu_instance();
        g_gpu_instance_created = true;
    }
    int gpu_count = ncnn::get_gpu_count();
    LOGI("Detected Vulkan GPU count: %d", gpu_count);
    return gpu_count > 0 ? 1 : 0;
#else
    LOGI("NCNN not compiled with Vulkan or in fallback mode");
    return 0;
#endif
}

extern "C" int init_upscaler(const char* param_path, const char* model_path, int scale, int tilesize, int gpuid) {
#if HAVE_NCNN
    std::lock_guard<std::mutex> lock(g_net_mutex);

    LOGI("init_upscaler: param=%s, model=%s, scale=%d, tile=%d, gpu=%d",
         param_path ? param_path : "null",
         model_path ? model_path : "null",
         scale, tilesize, gpuid);

    if (g_net) {
        delete g_net;
        g_net = nullptr;
    }

    if (!g_gpu_instance_created) {
        ncnn::create_gpu_instance();
        g_gpu_instance_created = true;
    }

    g_net = new ncnn::Net();

    int gpu_count = ncnn::get_gpu_count();
    bool use_gpu = (gpuid >= 0 && gpu_count > 0);

    g_net->opt.use_vulkan_compute = use_gpu;
    // Disable fp16 storage and packing layout to ensure standard FP32 planar output
    // and eliminate diagonal hatched static artifacts caused by half-float bit casting.
    g_net->opt.use_fp16_packed = false;
    g_net->opt.use_fp16_storage = false;
    g_net->opt.use_fp16_arithmetic = false;
    g_net->opt.use_packing_layout = false;

    int cpu_count = ncnn::get_big_cpu_count();
    if (cpu_count <= 0) cpu_count = ncnn::get_cpu_count();
    g_net->opt.num_threads = std::clamp(cpu_count, 1, 4);

    if (use_gpu) {
        g_net->set_vulkan_device(gpuid);
        LOGI("Vulkan compute enabled on GPU device %d", gpuid);
    } else {
        LOGI("Running on CPU multi-threading (%d threads)", g_net->opt.num_threads);
    }

    if (!param_path || !model_path) {
        LOGE("Invalid model paths passed to init_upscaler");
        return -1;
    }

    int ret1 = g_net->load_param(param_path);
    int ret2 = g_net->load_model(model_path);

    if (ret1 != 0 || ret2 != 0) {
        LOGE("Failed to load model files: param_ret=%d, model_ret=%d", ret1, ret2);
        delete g_net;
        g_net = nullptr;
        return -2;
    }

    g_scale = scale > 0 ? scale : 2;
    g_tilesize = tilesize > 0 ? tilesize : 128;
    g_gpuid = gpuid;

    LOGI("Upscaler initialized successfully (scale=%d, tilesize=%d)", g_scale, g_tilesize);
    return 0;
#else
    LOGI("Upscaler initialized in simulated fallback mode");
    return 1;
#endif
}

extern "C" int upscale_image(
    const unsigned char* in_rgba,
    int width,
    int height,
    unsigned char* out_rgba,
    int scale,
    int tilesize,
    upscale_progress_callback progress_cb
) {
    if (!in_rgba || !out_rgba || width <= 0 || height <= 0) {
        LOGE("Invalid image dimensions or null buffers");
        return -1;
    }

    int effective_scale = scale > 0 ? scale : 2;
    int out_w = width * effective_scale;
    int out_h = height * effective_scale;

#if HAVE_NCNN
    std::lock_guard<std::mutex> lock(g_net_mutex);

    if (!g_net) {
        LOGE("Engine not initialized! Call init_upscaler first");
        return -2;
    }

    int effective_tile = tilesize > 0 ? tilesize : g_tilesize;
    if (effective_tile <= 0) effective_tile = 128;

    // Zero-initialize output buffer safely
    std::memset(out_rgba, 0, (size_t)out_w * out_h * 4);

        // Convert raw input RGBA to NCNN Mat (RGB planar)
        ncnn::Mat in_rgb = ncnn::Mat::from_pixels(in_rgba, ncnn::Mat::PIXEL_RGBA2RGB, width, height);
        if (in_rgb.empty()) {
            LOGE("Failed to create NCNN input Mat from RGBA pixels");
            return -4;
        }

        const float norm_vals[3] = {1 / 255.f, 1 / 255.f, 1 / 255.f};
        const float denorm_vals[3] = {255.f, 255.f, 255.f};
        const float mean_vals[3] = {0.f, 0.f, 0.f};

        const int prepadding = 10;
        const int xtiles = (width + effective_tile - 1) / effective_tile;
        const int ytiles = (height + effective_tile - 1) / effective_tile;
        const int total_tiles = xtiles * ytiles;
        int current_tile = 0;

        LOGI("Processing image (%dx%d) -> (%dx%d) with %dx%d (%d total) tiles (size=%d)",
             width, height, out_w, out_h, xtiles, ytiles, total_tiles, effective_tile);

        for (int yi = 0; yi < ytiles; yi++) {
            int tile_y = yi * effective_tile;
            int tile_h = std::min(effective_tile, height - tile_y);

            for (int xi = 0; xi < xtiles; xi++) {
                int tile_x = xi * effective_tile;
                int tile_w = std::min(effective_tile, width - tile_x);

                // Compute padded coordinates
                int pad_left = std::min(prepadding, tile_x);
                int pad_top = std::min(prepadding, tile_y);
                int pad_right = std::min(prepadding, width - (tile_x + tile_w));
                int pad_bottom = std::min(prepadding, height - (tile_y + tile_h));

                int crop_x = tile_x - pad_left;
                int crop_y = tile_y - pad_top;
                int crop_w = tile_w + pad_left + pad_right;
                int crop_h = tile_h + pad_top + pad_bottom;

                if (crop_x < 0 || crop_y < 0 || crop_x + crop_w > in_rgb.w || crop_y + crop_h > in_rgb.h) {
                    LOGE("Tile crop out of bounds! (%d,%d,%d,%d) in (%d,%d)", crop_x, crop_y, crop_w, crop_h, in_rgb.w, in_rgb.h);
                    current_tile++;
                    continue;
                }

                ncnn::Mat tile_in;
                ncnn::copy_cut_border(
                    in_rgb,
                    tile_in,
                    crop_y,
                    in_rgb.h - (crop_y + crop_h),
                    crop_x,
                    in_rgb.w - (crop_x + crop_w)
                );
                tile_in.substract_mean_normalize(mean_vals, norm_vals);

                ncnn::Extractor ex = g_net->create_extractor();
                ex.input("data", tile_in);

                ncnn::Mat tile_out;
                int ex_ret = ex.extract("output", tile_out);
                if (ex_ret != 0 || tile_out.empty() || tile_out.w <= 0 || tile_out.h <= 0) {
                    LOGE("Neural network extraction failed for tile (%d,%d), code=%d", xi, yi, ex_ret);
                    current_tile++;
                    continue;
                }

                // Denormalize output float channels to [0.0, 255.0]
                tile_out.substract_mean_normalize(mean_vals, denorm_vals);

                // Compute exact unpadded dimensions
                int target_w = tile_w * effective_scale;
                int target_h = tile_h * effective_scale;
                int cut_left = pad_left * effective_scale;
                int cut_top = pad_top * effective_scale;
                int cut_right = std::max(0, tile_out.w - (cut_left + target_w));
                int cut_bottom = std::max(0, tile_out.h - (cut_top + target_h));

                // Guard against cut borders exceeding output dimensions
                if (cut_left + cut_right >= tile_out.w || cut_top + cut_bottom >= tile_out.h) {
                    LOGE("Cut borders exceed tile_out dimensions for tile (%d,%d)", xi, yi);
                    current_tile++;
                    continue;
                }

                ncnn::Mat unpadded_tile;
                ncnn::copy_cut_border(
                    tile_out,
                    unpadded_tile,
                    cut_top,
                    cut_bottom,
                    cut_left,
                    cut_right
                );

                if (unpadded_tile.empty() || unpadded_tile.w <= 0 || unpadded_tile.h <= 0) {
                    current_tile++;
                    continue;
                }

                // Export unpadded tile directly to out_rgba at (dst_x, dst_y) with row stride out_w * 4
                int dst_x = tile_x * effective_scale;
                int dst_y = tile_y * effective_scale;

                // Strict buffer bounds check: prevent buffer overrun
                if (dst_x + unpadded_tile.w > out_w || dst_y + unpadded_tile.h > out_h) {
                    LOGE("Tile bounds exceed output buffer! dst=(%d,%d) tile=(%d,%d) out=(%d,%d)",
                         dst_x, dst_y, unpadded_tile.w, unpadded_tile.h, out_w, out_h);
                    current_tile++;
                    continue;
                }

                size_t dst_offset = ((size_t)dst_y * out_w + dst_x) * 4;
                unsigned char* dst_ptr = out_rgba + dst_offset;

                unpadded_tile.to_pixels(dst_ptr, ncnn::Mat::PIXEL_RGB2RGBA, out_w * 4);

                current_tile++;
                if (progress_cb) {
                    progress_cb(current_tile, total_tiles);
                }
            }
        }

        LOGI("Upscaling completed successfully.");
        return 0;

#else
    // Fallback: Bilinear scale interpolation
    LOGI("Upscaling via fallback bilinear interpolator");
    for (int y = 0; y < out_h; y++) {
        float src_y = (float)y / (float)effective_scale;
        int y_low = (int)src_y;
        int y_high = std::min(y_low + 1, height - 1);
        float y_weight = src_y - y_low;

        for (int x = 0; x < out_w; x++) {
            float src_x = (float)x / (float)effective_scale;
            int x_low = (int)src_x;
            int x_high = std::min(x_low + 1, width - 1);
            float x_weight = src_x - x_low;

            int dst_idx = (y * out_w + x) * 4;

            int idx_00 = (y_low * width + x_low) * 4;
            int idx_10 = (y_low * width + x_high) * 4;
            int idx_01 = (y_high * width + x_low) * 4;
            int idx_11 = (y_high * width + x_high) * 4;

            for (int c = 0; c < 4; c++) {
                float top = in_rgba[idx_00 + c] * (1.0f - x_weight) + in_rgba[idx_10 + c] * x_weight;
                float bottom = in_rgba[idx_01 + c] * (1.0f - x_weight) + in_rgba[idx_11 + c] * x_weight;
                float val = top * (1.0f - y_weight) + bottom * y_weight;
                out_rgba[dst_idx + c] = (unsigned char)std::clamp(val, 0.0f, 255.0f);
            }
        }
    }
    if (progress_cb) {
        progress_cb(1, 1);
    }
    return 1;
#endif
}

extern "C" void destroy_upscaler() {
#if HAVE_NCNN
    std::lock_guard<std::mutex> lock(g_net_mutex);
    if (g_net) {
        delete g_net;
        g_net = nullptr;
    }
    LOGI("Upscaler destroyed and network freed.");
#endif
}
