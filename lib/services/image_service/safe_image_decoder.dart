import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Provides memory-safe decoding with OOM protection for ultra-high-resolution
/// images (e.g. 48MP, 64MP, 108MP camera photos) on budget and low-RAM devices.
class SafeImageDecoder {
  SafeImageDecoder._();

  /// Maximum pixel count before downsampling is enforced (~20 MegaPixels)
  static const int defaultMaxPixels = 20 * 1000 * 1000;

  /// Maximum single dimension (width or height) allowed before downsampling (4K UHD)
  static const int defaultMaxDimension = 4096;

  /// Fast header-only inspection: Reads image dimensions (width & height)
  /// in ~0.5ms without allocating pixel buffers in heap memory.
  static ({int width, int height})? readHeaderDimensions(Uint8List bytes) {
    try {
      final decoder = img.findDecoderForData(bytes);
      if (decoder != null) {
        final info = decoder.startDecode(bytes);
        if (info != null && info.width > 0 && info.height > 0) {
          int w = info.width;
          int h = info.height;

          // Check EXIF orientation (orientations 5, 6, 7, 8 swap width and height)
          if (decoder is img.JpegDecoder) {
            try {
              final exif = img.ExifData.fromInputBuffer(img.InputBuffer(bytes));
              if (exif.imageIfd.hasOrientation) {
                final orientation = exif.imageIfd.orientation;
                if (orientation != null &&
                    orientation >= 5 &&
                    orientation <= 8) {
                  final temp = w;
                  w = h;
                  h = temp;
                }
              }
            } catch (_) {}
          }
          return (width: w, height: h);
        }
      }
    } catch (e) {
      debugPrint('[SafeImageDecoder] Error reading header dimensions: $e');
    }
    return null;
  }

  /// Memory-safe image decoder.
  /// If the image exceeds [maxPixels] or [maxDimension] (such as 48MP, 64MP, 108MP photos),
  /// it leverages Flutter's native C++ Skia engine (`ui.instantiateImageCodec`) to
  /// downsample during IDCT decoding directly in native memory, avoiding massive Dart heap spikes.
  static Future<img.Image?> decodeSafe(
    Uint8List bytes, {
    int maxDimension = defaultMaxDimension,
    int maxPixels = defaultMaxPixels,
  }) async {
    final header = readHeaderDimensions(bytes);

    // If header inspection fails or image is within safe memory limits,
    // standard Dart decoding can be attempted.
    if (header == null ||
        (header.width * header.height <= maxPixels &&
            header.width <= maxDimension &&
            header.height <= maxDimension)) {
      try {
        return img.decodeImage(bytes);
      } catch (e) {
        debugPrint('[SafeImageDecoder] Standard decode failed: $e');
      }
    }

    final origW = header?.width ?? 0;
    final origH = header?.height ?? 0;

    // Calculate downsampled target dimensions keeping exact aspect ratio
    int targetW = origW;
    int targetH = origH;

    if (origW > 0 && origH > 0) {
      final scaleDim = maxDimension / math.max(origW, origH);
      final scalePixels = math.sqrt(maxPixels / (origW * origH));
      final scale = math.min(scaleDim, scalePixels);

      if (scale < 1.0) {
        targetW = (origW * scale).round().clamp(1, origW);
        targetH = (origH * scale).round().clamp(1, origH);
        debugPrint(
          '[SafeImageDecoder] OOM Protection: Decimating ${origW}x$origH (~${((origW * origH) / 1e6).toStringAsFixed(1)}MP) '
          'to ${targetW}x$targetH to protect heap memory.',
        );
      }
    }

    // Attempt native C++ Skia engine downsampling (Zero Dart heap spike)
    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetW > 0 ? targetW : null,
        targetHeight: targetH > 0 ? targetH : null,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData != null) {
        return img.Image.fromBytes(
          width: frame.image.width,
          height: frame.image.height,
          bytes: byteData.buffer,
          order: img.ChannelOrder.rgba,
        );
      }
    } catch (e) {
      debugPrint('[SafeImageDecoder] Native engine downsampling fallback: $e');
    }

    // Fallback: standard decode + resize
    try {
      final fallbackImage = img.decodeImage(bytes);
      if (fallbackImage != null &&
          (targetW < fallbackImage.width || targetH < fallbackImage.height)) {
        return img.copyResize(
          fallbackImage,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }
      return fallbackImage;
    } catch (e) {
      debugPrint('[SafeImageDecoder] Ultimate fallback decode failed: $e');
      return null;
    }
  }

  /// Ensures an image file is safe for ML Kit processing (max dimension ~2048px).
  /// If the image is larger, downsamples it and returns a temporary file.
  /// Prevents ML Kit and Google Play Services crashes on 48MP/108MP camera photos.
  static Future<File> ensureSafeForMlKit(
    File sourceFile, {
    int maxDimension = 2048,
  }) async {
    if (!sourceFile.existsSync()) return sourceFile;

    try {
      final bytes = sourceFile.readAsBytesSync();
      final header = readHeaderDimensions(bytes);

      if (header != null &&
          (header.width > maxDimension || header.height > maxDimension)) {
        final decoded = await decodeSafe(
          bytes,
          maxDimension: maxDimension,
          maxPixels: maxDimension * maxDimension,
        );

        if (decoded != null) {
          String tempDirPath;
          if (Platform.environment.containsKey('FLUTTER_TEST')) {
            tempDirPath = Directory.systemTemp.path;
          } else {
            try {
              final cacheDir = await getTemporaryDirectory();
              tempDirPath = cacheDir.path;
            } catch (_) {
              tempDirPath = Directory.systemTemp.path;
            }
          }
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final downscaledPath = p.join(
            tempDirPath,
            'mlkit_safe_$timestamp.jpg',
          );
          final downscaledFile = File(downscaledPath);
          await downscaledFile.writeAsBytes(
            img.encodeJpg(decoded, quality: 92),
            flush: true,
          );
          return downscaledFile;
        }
      }
    } catch (e) {
      debugPrint('[SafeImageDecoder] ML Kit pre-scale warning: $e');
    }

    return sourceFile;
  }
}
