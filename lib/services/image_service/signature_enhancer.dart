import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_result.dart';

import 'safe_image_decoder.dart';
import 'target_size_compressor.dart';

enum SignatureInkColor { original, darkNavy, pureBlack, royalBlue }

class SignatureEnhanceOptions {
  final String sourcePath;
  final double threshold; // 0.0 to 1.0 (default 0.0)
  final int targetSizeKB; // Default 19 KB (Strictly under 20 KB)
  final int? targetWidth; // e.g. 400
  final int? targetHeight; // e.g. 200
  final int quarterTurns;
  final SignatureInkColor inkColor;

  const SignatureEnhanceOptions({
    required this.sourcePath,
    this.threshold = 0.0,
    this.targetSizeKB = 19,
    this.targetWidth = 400,
    this.targetHeight = 200,
    this.quarterTurns = 0,
    this.inkColor = SignatureInkColor.darkNavy,
  });

  SignatureEnhanceOptions copyWith({
    String? sourcePath,
    double? threshold,
    int? targetSizeKB,
    int? targetWidth,
    int? targetHeight,
    int? quarterTurns,
    SignatureInkColor? inkColor,
  }) {
    return SignatureEnhanceOptions(
      sourcePath: sourcePath ?? this.sourcePath,
      threshold: threshold ?? this.threshold,
      targetSizeKB: targetSizeKB ?? this.targetSizeKB,
      targetWidth: targetWidth ?? this.targetWidth,
      targetHeight: targetHeight ?? this.targetHeight,
      quarterTurns: quarterTurns ?? this.quarterTurns,
      inkColor: inkColor ?? this.inkColor,
    );
  }
}

class SignatureEnhancer {
  SignatureEnhancer._();

  /// Enhances and cleans scanned signature image in background isolate
  static Future<ProcessResult> enhanceSignature(
    SignatureEnhanceOptions options,
  ) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDirPath = cacheDir.path;

