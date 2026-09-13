import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'image_service/safe_image_decoder.dart';


// FFI Native Signatures
typedef _IsVulkanAvailableNative = Int32 Function();
typedef _IsVulkanAvailableDart = int Function();

typedef _InitUpscalerNative = Int32 Function(
  Pointer<Utf8> paramPath,
  Pointer<Utf8> modelPath,
  Int32 scale,
  Int32 tileSize,
  Int32 gpuid,
);
typedef _InitUpscalerDart = int Function(
  Pointer<Utf8> paramPath,
  Pointer<Utf8> modelPath,
  int scale,
  int tileSize,
  int gpuid,
);

typedef _ProgressCallbackNative = Void Function(Int32 current, Int32 total);

typedef _UpscaleImageNative = Int32 Function(
  Pointer<Uint8> inRgba,
  Int32 width,
  Int32 height,
  Pointer<Uint8> outRgba,
  Int32 scale,
  Int32 tileSize,
  Pointer<NativeFunction<_ProgressCallbackNative>> progressCb,
);
typedef _UpscaleImageDart = int Function(
  Pointer<Uint8> inRgba,
  int width,
  int height,
  Pointer<Uint8> outRgba,
  int scale,
  int tileSize,
  Pointer<NativeFunction<_ProgressCallbackNative>> progressCb,
);

typedef _DestroyUpscalerNative = Void Function();
typedef _DestroyUpscalerDart = void Function();

/// Result model containing processed output and performance metrics
class AiUpscaleResult {
  final Uint8List imageBytes;
  final int originalWidth;
  final int originalHeight;
  final int upscaledWidth;
  final int upscaledHeight;
  final Duration duration;
  final bool isVulkanAccelerated;
  final bool isFallbackSimulated;
  final int scale;

  const AiUpscaleResult({
    required this.imageBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.upscaledWidth,
    required this.upscaledHeight,
    required this.duration,
    required this.isVulkanAccelerated,
    required this.isFallbackSimulated,
    required this.scale,
  });
}

/// Service providing on-device AI Super Resolution using Tencent NCNN + Real-ESRGAN
class AiUpscalerService {
  static final AiUpscalerService _instance = AiUpscalerService._internal();
  factory AiUpscalerService() => _instance;
  AiUpscalerService._internal();

  DynamicLibrary? _dylib;
  _IsVulkanAvailableDart? _isVulkanAvailable;
  _InitUpscalerDart? _initUpscaler;
  _UpscaleImageDart? _upscaleImage;
  _DestroyUpscalerDart? _destroyUpscaler;

  bool _isInitialized = false;
  bool _isNativeLoaded = false;
  bool _isVulkanSupported = false;

  bool get isNativeLoaded => _isNativeLoaded && _upscaleImage != null;
  bool get isVulkanSupported => _isVulkanSupported;

  /// Loads native library bindings
  void _loadNativeLibrary() {
    if (_isNativeLoaded) return;

    try {
      if (Platform.isAndroid) {
        _dylib = DynamicLibrary.open('libupscaler.so');
      } else {
        // Desktop / Mock support
        _dylib = DynamicLibrary.process();
      }

      _isVulkanAvailable = _dylib!
          .lookup<NativeFunction<_IsVulkanAvailableNative>>('is_vulkan_available')
          .asFunction<_IsVulkanAvailableDart>();

      _initUpscaler = _dylib!
          .lookup<NativeFunction<_InitUpscalerNative>>('init_upscaler')
          .asFunction<_InitUpscalerDart>();

      _upscaleImage = _dylib!
          .lookup<NativeFunction<_UpscaleImageNative>>('upscale_image')
          .asFunction<_UpscaleImageDart>();

      _destroyUpscaler = _dylib!
          .lookup<NativeFunction<_DestroyUpscalerNative>>('destroy_upscaler')
          .asFunction<_DestroyUpscalerDart>();

      _isNativeLoaded = true;
      _isVulkanSupported = (_isVulkanAvailable?.call() ?? 0) > 0;
      debugPrint('[AiUpscalerService] Native library loaded. Vulkan available: $_isVulkanSupported');
    } catch (e) {
      debugPrint('[AiUpscalerService] Failed to load native library: $e');
      _isNativeLoaded = false;
      _isVulkanSupported = false;
    }
  }

