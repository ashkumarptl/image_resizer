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

  /// Clean old temporary processed files to free device storage
  static Future<void> cleanOldCacheFiles({Duration maxAge = const Duration(days: 7)}) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final now = DateTime.now();

      if (cacheDir.existsSync()) {
        final files = cacheDir.listSync();
        for (final entity in files) {
          if (entity is File && entity.path.contains('img_tool_')) {
            final stat = entity.statSync();
            if (now.difference(stat.modified) > maxAge) {
              entity.deleteSync();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error cleaning cache: $e');
    }
  }
}
