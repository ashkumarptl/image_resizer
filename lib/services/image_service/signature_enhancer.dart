import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_result.dart';

import 'safe_image_decoder.dart';

enum SignatureInkColor { original, darkNavy, pureBlack, royalBlue }

class SignatureEnhanceOptions {
  final String sourcePath;
  final double threshold; // 0.0 to 1.0 (default ~0.65)
  final int targetSizeKB; // Default 19 KB (Strictly under 20 KB)
  final int? targetWidth; // e.g. 400
  final int? targetHeight; // e.g. 200
  final int quarterTurns;
  final SignatureInkColor inkColor;

  const SignatureEnhanceOptions({
    required this.sourcePath,
    this.threshold = 0.65,
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
    final thresholdInt = (options.threshold * 255).round().clamp(0, 255);
    final enhanced = img.Image(
      width: workingSource.width,
      height: workingSource.height,
    );

    final isOriginalInk = options.inkColor == SignatureInkColor.original;
    final (r, g, b) = switch (options.inkColor) {
      SignatureInkColor.pureBlack => (0, 0, 0),
      SignatureInkColor.royalBlue => (14, 55, 160),
      SignatureInkColor.darkNavy => (15, 23, 42),
      SignatureInkColor.original => (0, 0, 0),
    };

    for (var y = 0; y < workingSource.height; y++) {
      for (var x = 0; x < workingSource.width; x++) {
        final pixel = workingSource.getPixel(x, y);
        // Luminance calculation
        final lum = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b)
            .round();

        if (lum > thresholdInt) {
          // Pure white background
          enhanced.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          if (isOriginalInk) {
            // Retain original vibrant ink stroke color
            enhanced.setPixelRgba(
              x,
              y,
              pixel.r.toInt(),
              pixel.g.toInt(),
              pixel.b.toInt(),
              255,
            );
          } else {
            // Sharp dark ink
            enhanced.setPixelRgba(x, y, r, g, b, 255);
          }
        }
      }
    }

    // 3. Resize to standard signature aspect if specified
    img.Image working = enhanced;
    if (options.targetWidth != null || options.targetHeight != null) {
      working = img.copyResize(
        working,
        width: options.targetWidth ?? (working.width * 0.5).round(),
        height: options.targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    // 4. Encode & Compress to strictly under targetSizeKB
    final targetMaxBytes = options.targetSizeKB * 1024;
    var quality = 85;
    var encoded = img.encodeJpg(working, quality: quality);

    while (encoded.length > targetMaxBytes && quality > 15) {
      quality -= 10;
      encoded = img.encodeJpg(working, quality: quality);
    }

    // If still too big, scale down dimensions
    if (encoded.length > targetMaxBytes) {
      working = img.copyResize(working, width: (working.width * 0.75).round());
      encoded = img.encodeJpg(working, quality: 70);
    }

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
