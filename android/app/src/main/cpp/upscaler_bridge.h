#ifndef UPSCALER_BRIDGE_H
#define UPSCALER_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*upscale_progress_callback)(int current, int total);

// Check if Vulkan GPU compute is available on this device
__attribute__((visibility("default")))
int is_vulkan_available();

// Initialize the upscaler engine with model files
// scale: 2, 3, or 4
// tilesize: safe default 128 (0 for auto)
// gpuid: 0 for primary GPU, -1 for CPU
__attribute__((visibility("default")))
int init_upscaler(const char* param_path, const char* model_path, int scale, int tilesize, int gpuid);

// Upscale an RGBA image buffer
// in_rgba: input pixel array (width * height * 4)
// out_rgba: pre-allocated output pixel array (width * scale * height * scale * 4)
__attribute__((visibility("default")))
int upscale_image(
    const unsigned char* in_rgba,
    int width,
    int height,
    unsigned char* out_rgba,
    int scale,
    int tilesize,
    upscale_progress_callback progress_cb
);

// Release upscaler engine and GPU resources
__attribute__((visibility("default")))
void destroy_upscaler();

#ifdef __cplusplus
}
#endif

#endif // UPSCALER_BRIDGE_H
