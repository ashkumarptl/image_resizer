import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/scanner/document_scanner_service.dart';

/// Available sources for selecting or scanning images in the app.
enum AppImageSource {
  smartScanner,
  gallery,
}

/// Unified entry point for document and image scanning using Google ML Kit Document Scanner,
/// with automatic graceful fallback to standard [ImagePicker] if native scanner is unavailable
/// (e.g., during development hot reloads, unsupported platforms, or missing Google Play Services).
class ImageSourcePickerSheet {
  /// Launches Google ML Kit Document Scanner for single image/document capture or gallery import.
  /// Falls back to standard [ImagePicker] if ML Kit native implementation is unavailable.
  static Future<File?> show(
    BuildContext context, {
    String title = 'Scan Document / Photo',
    String subtitle = '',
    bool enableSmartScanner = true,
  }) async {
    if (enableSmartScanner) {
      try {
        final scannerService = DocumentScannerService();
        return await scannerService.scanSingleDocument();
      } on MissingPluginException catch (e) {
        debugPrint('[ImageSourcePickerSheet] ML Kit Document Scanner not registered ($e). Falling back to ImagePicker.');
      } catch (e) {
        final str = e.toString().toLowerCase();
        if (str.contains('cancel')) return null;
        debugPrint('[ImageSourcePickerSheet] Scanner error ($e). Falling back to ImagePicker.');
      }
    }

    // Graceful fallback to standard gallery picker
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      return picked != null ? File(picked.path) : null;
    } catch (e) {
      debugPrint('[ImageSourcePickerSheet] Fallback ImagePicker error: $e');
      return null;
    }
  }

  /// Launches Google ML Kit Document Scanner in batch mode (up to [maxPages] pages).
  /// Falls back to [ImagePicker.pickMultiImage] if ML Kit native implementation is unavailable.
  static Future<List<File>> showMulti(
    BuildContext context, {
    String title = 'Scan Documents / Photos',
    String subtitle = '',
    int maxPages = 25,
  }) async {
    try {
      final scannerService = DocumentScannerService();
      return await scannerService.scanMultipleDocuments(pageLimit: maxPages);
    } on MissingPluginException catch (e) {
      debugPrint('[ImageSourcePickerSheet] ML Kit Document Scanner not registered ($e). Falling back to ImagePicker.');
    } catch (e) {
      final str = e.toString().toLowerCase();
      if (str.contains('cancel')) return [];
      debugPrint('[ImageSourcePickerSheet] Scanner error ($e). Falling back to ImagePicker.');
    }

    // Graceful fallback to standard multi-image picker
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(limit: maxPages);
      return pickedList.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('[ImageSourcePickerSheet] Fallback ImagePicker multi error: $e');
      return [];
    }
  }
}