  /// Extracts compact AI model files from APK assets to the persistent storage directory
  Future<({String paramPath, String modelPath})> ensureModelsExtracted({int scale = 2}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory(p.join(docsDir.path, 'ai_models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final modelBaseName = scale == 4 ? 'realesr-animevideov3-x4' : 'realesr-animevideov3-x2';
    final paramFile = File(p.join(modelsDir.path, '$modelBaseName.param'));
    final binFile = File(p.join(modelsDir.path, '$modelBaseName.bin'));

    // Extract .param
    if (!await paramFile.exists()) {
      final data = await rootBundle.load('assets/models/$modelBaseName.param');
      await paramFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint('[AiUpscalerService] Extracted $modelBaseName.param (${await paramFile.length()} bytes)');
    }

    // Extract .bin
    if (!await binFile.exists()) {
      final data = await rootBundle.load('assets/models/$modelBaseName.bin');
      await binFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint('[AiUpscalerService] Extracted $modelBaseName.bin (${await binFile.length()} bytes)');
    }

    return (paramPath: paramFile.path, modelPath: binFile.path);
  }

  /// Initializes the upscaler engine for a given scale (2 or 4)
  Future<bool> initializeEngine({int scale = 2, int tileSize = 128}) async {
    _loadNativeLibrary();
    if (!_isNativeLoaded || _initUpscaler == null) {
      debugPrint('[AiUpscalerService] Cannot initialize engine without native library');
      return false;
    }

    try {
      final paths = await ensureModelsExtracted(scale: scale);
      final paramPtr = paths.paramPath.toNativeUtf8();
      final modelPtr = paths.modelPath.toNativeUtf8();

      final gpuId = _isVulkanSupported ? 0 : -1;
      final ret = _initUpscaler!(paramPtr, modelPtr, scale, tileSize, gpuId);

      calloc.free(paramPtr);
      calloc.free(modelPtr);

      _isInitialized = (ret >= 0);
      debugPrint('[AiUpscalerService] init_upscaler returned: $ret');
      return _isInitialized;
    } catch (e) {
      debugPrint('[AiUpscalerService] Exception during initialization: $e');
      return false;
    }
  }

  /// Upscale an image with AI Super Resolution
  /// [inputBytes]: Raw image file bytes (PNG, JPG, WebP)
  /// [scale]: Target upscale factor (2 for 2x, 4 for 4x)
  /// [tileSize]: Sub-tile processing size to avoid GPU memory overflow (safe default: 128)
  /// [onProgress]: Callback receiving progress (0.0 to 1.0) and human-readable status message
  Future<AiUpscaleResult> upscale({
    required Uint8List inputBytes,
    int scale = 2,
    int tileSize = 128,
    void Function(double progress, String status)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();

    onProgress?.call(0.02, 'Initializing AI neural engine...');

    // OOM Protection: Pre-scale ultra-high-resolution images (e.g. 12MP-48MP camera photos)
    // before allocating massive native RGBA buffers and neural GPU textures.
    // 2x: max input dimension 2048px (max output 4096px, 4K UHD)
    // 4x: max input dimension 1280px (max output 5120px, 5K)
    Uint8List processBytes = inputBytes;
    try {
      final header = SafeImageDecoder.readHeaderDimensions(inputBytes);
      final maxInputDim = scale == 4 ? 1280 : 2048;
      if (header != null && (header.width > maxInputDim || header.height > maxInputDim)) {
        onProgress?.call(0.04, 'Optimizing image resolution for neural processing...');
        final safeImage = await SafeImageDecoder.decodeSafe(
          inputBytes,
          maxDimension: maxInputDim,
          maxPixels: maxInputDim * maxInputDim,
        );
        if (safeImage != null) {
          processBytes = Uint8List.fromList(img.encodeJpg(safeImage, quality: 95));
        }
      }
    } catch (e) {
      debugPrint('[AiUpscalerService] Pre-scale safe check warning: $e');
    }

    // Ensure native engine is initialized with models on main thread
    await initializeEngine(scale: scale, tileSize: tileSize);

    NativeCallable<_ProgressCallbackNative>? nativeCallable;
    if (onProgress != null) {
      nativeCallable = NativeCallable<_ProgressCallbackNative>.listener((int current, int total) {
        if (total > 0) {
          final p = (current / total).clamp(0.0, 1.0);
          final percent = (p * 100).toInt();
          onProgress(p, 'Processing neural tile $current of $total ($percent%)...');
        }
      });
    }

    final cbAddress = nativeCallable?.nativeFunction.address ?? 0;

    try {
      onProgress?.call(0.05, 'Decoding image frames...');

      final workerParams = _UpscaleWorkerParams(
        inputBytes: processBytes,
        scale: scale,
        tileSize: tileSize,
        progressCbAddress: cbAddress,
        isNativeLoaded: _isNativeLoaded,
      );

      // Run heavy image decode, FFI neural inference, and JPEG encode in background isolate
      final workerResult = await compute(_runUpscaleWorker, workerParams);

      stopwatch.stop();
      onProgress?.call(1.0, 'Finalizing output...');

      return AiUpscaleResult(
        imageBytes: workerResult.resultBytes,
        originalWidth: workerResult.inW,
        originalHeight: workerResult.inH,
        upscaledWidth: workerResult.outW,
        upscaledHeight: workerResult.outH,
        duration: stopwatch.elapsed,
        isVulkanAccelerated: _isVulkanSupported && !workerResult.isFallback,
        isFallbackSimulated: workerResult.isFallback,
        scale: scale,
      );
    } finally {
      nativeCallable?.close();
    }
  }

  /// Release native resources
  void dispose() {
    if (_isNativeLoaded && _destroyUpscaler != null) {
      _destroyUpscaler!();
      _isInitialized = false;
    }
  }
}

class _UpscaleWorkerParams {
  final Uint8List inputBytes;
  final int scale;
  final int tileSize;
  final int progressCbAddress;
  final bool isNativeLoaded;

  const _UpscaleWorkerParams({
    required this.inputBytes,
    required this.scale,
    required this.tileSize,
    required this.progressCbAddress,
    required this.isNativeLoaded,
  });
}

class _UpscaleWorkerResult {
  final Uint8List resultBytes;
  final int inW;
  final int inH;
  final int outW;
  final int outH;
  final bool isFallback;

  const _UpscaleWorkerResult({
    required this.resultBytes,
    required this.inW,
    required this.inH,
    required this.outW,
    required this.outH,
    required this.isFallback,
  });
}

_UpscaleWorkerResult _runUpscaleWorker(_UpscaleWorkerParams params) {
  // Decode image in background isolate (zero UI freeze!)
  final decoded = img.decodeImage(params.inputBytes);
  if (decoded == null) {
    throw Exception("Unable to decode input image format");
  }

  final inW = decoded.width;
  final inH = decoded.height;
  final outW = inW * params.scale;
  final outH = inH * params.scale;

  final inRgbaBytes = decoded.getBytes(order: img.ChannelOrder.rgba);
  final inBufferSize = inW * inH * 4;
  final outBufferSize = outW * outH * 4;

  bool isFallback = !params.isNativeLoaded;
  Uint8List resultBytes;

  if (params.isNativeLoaded && Platform.isAndroid) {
    DynamicLibrary? dylib;
    _UpscaleImageDart? upscaleImage;
    try {
      dylib = DynamicLibrary.open('libupscaler.so');
      upscaleImage = dylib
          .lookup<NativeFunction<_UpscaleImageNative>>('upscale_image')
          .asFunction<_UpscaleImageDart>();
    } catch (e) {
      debugPrint('[UpscaleWorker] Failed to load native library in isolate: $e');
    }

    if (upscaleImage != null) {
      Pointer<Uint8>? inPtr;
      Pointer<Uint8>? outPtr;
      try {
        inPtr = calloc<Uint8>(inBufferSize);
        outPtr = calloc<Uint8>(outBufferSize);
      } catch (e) {
        debugPrint('[UpscaleWorker] Native memory allocation failed: $e');
        inPtr = null;
        outPtr = null;
      }

      if (inPtr != null && inPtr.address != 0 && outPtr != null && outPtr.address != 0) {
        final cbPtr = params.progressCbAddress != 0
            ? Pointer<NativeFunction<_ProgressCallbackNative>>.fromAddress(params.progressCbAddress)
            : nullptr;

        try {
          inPtr.asTypedList(inBufferSize).setAll(0, inRgbaBytes);
          final status = upscaleImage(inPtr, inW, inH, outPtr, params.scale, params.tileSize, cbPtr);
          if (status < 0) {
            // Processing error or memory pressure in C++
            debugPrint('[UpscaleWorker] upscale_image returned error status: $status, using cubic fallback');
            isFallback = true;
            final resized = img.copyResize(
              decoded,
              width: outW,
              height: outH,
              interpolation: img.Interpolation.cubic,
            );
            resultBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
          } else {
            isFallback = (status == 1);
            final outPixels = Uint8List.fromList(outPtr.asTypedList(outBufferSize));
            final outImage = img.Image.fromBytes(
              width: outW,
              height: outH,
              bytes: outPixels.buffer,
              order: img.ChannelOrder.rgba,
              numChannels: 4,
            );
            resultBytes = Uint8List.fromList(img.encodeJpg(outImage, quality: 95));
          }
        } catch (e) {
          debugPrint('[UpscaleWorker] Inference execution error: $e, falling back to cubic');
          isFallback = true;
          final resized = img.copyResize(
            decoded,
            width: outW,
            height: outH,
            interpolation: img.Interpolation.cubic,
          );
          resultBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
        } finally {
          if (inPtr.address != 0) calloc.free(inPtr);
          if (outPtr.address != 0) calloc.free(outPtr);
        }
      } else {
        // Safe cleanup if only one pointer was allocated before failure
        if (inPtr != null && inPtr.address != 0) calloc.free(inPtr);
        if (outPtr != null && outPtr.address != 0) calloc.free(outPtr);
        isFallback = true;
        final resized = img.copyResize(
          decoded,
          width: outW,
          height: outH,
          interpolation: img.Interpolation.cubic,
        );
        resultBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
      }
    } else {
      isFallback = true;
      final resized = img.copyResize(
        decoded,
        width: outW,
        height: outH,
        interpolation: img.Interpolation.cubic,
      );
      resultBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
    }
  } else {
    isFallback = true;
    final resized = img.copyResize(
      decoded,
      width: outW,
      height: outH,
      interpolation: img.Interpolation.cubic,
    );
    resultBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 95));
  }

  return _UpscaleWorkerResult(
    resultBytes: resultBytes,
    inW: inW,
    inH: inH,
    outW: outW,
    outH: outH,
    isFallback: isFallback,
  );
}
