import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';

class ImageProcessor {
  ImageProcessor._();

  /// Process image in a background isolate to keep UI smooth and non-blocking
  static Future<ProcessResult> processImage(ProcessOptions options) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDirPath = cacheDir.path;

    return compute(
      _processImageInternal,
      _IsolateParams(
        options: options,
        outputDirPath: outputDirPath,
      ),
    );
  }

  /// Internal processing executed inside the background isolate
  static Future<ProcessResult> _processImageInternal(_IsolateParams params) async {
    final stopwatch = Stopwatch()..start();
    final options = params.options;
    final sourceFile = File(options.sourcePath);

    if (!sourceFile.existsSync()) {
      throw Exception('Source file does not exist at ${options.sourcePath}');
    }

    final originalBytes = await sourceFile.readAsBytes();
    final originalSizeBytes = originalBytes.length;

    // 1. Decode Image
    final decodedImage = img.decodeImage(originalBytes);
    if (decodedImage == null) {
      throw Exception('Failed to decode image from ${options.sourcePath}');
    }

    final originalWidth = decodedImage.width;
    final originalHeight = decodedImage.height;

    img.Image workingImage = decodedImage;

    // 2. Handle Dimension Resizing if requested
    if (options.resizeMode == ResizeMode.exactPixels) {
      if (options.targetWidth != null || options.targetHeight != null) {
        int targetW = options.targetWidth ?? workingImage.width;
        int targetH = options.targetHeight ?? workingImage.height;

        if (options.keepAspectRatio) {
          if (options.targetWidth != null && options.targetHeight == null) {
            targetH = (originalHeight * (targetW / originalWidth)).round();
          } else if (options.targetHeight != null && options.targetWidth == null) {
            targetW = (originalWidth * (targetH / originalHeight)).round();
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
      encodedBytes = _encodeImage(workingImage, format: format, quality: finalQuality);
    }

    // 4. Save to temporary output file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == 'jpeg' ? 'jpg' : format;
    final outputFileName = 'img_tool_$timestamp.$extension';
    final outputFilePath = p.join(params.outputDirPath, outputFileName);
    final outputFile = File(outputFilePath);
    await outputFile.writeAsBytes(encodedBytes);

    stopwatch.stop();

    return ProcessResult(
      originalPath: options.sourcePath,
      outputPath: outputFilePath,
      originalSizeBytes: originalSizeBytes,
      outputSizeBytes: encodedBytes.length,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      outputWidth: workingImage.width,
      outputHeight: workingImage.height,
      outputFormat: extension,
      finalQuality: finalQuality,
      processingTime: stopwatch.elapsed,
    );
  }

  /// Binary search quality and iterative dimension scaling to hit target size
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

    if (!isLosslessPng) {
      // Step A: Binary search on quality (5% to 95%) for lossy formats (JPG, WebP)
      int low = 5;
      int high = 95;

      while (low <= high) {
        final midQuality = (low + high) ~/ 2;
        final encoded = _encodeImage(currentImage, format: format, quality: midQuality);

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
      final originalEncoded = _encodeImage(currentImage, format: format, quality: 100);
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
    if (!strictDimensions && (bestBytes == null || bestBytes.length > targetMaxBytes)) {
      double scale = 0.90;
      final int stepQuality = isLosslessPng ? 100 : 75;

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
          final encoded = _encodeImage(scaledImage, format: format, quality: 100);
          if (encoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = encoded;
            bestQuality = 100;
            break;
          }
        } else {
          // Test with moderate quality
          final encoded = _encodeImage(scaledImage, format: format, quality: stepQuality);
          if (encoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = encoded;
            bestQuality = stepQuality;
            break;
          }

          // Try lower quality 40% on scaled image
          final lowQualityEncoded = _encodeImage(scaledImage, format: format, quality: 40);
          if (lowQualityEncoded.length <= targetMaxBytes) {
            currentImage = scaledImage;
            bestBytes = lowQualityEncoded;
            bestQuality = 40;
            break;
          }
        }

        scale -= 0.10;
      }
    }

    // Fallback if still null
    if (bestBytes == null) {
      bestQuality = isLosslessPng ? 100 : 20;
      bestBytes = _encodeImage(currentImage, format: format, quality: bestQuality);
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

  const _IsolateParams({
    required this.options,
    required this.outputDirPath,
  });
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
