import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import 'dpi_service.dart';
import 'heic_converter.dart';
import 'metadata_stripper.dart';
import 'safe_image_decoder.dart';

typedef ImageProgressCallback = void Function(double progress, String stage);

/// Dimension model representing image width and height
class ImageDimensions {
  final int width;
  final int height;

  const ImageDimensions({required this.width, required this.height});

  @override
  String toString() => '${width}x$height';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageDimensions &&
          runtimeType == other.runtimeType &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => width.hashCode ^ height.hashCode;
}

class ImageProcessor {
  ImageProcessor._();

  /// Reads image dimensions (width & height) in a background isolate without freezing UI.
  /// Automatically uses native engine decoder fallback for HEIC/HEIF files.
  static Future<ImageDimensions?> readImageDimensions(String filePath) async {
    ImageDimensions? dims;
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) {
        dims = _readDimensionsInternal(filePath);
      } else {
        dims = await compute(_readDimensionsInternal, filePath);
      }
    } catch (_) {}

    if (dims != null && dims.width > 0 && dims.height > 0) {
      return dims;
    }

    // Fallback for HEIC/unsupported pure-Dart formats
    try {
      final compatiblePath = await HeicConverter.ensureCompatibleImage(
        filePath,
      );
      if (compatiblePath != filePath) {
        if (Platform.environment.containsKey('FLUTTER_TEST')) {
          dims = _readDimensionsInternal(compatiblePath);
        } else {
          dims = await compute(_readDimensionsInternal, compatiblePath);
        }
        if (dims != null && dims.width > 0 && dims.height > 0) {
          return dims;
        }
      }

      // Final fallback via Flutter engine
      final file = File(filePath);
      if (file.existsSync()) {
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return ImageDimensions(
          width: frame.image.width,
          height: frame.image.height,
        );
      }
    } catch (e) {
      debugPrint('[ImageProcessor] Fallback dimension read error: $e');
    }
    return null;
  }

  static ImageDimensions? _readDimensionsInternal(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final bytes = file.readAsBytesSync();

      // Fast-path: Header decoding without allocating all pixel data in heap
      final headerDims = SafeImageDecoder.readHeaderDimensions(bytes);
      if (headerDims != null) {
        return ImageDimensions(
          width: headerDims.width,
          height: headerDims.height,
        );
      }

      // Safe fallback: decode image within this background isolate
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        return ImageDimensions(width: decoded.width, height: decoded.height);
      }
    } catch (e) {
      debugPrint('Error reading image dimensions: $e');
    }
    return null;
  }

  /// Process image in a background isolate to keep UI smooth and non-blocking.
  /// Real-time determinate progress stages are streamed via [onProgress].
  static Future<ProcessResult> processImage(
    ProcessOptions options, {
    String? customOutputDirPath,
    ImageProgressCallback? onProgress,
  }) async {
    // Automatically convert HEIC/unsupported format to compatible format before processing
    final effectiveSourcePath = await HeicConverter.ensureCompatibleImage(
      options.sourcePath,
    );
    final effectiveOptions = effectiveSourcePath != options.sourcePath
        ? options.copyWith(sourcePath: effectiveSourcePath)
        : options;

    String outputDirPath;
    if (customOutputDirPath != null) {
      outputDirPath = customOutputDirPath;
    } else if (Platform.environment.containsKey('FLUTTER_TEST')) {
      outputDirPath = Directory.systemTemp.path;
    } else {
      try {
        final cacheDir = await getTemporaryDirectory();
        outputDirPath = cacheDir.path;
      } catch (_) {
        outputDirPath = Directory.systemTemp.path;
      }
    }

    final params = _IsolateParams(
      options: effectiveOptions,
      outputDirPath: outputDirPath,
    );

    // In test environment, execute directly to avoid compute()/Isolate blocking in widget tests
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      onProgress?.call(0.10, 'Reading image file...');
      onProgress?.call(0.35, 'Decoding image pixels...');
      final res = await _processImageInternal(params, onProgress: onProgress);
      onProgress?.call(1.00, 'Complete');
      return res;
    }

    // If progress reporting is requested, use dedicated spawned isolate with message port
    if (onProgress != null) {
      return _processWithProgressPort(params, onProgress);
    }

    return compute(_processImageCompute, params);
  }

  static Future<ProcessResult> _processWithProgressPort(
    _IsolateParams params,
    ImageProgressCallback onProgress,
  ) async {
    final receivePort = ReceivePort();
    Isolate? isolate;
    StreamSubscription? sub;

    try {
      final completer = Completer<ProcessResult>();

      sub = receivePort.listen(
        (message) {
          if (message is _WorkerProgress) {
            onProgress(message.progress, message.stage);
          } else if (message is ProcessResult) {
            if (!completer.isCompleted) completer.complete(message);
          } else if (message is _WorkerError) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception(message.error),
                message.stack != null
                    ? StackTrace.fromString(message.stack!)
                    : null,
              );
            }
          }
        },
        onError: (err, stack) {
          if (!completer.isCompleted) {
            completer.completeError(err, stack);
          }
        },
      );

      isolate = await Isolate.spawn(
        _workerIsolateEntryPoint,
        _WorkerArgs(params: params, sendPort: receivePort.sendPort),
      );

      return await completer.future;
    } finally {
      await sub?.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  static void _workerIsolateEntryPoint(_WorkerArgs args) async {
    final sendPort = args.sendPort;
    try {
      final result = await _processImageInternal(
        args.params,
        onProgress: (progress, stage) {
          sendPort.send(_WorkerProgress(progress, stage));
        },
      );
      sendPort.send(result);
    } catch (e, stack) {
      sendPort.send(_WorkerError(e.toString(), stack.toString()));
    }
  }

  static Future<ProcessResult> _processImageCompute(_IsolateParams params) {
    return _processImageInternal(params);
  }

  /// Internal processing executed inside the background isolate
  static Future<ProcessResult> _processImageInternal(
    _IsolateParams params, {
    ImageProgressCallback? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final options = params.options;
    final sourceFile = File(options.sourcePath);

    if (!sourceFile.existsSync()) {
      throw Exception('Source file does not exist at ${options.sourcePath}');
    }

    onProgress?.call(0.10, 'Reading image file...');
    final originalBytes = sourceFile.readAsBytesSync();
    final originalSizeBytes = originalBytes.length;

    // 1. Decode Image with OOM protection (downsampling 48MP/108MP if needed)
    onProgress?.call(0.35, 'Decoding image (OOM protected)...');
    final decodedImage = await SafeImageDecoder.decodeSafe(originalBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image from ${options.sourcePath}');
    }

    final originalWidth = decodedImage.width;
    final originalHeight = decodedImage.height;

    img.Image workingImage = decodedImage;

    // Automatic Privacy: Strip GPS location, camera model, and sensitive EXIF tags
    if (options.stripMetadata) {
      MetadataStripper.stripFromImage(workingImage);
    }

    // Apply orientation: Rotation & Flip before resizing/compression
    onProgress?.call(0.55, 'Applying transformations...');
    if (options.quarterTurns % 4 != 0) {
      final angle = (options.quarterTurns % 4) * 90;
      workingImage = img.copyRotate(workingImage, angle: angle);
    }
    if (options.flipHorizontal && options.flipVertical) {
      workingImage = img.copyFlip(
        workingImage,
        direction: img.FlipDirection.both,
      );
    } else if (options.flipHorizontal) {
      workingImage = img.copyFlip(
        workingImage,
        direction: img.FlipDirection.horizontal,
      );
    } else if (options.flipVertical) {
      workingImage = img.copyFlip(
        workingImage,
        direction: img.FlipDirection.vertical,
      );
    }

    // 2. Handle Dimension Resizing if requested
    onProgress?.call(0.70, 'Resizing to target resolution...');
    if (options.resizeMode == ResizeMode.exactPixels) {
      if (options.targetWidth != null || options.targetHeight != null) {
        int targetW = options.targetWidth ?? workingImage.width;
        int targetH = options.targetHeight ?? workingImage.height;

        if (options.keepAspectRatio) {
          if (options.targetWidth != null && options.targetHeight == null) {
            targetH = (workingImage.height * (targetW / workingImage.width))
                .round();
          } else if (options.targetHeight != null &&
              options.targetWidth == null) {
            targetW = (workingImage.width * (targetH / workingImage.height))
                .round();
          }
        }

        workingImage = img.copyResize(
          workingImage,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }
    } else if (options.resizeMode == ResizeMode.percentage) {
      if (options.resizePercentage != null && options.resizePercentage! > 0) {
        final factor = options.resizePercentage! / 100.0;
        final targetW = (workingImage.width * factor).round();
        final targetH = (workingImage.height * factor).round();

        workingImage = img.copyResize(
          workingImage,
          width: targetW > 0 ? targetW : 1,
          height: targetH > 0 ? targetH : 1,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    // 3. Handle Target Size or Direct Encoding
    onProgress?.call(0.85, 'Optimizing compression & quality...');
    Uint8List encodedBytes;
    int finalQuality = options.quality;
    final format = options.outputFormat.toLowerCase();

    if (options.targetSizeKB != null && options.targetSizeKB! > 0) {
      // Smart Target File Size Optimization
      final targetMaxBytes = options.targetSizeKB! * 1024;
      final optResult = _optimizeToTargetSize(
        workingImage,
        targetMaxBytes: targetMaxBytes,
        format: format,
        strictDimensions: options.strictDimensions,
      );
      encodedBytes = optResult.bytes;
      finalQuality = optResult.quality;
      workingImage = optResult.image;
    } else {
      // Direct Encoding based on quality
      encodedBytes = _encodeImage(
        workingImage,
        format: format,
        quality: finalQuality,
      );

      // Auto-clamp safeguard: If user did not upscale dimensions and format is lossy,
      // prevent unexpected file size inflation over original input size.
      if (options.preventSizeIncrease &&
          format != 'png' &&
          workingImage.width <= originalWidth &&
          workingImage.height <= originalHeight &&
          encodedBytes.length > originalSizeBytes) {
        int low = 20;
        int high = finalQuality;
        Uint8List? bestBytes;
        int bestQuality = finalQuality;

        while (low <= high) {
          final mid = (low + high) ~/ 2;
          final testBytes = _encodeImage(
            workingImage,
            format: format,
            quality: mid,
          );
          if (testBytes.length <= originalSizeBytes) {
            bestBytes = testBytes;
            bestQuality = mid;
            low = mid + 1; // Try higher quality within boundary
          } else {
            high = mid - 1;
          }
        }

        if (bestBytes != null) {
          encodedBytes = bestBytes;
          finalQuality = bestQuality;
        } else {
          // If even quality 20 is larger than original, use a moderate quality to minimize bloat
          final fallbackBytes = _encodeImage(
            workingImage,
            format: format,
            quality: 60,
          );
          if (fallbackBytes.length < encodedBytes.length) {
            encodedBytes = fallbackBytes;
            finalQuality = 60;
          }
        }
      }
    }

    // 4. Save to temporary output file
    onProgress?.call(0.95, 'Saving processed image...');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == 'jpeg' ? 'jpg' : format;
    final outputFileName = 'img_tool_$timestamp.$extension';
    final outputFilePath = p.join(params.outputDirPath, outputFileName);
    final outputFile = File(outputFilePath);

    // Apply target DPI if specified (lossless metadata injection)
    final finalBytes = options.targetDpi != null
        ? DpiService.setDpi(encodedBytes, options.targetDpi!, format: extension)
        : encodedBytes;

    outputFile.writeAsBytesSync(finalBytes);

    stopwatch.stop();
    onProgress?.call(1.00, 'Complete');

    return ProcessResult(
      originalPath: options.sourcePath,
      outputPath: outputFilePath,
      originalSizeBytes: originalSizeBytes,
      outputSizeBytes: finalBytes.length,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      outputWidth: workingImage.width,
      outputHeight: workingImage.height,
      outputFormat: extension,
      finalQuality: finalQuality,
      processingTime: stopwatch.elapsed,
      metadataStripped: options.stripMetadata,
    );
  }

  /// Binary search quality and iterative dimension scaling to hit target size.
  /// Includes pre-scale optimizations for low-end devices processing 50MP/108MP camera photos.
  static _OptimizedOutput _optimizeToTargetSize(
    img.Image originalImage, {
    required int targetMaxBytes,
    required String format,
    bool strictDimensions = false,
  }) {
    img.Image currentImage = originalImage;
    int bestQuality = 80;
    Uint8List? bestBytes;
    final isLosslessPng = format.toLowerCase() == 'png';

    // Pre-optimization for low-end / budget devices:
    // If image is massive (>4K / 50MP-108MP) and user wants a target file size (e.g. <= 200KB)
    // without strict dimensions, pre-scale to a manageable resolution to avoid OOM and CPU thermal throttling.
    if (!strictDimensions) {
      final maxDim = math.max(currentImage.width, currentImage.height);
      int maxAllowedDim = 3840;
      if (targetMaxBytes <= 100 * 1024) {
        maxAllowedDim = 1920;
      } else if (targetMaxBytes <= 300 * 1024) {
        maxAllowedDim = 2560;
      }

      if (maxDim > maxAllowedDim) {
        final scale = maxAllowedDim / maxDim;
        final targetW = (currentImage.width * scale).round();
        final targetH = (currentImage.height * scale).round();
        currentImage = img.copyResize(
          currentImage,
          width: targetW > 0 ? targetW : 1,
          height: targetH > 0 ? targetH : 1,
          interpolation: img.Interpolation.linear,
        );
      }
    }

    if (!isLosslessPng) {
      // Step A: Binary search on quality (5% to 95%) for lossy formats (JPG, WebP)
      int low = 5;
      int high = 95;

      while (low <= high) {
        final midQuality = (low + high) ~/ 2;
        final encoded = _encodeImage(
          currentImage,
          format: format,
          quality: midQuality,
        );

        if (encoded.length <= targetMaxBytes) {
          bestBytes = encoded;
          bestQuality = midQuality;
          // Try higher quality if possible
          low = midQuality + 1;
        } else {
          // Size is too big, lower quality
          high = midQuality - 1;
        }
      }
    } else {
      // For PNG: Test original resolution first
      final originalEncoded = _encodeImage(
        currentImage,
        format: format,
        quality: 100,
      );
      if (originalEncoded.length <= targetMaxBytes) {
        return _OptimizedOutput(
          bytes: originalEncoded,
          quality: 100,
          image: currentImage,
        );
      }
    }

    // Step B: If quality adjustment alone isn't enough (or for PNG), scale down dimensions iteratively.
    // If strictDimensions is requested (e.g. for exam portal requirements), do not resize dimensions.
    if (!strictDimensions &&
        (bestBytes == null || bestBytes.length > targetMaxBytes)) {
      final int stepQuality = isLosslessPng ? 100 : 75;

      // Estimate initial scale using area-ratio formula: area ~ bytes, so scale ~ sqrt(target / current)
      final int currentBytes = (bestBytes != null && bestBytes.isNotEmpty)
          ? bestBytes.length
          : _encodeImage(
              currentImage,
              format: format,
              quality: stepQuality,
            ).length;

      double scale = 0.90;
      if (currentBytes > targetMaxBytes && currentBytes > 0) {
        // Direct mathematical jump with a 5% safety margin
        final estimated = math.sqrt(targetMaxBytes / currentBytes) * 0.95;
        scale = estimated.clamp(0.05, 0.90);
      }

      while (scale >= 0.05) {
        final newW = (originalImage.width * scale).round();
        final newH = (originalImage.height * scale).round();
        if (newW <= 5 || newH <= 5) break;

        final scaledImage = img.copyResize(
          originalImage,
          width: newW,
          height: newH,
          interpolation: img.Interpolation.linear,
        );

        if (isLosslessPng) {
          final encoded = _encodeImage(
            scaledImage,
            format: format,
            quality: 100,
          );
          if (encoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = encoded;
            bestQuality = 100;
            break;
          }
        } else {
          // Test with moderate quality
          final encoded = _encodeImage(
            scaledImage,
            format: format,
            quality: stepQuality,
          );
          if (encoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = encoded;
            bestQuality = stepQuality;
            break;
          }

          // Try lower quality 40% on scaled image
          final lowQualityEncoded = _encodeImage(
            scaledImage,
            format: format,
            quality: 40,
          );
          if (lowQualityEncoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = lowQualityEncoded;
            bestQuality = 40;
            break;
          }
        }

        // If mathematical estimation didn't quite fit, step down proportionally
        scale *= 0.80;
      }
    }

    // Fallback if still null
    if (bestBytes == null) {
      bestQuality = isLosslessPng ? 100 : 20;
      bestBytes = _encodeImage(
        currentImage,
        format: format,
        quality: bestQuality,
      );
    }

    return _OptimizedOutput(
      bytes: bestBytes,
      quality: bestQuality,
      image: currentImage,
    );
  }

  /// Encodes image to target format
  static Uint8List _encodeImage(
    img.Image image, {
    required String format,
    required int quality,
  }) {
    switch (format.toLowerCase()) {
      case 'png':
        return Uint8List.fromList(img.encodePng(image, level: 6));
      case 'webp':
        return Uint8List.fromList(img.encodeWebP(image));
      case 'jpg':
      case 'jpeg':
      default:
        return Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }
  }
}

class _IsolateParams {
  final ProcessOptions options;
  final String outputDirPath;

  const _IsolateParams({required this.options, required this.outputDirPath});
}

class _WorkerArgs {
  final _IsolateParams params;
  final SendPort sendPort;

  const _WorkerArgs({required this.params, required this.sendPort});
}

class _WorkerProgress {
  final double progress;
  final String stage;

  const _WorkerProgress(this.progress, this.stage);
}

class _WorkerError {
  final String error;
  final String? stack;

  const _WorkerError(this.error, this.stack);
}

class _OptimizedOutput {
  final Uint8List bytes;
  final int quality;
  final img.Image image;

  const _OptimizedOutput({
    required this.bytes,
    required this.quality,
    required this.image,
  });
}
