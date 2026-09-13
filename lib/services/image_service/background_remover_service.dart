import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'safe_image_decoder.dart';

class BackgroundRemoverService {
  BackgroundRemoverService._();

  /// Performs on-device ML Kit subject segmentation on [imageFile]
  /// and returns the foreground transparent PNG bytes.
  /// Ultra-high-resolution images (e.g. 48MP/108MP) are automatically pre-scaled
  /// to protect ML Kit and device memory from OOM crashes.
  static Future<Uint8List?> extractForeground(File imageFile) async {
    final effectiveFile = await SafeImageDecoder.ensureSafeForMlKit(imageFile);
    final isTempFile = effectiveFile.path != imageFile.path;

    final options = SubjectSegmenterOptions(
      enableForegroundBitmap: true,
      enableForegroundConfidenceMask: false,
      enableMultipleSubjects: SubjectResultOptions(
        enableConfidenceMask: false,
        enableSubjectBitmap: false,
      ),
    );

    final segmenter = SubjectSegmenter(options: options);
    try {
      final inputImage = InputImage.fromFile(effectiveFile);
      final result = await segmenter.processImage(inputImage);
      return result.foregroundBitmap;
    } finally {
      try {
        await segmenter.close();
      } catch (_) {}
      if (isTempFile && effectiveFile.existsSync()) {
        try {
          await effectiveFile.delete();
        } catch (_) {}
      }
    }
  }

  /// Saves the foreground PNG bytes with optional background color into a new File.
  /// If [backgroundColor] is null or transparent, output will be a transparent PNG.
  static Future<File> createResultFile({
    required Uint8List foregroundPngBytes,
    Color? backgroundColor,
    String preferredFormat = 'png',
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final isTransparent =
        backgroundColor == null ||
        backgroundColor == Colors.transparent ||
        backgroundColor.a == 0.0;

    if (isTransparent) {
      // Direct write of the native PNG bitmap for maximum speed and zero re-encoding loss
      final outputPath = p.join(tempDir.path, 'bg_removed_$timestamp.png');
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(foregroundPngBytes, flush: true);
      return outputFile;
    }

    // Composite solid color background in background isolate
    final colorRgb = [
      (backgroundColor.r * 255).round().clamp(0, 255),
      (backgroundColor.g * 255).round().clamp(0, 255),
      (backgroundColor.b * 255).round().clamp(0, 255),
    ];

    final outputFormat =
        preferredFormat.toLowerCase() == 'jpg' ||
            preferredFormat.toLowerCase() == 'jpeg'
        ? 'jpg'
        : 'png';

    final outputPath = p.join(
      tempDir.path,
      'bg_replaced_$timestamp.$outputFormat',
    );

    final processedBytes = await compute(_compositeColorBackground, {
      'foregroundBytes': foregroundPngBytes,
      'r': colorRgb[0],
      'g': colorRgb[1],
      'b': colorRgb[2],
      'format': outputFormat,
    });

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(processedBytes, flush: true);
    return outputFile;
  }

  static Uint8List _compositeColorBackground(Map<String, dynamic> params) {
    final foregroundBytes = params['foregroundBytes'] as Uint8List;
    final r = params['r'] as int;
    final g = params['g'] as int;
    final b = params['b'] as int;
    final format = params['format'] as String;

    final fg = img.decodePng(foregroundBytes);
    if (fg == null) {
      throw Exception('Failed to decode foreground PNG bitmap');
    }

    // Create a new image filled with the solid background color
    final bg = img.Image(width: fg.width, height: fg.height, numChannels: 4);
    img.fill(bg, color: img.ColorRgba8(r, g, b, 255));

    // Composite the foreground over the solid background
    img.compositeImage(bg, fg);

    if (format == 'jpg' || format == 'jpeg') {
      return Uint8List.fromList(img.encodeJpg(bg, quality: 95));
    } else {
      return Uint8List.fromList(img.encodePng(bg));
    }
  }
}
