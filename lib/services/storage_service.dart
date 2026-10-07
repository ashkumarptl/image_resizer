import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService._();

  /// Save image to device's public photo gallery using Gal
  static Future<bool> saveToGallery(String filePath) async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final requestGranted = await Gal.requestAccess();
        if (!requestGranted) {
          debugPrint('Storage permission denied by user.');
          return false;
        }
      }

      await Gal.putImage(filePath);
      return true;
    } catch (e) {
      debugPrint('Error saving image to gallery: $e');
      return false;
    }
  }

  /// Save a PDF file to the device's public Downloads or Documents folder
  static Future<File?> savePdfToDevice(
    String sourcePdfPath, {
    String? customFileName,
  }) async {
    try {
      final sourceFile = File(sourcePdfPath);
      if (!await sourceFile.exists()) {
        debugPrint('Source PDF file does not exist: $sourcePdfPath');
        return null;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName ?? 'Doc_$timestamp.pdf';

      Directory? targetDir;

      // 1. Android public Download folder
      if (!kIsWeb && Platform.isAndroid) {
        final androidDownloadDir = Directory('/storage/emulated/0/Download');
        if (await androidDownloadDir.exists()) {
          targetDir = androidDownloadDir;
        }
      }

      // 2. Standard Downloads directory
      targetDir ??= await getDownloadsDirectory();

      // 3. Fallback to Documents directory
      targetDir ??= await getApplicationDocumentsDirectory();

      final destinationPath = '${targetDir.path}/$fileName';
      final savedFile = await sourceFile.copy(destinationPath);
      debugPrint('PDF saved successfully to: $destinationPath');
      return savedFile;
    } catch (e) {
      debugPrint('Error saving PDF to device: $e');
      return null;
    }
  }

  static const List<String> _tempFilePrefixes = [
    'img_tool_',
    'sig_enhanced_',
    'bg_removed_',
    'bg_replaced_',
    'mlkit_safe_',
    'image_tools_batch_',
    'doc_overlay_',
    'perspective_crop_',
    'heic_conv_',
    '_clean_',
    'studio_proxy_',
    'Doc_',
    'scan_',
    'thumb_',
  ];

  static bool _isAppTempFile(String path) {
    for (final prefix in _tempFilePrefixes) {
      if (path.contains(prefix)) return true;
    }
    return false;
  }

  /// Clean old temporary processed files to free device storage without blocking UI thread
  static Future<void> cleanOldCacheFiles({
    Duration maxAge = const Duration(days: 7),
  }) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final now = DateTime.now();

      if (await cacheDir.exists()) {
        await for (final entity in cacheDir.list(followLinks: false)) {
          if (entity is File && _isAppTempFile(entity.path)) {
            try {
              final stat = await entity.stat();
              if (now.difference(stat.modified) > maxAge) {
                await entity.delete();
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }
}