    return compute(
      _enhanceSignatureInternal,
      _EnhanceIsolateParams(options: options, outputDirPath: outputDirPath),
    );
  }

  static Future<ProcessResult> _enhanceSignatureInternal(
    _EnhanceIsolateParams params,
  ) async {
    final stopwatch = Stopwatch()..start();
    final options = params.options;
    final sourceFile = File(options.sourcePath);

    if (!sourceFile.existsSync()) {
      throw Exception('Signature file not found: ${options.sourcePath}');
    }

    final bytes = await sourceFile.readAsBytes();
    final maxDecodeDim =
        (options.targetWidth != null || options.targetHeight != null)
        ? math
              .max(
                (options.targetWidth ?? 400) * 2,
                (options.targetHeight ?? 200) * 2,
              )
              .clamp(800, 2048)
        : 2048;
    final decoded = await SafeImageDecoder.decodeSafe(
      bytes,
      maxDimension: maxDecodeDim,
    );
    if (decoded == null) {
      throw Exception('Failed to decode signature image');
    }

    // Apply rotation if specified
    img.Image workingSource = decoded;
    if (options.quarterTurns % 4 != 0) {
      final angle = (options.quarterTurns % 4) * 90;
      workingSource = img.copyRotate(workingSource, angle: angle);
    }

    final origW = workingSource.width;
    final origH = workingSource.height;
    final origSize = bytes.length;

    // 1. High-contrast thresholding with white background isolation
    final isOriginalInk = options.inkColor == SignatureInkColor.original;
    final (r, g, b) = switch (options.inkColor) {
      SignatureInkColor.pureBlack => (0, 0, 0),
      SignatureInkColor.royalBlue => (14, 55, 160),
      SignatureInkColor.darkNavy => (15, 23, 42),
      SignatureInkColor.original => (0, 0, 0),
    };

    final img.Image enhanced;
    if (options.threshold < 0.0) {
      // Negative threshold bypasses background / shadow removal
      enhanced = img.Image.from(workingSource);
    } else {
      final width = workingSource.width;
      final height = workingSource.height;

      // 1. Build luminance buffer
      final lumBuffer = Uint8List(width * height);
      for (var y = 0; y < height; y++) {
        final rowOffset = y * width;
        for (var x = 0; x < width; x++) {
          final pixel = workingSource.getPixel(x, y);
          lumBuffer[rowOffset +
              x] = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
              .round()
              .clamp(0, 255);
        }
      }

      // 2. Build 2D Integral Image for O(1) local window mean calculation (Bradley-Roth adaptive thresholding)
      final intStride = width + 1;
      final integral = Int32List((width + 1) * (height + 1));
      for (var y = 0; y < height; y++) {
        var rowSum = 0;
        final rowOffset = (y + 1) * intStride;
        final prevRowOffset = y * intStride;
        final lumRowOffset = y * width;
        for (var x = 0; x < width; x++) {
          rowSum += lumBuffer[lumRowOffset + x];
          integral[rowOffset + x + 1] =
              integral[prevRowOffset + x + 1] + rowSum;
        }
      }

      // 3. Dynamic contrast thresholds based on user slider strength (0.0 to 1.0)
      final thValue = options.threshold.clamp(0.0, 1.0);
      final tFactor = 0.04 + thValue * 0.18;
      final bMargin = 6.0 + thValue * 14.0;
      final radius = math
          .max(16, (math.min(width, height) / 10).round())
          .clamp(16, 64);
      const softness = 6.0;

      enhanced = img.Image(width: width, height: height);

      for (var y = 0; y < height; y++) {
        final y1 = math.max(0, y - radius);
        final y2 = math.min(height - 1, y + radius);
        final lumRowOffset = y * width;

        for (var x = 0; x < width; x++) {
          final x1 = math.max(0, x - radius);
          final x2 = math.min(width - 1, x + radius);

          final count = (x2 - x1 + 1) * (y2 - y1 + 1);
          final sum =
              integral[(y2 + 1) * intStride + (x2 + 1)] -
              integral[y1 * intStride + (x2 + 1)] -
              integral[(y2 + 1) * intStride + x1] +
              integral[y1 * intStride + x1];

          final localMean = sum / count;
          final currentLum = lumBuffer[lumRowOffset + x];
          final diff = localMean - currentLum;

          final cutoff = localMean * tFactor + bMargin;

          if (diff <= cutoff - softness) {
            // Pure white background
            enhanced.setPixelRgba(x, y, 255, 255, 255, 255);
          } else {
            final alpha = ((diff - (cutoff - softness)) / (2 * softness)).clamp(
              0.0,
              1.0,
            );
            if (isOriginalInk) {
              final pixel = workingSource.getPixel(x, y);
              final outR = ((1.0 - alpha) * 255 + alpha * pixel.r)
                  .round()
                  .clamp(0, 255);
              final outG = ((1.0 - alpha) * 255 + alpha * pixel.g)
                  .round()
                  .clamp(0, 255);
              final outB = ((1.0 - alpha) * 255 + alpha * pixel.b)
                  .round()
                  .clamp(0, 255);
              enhanced.setPixelRgba(x, y, outR, outG, outB, 255);
            } else {
              final outR = ((1.0 - alpha) * 255 + alpha * r).round().clamp(
                0,
                255,
              );
              final outG = ((1.0 - alpha) * 255 + alpha * g).round().clamp(
                0,
                255,
              );
              final outB = ((1.0 - alpha) * 255 + alpha * b).round().clamp(
                0,
                255,
              );
              enhanced.setPixelRgba(x, y, outR, outG, outB, 255);
            }
          }
        }
      }
    }

    // 3. Resize to standard signature aspect if specified
    img.Image working = enhanced;
    if (options.targetWidth != null || options.targetHeight != null) {
      working = img.copyResize(
        working,
        width: options.targetWidth,
        height: options.targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // 4. Encode & Compress to strictly under targetSizeKB
    final targetMaxBytes = options.targetSizeKB * 1024;
    final compressed = TargetSizeCompressor.compressToTargetSize(
      working,
      targetMaxBytes: targetMaxBytes,
    );
    final encoded = compressed.bytes;
    final quality = compressed.quality;
    working = compressed.image;

    // 5. Save output file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFilePath = p.join(
      params.outputDirPath,
      'sig_enhanced_$timestamp.jpg',
    );
    await File(outputFilePath).writeAsBytes(encoded);

    stopwatch.stop();

    return ProcessResult(
      originalPath: options.sourcePath,
      outputPath: outputFilePath,
      originalSizeBytes: origSize,
      outputSizeBytes: encoded.length,
      originalWidth: origW,
      originalHeight: origH,
      outputWidth: working.width,
      outputHeight: working.height,
      outputFormat: 'jpg',
      finalQuality: quality,
      processingTime: stopwatch.elapsed,
    );
  }
}

class _EnhanceIsolateParams {
  final SignatureEnhanceOptions options;
  final String outputDirPath;

  const _EnhanceIsolateParams({
    required this.options,
    required this.outputDirPath,
  });
}
