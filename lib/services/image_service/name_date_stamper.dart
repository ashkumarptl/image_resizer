import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../data/models/process_result.dart';

class PhotoStampOptions {
  final String sourcePath;
  final String candidateName;
  final String dateOfPhoto; // e.g. "01/09/2026"
  final int targetSizeKB; // e.g. 48 KB (strictly under 50 KB)
  final int targetWidth; // e.g. 350
  final int targetHeight; // e.g. 450

  const PhotoStampOptions({
    required this.sourcePath,
    required this.candidateName,
    required this.dateOfPhoto,
    this.targetSizeKB = 48,
    this.targetWidth = 350,
    this.targetHeight = 450,
  });
}

class NameDateStamper {
  NameDateStamper._();

  /// Stamps Name and Date of Photo onto the image in background isolate
  static Future<ProcessResult> stampPhoto(PhotoStampOptions options) async {
    final cacheDir = await getTemporaryDirectory();
    final outputDirPath = cacheDir.path;

    return compute(
      _stampPhotoInternal,
      _StampIsolateParams(
        options: options,
        outputDirPath: outputDirPath,
      ),
    );
  }

  static Future<ProcessResult> _stampPhotoInternal(_StampIsolateParams params) async {
    final stopwatch = Stopwatch()..start();
    final options = params.options;
    final sourceFile = File(options.sourcePath);

    if (!sourceFile.existsSync()) {
      throw Exception('Photo file not found: ${options.sourcePath}');
    }

    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode photo image');
    }

    final origW = decoded.width;
    final origH = decoded.height;
    final origSize = bytes.length;

    // 1. Resize photo to standard dimensions (e.g. 350 x 450)
    final working = img.copyResize(
      decoded,
      width: options.targetWidth,
      height: options.targetHeight,
      interpolation: img.Interpolation.linear,
    );

    // 2. Draw white footer strip at bottom (height ~70px)
    final footerHeight = (working.height * 0.16).round().clamp(50, 100);
    final footerStartY = working.height - footerHeight;

    img.fillRect(
      working,
      x1: 0,
      y1: footerStartY,
      x2: working.width,
      y2: working.height,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Draw top border for footer strip
    img.drawLine(
      working,
      x1: 0,
      y1: footerStartY,
      x2: working.width,
      y2: footerStartY,
      color: img.ColorRgba8(200, 200, 200, 255),
    );

    // 3. Render Name and Date of Photo text
    final font = working.width > 400 ? img.arial24 : img.arial14;
    final nameText = options.candidateName.toUpperCase();
    final dateText = 'DOP: ${options.dateOfPhoto}';

    // Calculate centering (approx character width ~8-12px)
    final charWidth = font == img.arial24 ? 14 : 9;
    final nameX = ((working.width - (nameText.length * charWidth)) / 2).round().clamp(10, working.width - 20);
    final nameY = footerStartY + (footerHeight * 0.18).round();

    img.drawString(
      working,
      nameText,
      font: font,
      x: nameX,
      y: nameY,
      color: img.ColorRgba8(0, 0, 0, 255),
    );

    final dateX = ((working.width - (dateText.length * charWidth)) / 2).round().clamp(10, working.width - 20);
    final dateY = footerStartY + (footerHeight * 0.55).round();

    img.drawString(
      working,
      dateText,
      font: font,
      x: dateX,
      y: dateY,
      color: img.ColorRgba8(0, 0, 0, 255),
    );

    // 4. Encode & Compress to strictly under targetSizeKB
    final targetMaxBytes = options.targetSizeKB * 1024;
    var quality = 85;
    var encoded = img.encodeJpg(working, quality: quality);

    while (encoded.length > targetMaxBytes && quality > 15) {
      quality -= 10;
      encoded = img.encodeJpg(working, quality: quality);
    }

    // 5. Save output file
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputFilePath = p.join(params.outputDirPath, 'photo_stamped_$timestamp.jpg');
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

class _StampIsolateParams {
  final PhotoStampOptions options;
  final String outputDirPath;

  const _StampIsolateParams({
    required this.options,
    required this.outputDirPath,
  });
}
