import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../services/scanner/document_scanner_service.dart';

/// Available sources for selecting or scanning images in the app.
enum AppImageSource {
  smartScanner,
  gallery,
}

/// Unified bottom sheet entry point for selecting images or scanning documents
/// offering both Google ML Kit Document Scanner and Import from Gallery options.
class ImageSourcePickerSheet {
  /// Shows a modal bottom sheet allowing the user to choose between:
  /// 1. Smart Document Scanner (Google ML Kit)
  /// 2. Import from Gallery (ImagePicker)
  ///
  /// Falls back gracefully to Gallery if ML Kit is unavailable.
  static Future<File?> show(
    BuildContext context, {
    String title = 'Select Photo / Document',
    String subtitle = 'Choose how you want to add your image',
    bool enableSmartScanner = true,
  }) async {
    if (!enableSmartScanner) {
      return _pickFromGallery();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<AppImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Smart Document Scanner',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ML KIT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Camera with auto-edge detection & perspective crop',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(AppImageSource.smartScanner),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  title: Text(
                    'Import from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Choose an existing photo from your device',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(AppImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return null;

    if (source == AppImageSource.smartScanner) {
      try {
        final scannerService = DocumentScannerService();
        final file = await scannerService.scanSingleDocument();
        if (file != null) return file;
      } on MissingPluginException catch (e) {
        debugPrint('[ImageSourcePickerSheet] ML Kit Document Scanner not registered ($e). Falling back to ImagePicker.');
      } catch (e) {
        final str = e.toString().toLowerCase();
        if (str.contains('cancel')) return null;
        debugPrint('[ImageSourcePickerSheet] Scanner error ($e). Falling back to ImagePicker.');
      }
    }

    return _pickFromGallery();
  }

  /// Shows a modal bottom sheet allowing the user to choose between:
  /// 1. Batch Document Scanner (Google ML Kit)
  /// 2. Import from Gallery (ImagePicker.pickMultiImage)
  static Future<List<File>> showMulti(
    BuildContext context, {
    String title = 'Select Images Source',
    String subtitle = 'Choose how you want to add batch images',
    int maxPages = 25,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final source = await showModalBottomSheet<AppImageSource>(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary, size: 24),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Batch Document Scanner',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ML KIT',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    'Multi-page camera scanner with auto-boundary detection',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(AppImageSource.smartScanner),
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  tileColor: isDark
                      ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                      : AppColors.surfaceVariantLight,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  title: Text(
                    'Import from Gallery',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  subtitle: Text(
                    'Select multiple photos from your library',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(AppImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return [];

    if (source == AppImageSource.smartScanner) {
      try {
        final scannerService = DocumentScannerService();
        final files = await scannerService.scanMultipleDocuments(pageLimit: maxPages);
        if (files.isNotEmpty) return files;
      } on MissingPluginException catch (e) {
        debugPrint('[ImageSourcePickerSheet] ML Kit Document Scanner not registered ($e). Falling back to ImagePicker.');
      } catch (e) {
        final str = e.toString().toLowerCase();
        if (str.contains('cancel')) return [];
        debugPrint('[ImageSourcePickerSheet] Scanner error ($e). Falling back to ImagePicker.');
      }
    }

    return _pickMultiFromGallery(maxPages);
  }

  static Future<File?> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      return picked != null ? File(picked.path) : null;
    } catch (e) {
      debugPrint('[ImageSourcePickerSheet] Gallery picker error: $e');
      return null;
    }
  }

  static Future<List<File>> _pickMultiFromGallery(int maxPages) async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(limit: maxPages);
      return pickedList.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('[ImageSourcePickerSheet] Gallery multi-picker error: $e');
      return [];
    }
  }
}
