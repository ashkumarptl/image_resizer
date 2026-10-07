import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Result of target size compression optimization
class CompressedImageResult {
  final Uint8List bytes;
  final int quality;
  final img.Image image;

  const CompressedImageResult({
    required this.bytes,
    required this.quality,
    required this.image,
  });
}

/// Shared utility to encode and compress an image to strictly fit under a target max size in bytes.
class TargetSizeCompressor {
  TargetSizeCompressor._();

  /// Compresses [image] to strictly under [targetMaxBytes] using binary search on quality
  /// and intelligent dimension downscaling if needed.
  static CompressedImageResult compressToTargetSize(
    img.Image image, {
    required int targetMaxBytes,
    String format = 'jpg',
    int initialQuality = 85,
    int minQuality = 15,
  }) {
    img.Image working = image;
    final isPng = format.toLowerCase() == 'png';

    if (isPng) {
      final encoded = img.encodePng(working);
      if (encoded.length <= targetMaxBytes) {
        return CompressedImageResult(
          bytes: encoded,
          quality: 100,
          image: working,
        );
      }
      // Iterative dimension scale down for PNG to meet strict target
      while (working.width > 50 && working.height > 50) {
        working = img.copyResize(
          working,
          width: (working.width * 0.85).round(),
          interpolation: img.Interpolation.linear,
        );
        final testBytes = img.encodePng(working);
        if (testBytes.length <= targetMaxBytes) {
          return CompressedImageResult(
            bytes: testBytes,
            quality: 100,
            image: working,
          );
        }
      }
      return CompressedImageResult(
        bytes: img.encodePng(working),
        quality: 100,
        image: working,
      );
    }

    // Binary search for lossy formats (JPG, WebP)
    int low = minQuality;
    int high = initialQuality;
    Uint8List? bestBytes;
    int bestQuality = initialQuality;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final encoded = img.encodeJpg(working, quality: mid);
      if (encoded.length <= targetMaxBytes) {
        bestBytes = encoded;
        bestQuality = mid;
        low = mid + 1; // Try higher quality
      } else {
        high = mid - 1; // Lower quality
      }
    }

    // If lowest quality is still over budget, downscale dimensions
    if (bestBytes == null || bestBytes.length > targetMaxBytes) {
      final currentLen =
          (bestBytes != null && bestBytes.isNotEmpty)
              ? bestBytes.length
              : targetMaxBytes * 2;
      if (currentLen > targetMaxBytes) {
        final scale = (math.sqrt(targetMaxBytes / currentLen) * 0.95).clamp(
          0.10,
          0.85,
        );
        final newW = (working.width * scale).round();
        final newH = (working.height * scale).round();
        if (newW > 50 && newH > 50) {
          working = img.copyResize(
            working,
            width: newW,
            height: newH,
            interpolation: img.Interpolation.linear,
          );
          bestBytes = img.encodeJpg(working, quality: 65);
          bestQuality = 65;
        }
      }

      while ((bestBytes == null || bestBytes.length > targetMaxBytes) &&
          working.width > 50 &&
          working.height > 50) {
        working = img.copyResize(
          working,
          width: (working.width * 0.8).round(),
          height: (working.height * 0.8).round(),
          interpolation: img.Interpolation.linear,
        );
        bestBytes = img.encodeJpg(working, quality: 65);
        bestQuality = 65;
      }
    }

    return CompressedImageResult(
      bytes: bestBytes ?? img.encodeJpg(working, quality: minQuality),
      quality: bestQuality,
      image: working,
    );
  }
}
