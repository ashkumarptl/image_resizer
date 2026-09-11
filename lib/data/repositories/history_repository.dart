import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../services/image_service/safe_image_decoder.dart';
import '../models/history_item.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return HistoryRepository();
});

class _ThumbnailParam {
  final String sourcePath;
  final String targetPath;

  const _ThumbnailParam(this.sourcePath, this.targetPath);
}

class HistoryRepository {
  static const String _historyKey = 'image_tools_history';
  static const int thumbnailSize = 120;

  Future<Directory> _getThumbnailDirectory() async {
    String basePath;
    try {
      final tempDir = await getTemporaryDirectory();
      basePath = tempDir.path;
    } catch (_) {
      basePath = Directory.systemTemp.path;
    }
    final thumbDir = Directory(p.join(basePath, 'history_thumbs'));
    if (!thumbDir.existsSync()) {
      await thumbDir.create(recursive: true);
    }
    return thumbDir;
  }

  static Future<String?> _generateThumbnailInternal(_ThumbnailParam param) async {
    try {
      final sourceFile = File(param.sourcePath);
      if (!sourceFile.existsSync()) return null;

      final bytes = sourceFile.readAsBytesSync();
      // Fast downsampled decode for thumbnail to prevent massive heap spikes on large camera images
      final image = await SafeImageDecoder.decodeSafe(bytes, maxDimension: 360);
      if (image == null) return null;

      // Generate 120x120 square thumbnail for fast home list preview
      final thumbnail = img.copyResizeCropSquare(image, size: thumbnailSize);

      final targetFile = File(param.targetPath);
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsBytesSync(img.encodeJpg(thumbnail, quality: 80));
      return targetFile.path;
    } catch (_) {
      return null;
    }
  }

  /// Generates a 120x120 cached thumbnail for a given source image
  Future<String?> generateThumbnail(String sourcePath, String itemId) async {
    try {
      final dir = await _getThumbnailDirectory();
      final targetPath = p.join(dir.path, 'thumb_$itemId.jpg');
      final targetFile = File(targetPath);
      if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
        return targetPath;
      }

      final param = _ThumbnailParam(sourcePath, targetPath);
      final bool isTest = Platform.environment.containsKey('FLUTTER_TEST') ||
          Platform.environment['FLUTTER_TEST'] == 'true' ||
          WidgetsBinding.instance.runtimeType.toString().contains('Test');

      if (isTest) {
        return await _generateThumbnailInternal(param);
      } else {
        return await compute(_generateThumbnailInternal, param);
      }
    } catch (_) {
      return null;
    }
  }

  Future<List<HistoryItem>> getRecentHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJsonList = prefs.getStringList(_historyKey) ?? [];

      final items = <HistoryItem>[];
      bool needsUpdate = false;

      for (final jsonStr in historyJsonList) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final item = HistoryItem.fromJson(map);
          // Only include if file still exists
          if (File(item.filePath).existsSync()) {
            items.add(item);
          } else {
            needsUpdate = true;
            _deleteFileQuietly(item.thumbnailPath);
          }
        } catch (_) {}
      }

      if (needsUpdate) {
        final stringList = items.map((i) => jsonEncode(i.toJson())).toList();
        await prefs.setStringList(_historyKey, stringList);
      }

      // Backfill missing thumbnails in background if any exist without one
      _backfillMissingThumbnails(items);

      return items;
    } catch (_) {
      return [];
    }
  }

  void _backfillMissingThumbnails(List<HistoryItem> items) {
    Future(() async {
      try {
        bool changed = false;
        final updatedItems = <HistoryItem>[];

        for (final item in items) {
          if (item.thumbnailPath == null || !File(item.thumbnailPath!).existsSync()) {
            final thumbPath = await generateThumbnail(item.filePath, item.id);
            if (thumbPath != null) {
              updatedItems.add(item.copyWith(thumbnailPath: thumbPath));
              changed = true;
              continue;
            }
          }
          updatedItems.add(item);
        }

        if (changed) {
          final prefs = await SharedPreferences.getInstance();
          final stringList = updatedItems.map((i) => jsonEncode(i.toJson())).toList();
          await prefs.setStringList(_historyKey, stringList);
        }
      } catch (_) {}
    });
  }

  Future<void> addHistoryItem(HistoryItem item) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentList = await getRecentHistory();

      // Generate thumbnail if not already present or existing
      HistoryItem itemToAdd = item;
      if (item.thumbnailPath == null || !File(item.thumbnailPath!).existsSync()) {
        final thumbPath = await generateThumbnail(item.filePath, item.id);
        if (thumbPath != null) {
          itemToAdd = item.copyWith(thumbnailPath: thumbPath);
        }
      }

      // Remove existing if duplicate and clean its old thumbnail if different
      final removed = <HistoryItem>[];
      currentList.removeWhere((i) {
        if (i.filePath == itemToAdd.filePath) {
          removed.add(i);
          return true;
        }
        return false;
      });
      for (final oldItem in removed) {
        if (oldItem.thumbnailPath != null && oldItem.thumbnailPath != itemToAdd.thumbnailPath) {
          _deleteFileQuietly(oldItem.thumbnailPath);
        }
      }

      // Insert at front
      currentList.insert(0, itemToAdd);

      // Trim if exceeds max and delete trimmed thumbnail files
      if (currentList.length > AppConstants.maxHistoryItems) {
        final trimmed = currentList.sublist(AppConstants.maxHistoryItems);
        for (final trimmedItem in trimmed) {
          _deleteFileQuietly(trimmedItem.thumbnailPath);
        }
        currentList.removeRange(AppConstants.maxHistoryItems, currentList.length);
      }

      final stringList = currentList.map((i) => jsonEncode(i.toJson())).toList();
      await prefs.setStringList(_historyKey, stringList);
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);

      // Delete the thumbnail directory contents
      final dir = await _getThumbnailDirectory();
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }

  void _deleteFileQuietly(String? path) {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }
}
