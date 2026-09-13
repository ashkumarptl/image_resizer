import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../system_integration_service.dart';

class HeicConverter {
  HeicConverter._();

  /// Determines whether the given file is in HEIC or HEIF format.
  /// Checks file extension and examines ISO base media file format (ftyp) magic bytes.
  static bool isHeicFile(String filePath) {
    final ext = p.extension(filePath).toLowerCase();
    if (ext == '.heic' || ext == '.heif') return true;

    try {
      final file = File(filePath);
      if (!file.existsSync()) return false;
      final fileLength = file.lengthSync();
      if (fileLength < 12) return false;

      final raf = file.openSync();
      try {
        final header = raf.readSync(12);
        if (header.length >= 12) {
          final ftyp = String.fromCharCodes(header.sublist(4, 8));
          if (ftyp == 'ftyp') {
            final brand = String.fromCharCodes(
              header.sublist(8, 12),
            ).toLowerCase();
            if (brand.contains('hei') ||
                brand.contains('mif') ||
                brand.contains('msf') ||
                brand.contains('hevc') ||
                brand.contains('avif')) {
              return true;
            }
          }
        }
      } finally {
        raf.closeSync();
      }
    } catch (_) {}

    return false;
  }

  /// Converts a HEIC/HEIF image to a standard, universally decodable JPEG image.
  /// If the file is not HEIC, the original [filePath] is returned immediately.
  static Future<String> ensureCompatibleImage(String filePath) async {
    if (!isHeicFile(filePath)) {
      return filePath;
    }

    try {
      final sourceFile = File(filePath);
      if (!sourceFile.existsSync()) return filePath;

      String tempDir;
      try {
        tempDir = (await getTemporaryDirectory()).path;
      } catch (_) {
        tempDir = Directory.systemTemp.path;
      }

      final fileName = p.basenameWithoutExtension(filePath);
      final destPath = p.join(
        tempDir,
        '${fileName}_converted_${sourceFile.lengthSync()}.jpg',
      );

      final cachedFile = File(destPath);
      if (cachedFile.existsSync() && cachedFile.lengthSync() > 0) {
        return destPath;
      }

      // 1. Try native platform conversion (Android hardware-accelerated decoder)
      if (!kIsWeb &&
          Platform.isAndroid &&
          !Platform.environment.containsKey('FLUTTER_TEST')) {
        final converted = await SystemIntegrationService.instance
            .convertHeicToJpeg(filePath, targetPath: destPath);
        if (converted != null &&
            File(converted).existsSync() &&
            File(converted).lengthSync() > 0) {
          debugPrint(
            '[HeicConverter] Converted HEIC via native Android decoder: $converted',
          );
          return converted;
        }
      }

      // 2. Engine fallback using Flutter's native decoder (Skia/Impeller)
      final bytes = await sourceFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        final pngBytes = byteData.buffer.asUint8List();
        final decoded = img.decodePng(pngBytes);
        if (decoded != null) {
          final jpgBytes = img.encodeJpg(decoded, quality: 85);
          await cachedFile.parent.create(recursive: true);
          await cachedFile.writeAsBytes(jpgBytes);
          debugPrint(
            '[HeicConverter] Converted HEIC via engine fallback: $destPath',
          );
          return destPath;
        }
      }
    } catch (e) {
      debugPrint('[HeicConverter] Error converting HEIC: $e');
    }

    return filePath;
  }
}
