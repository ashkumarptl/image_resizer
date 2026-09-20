import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/process_result.dart';
import '../../../services/scanner/document_scanner_service.dart';
import '../../../services/share_service.dart';
import '../../result/result_screen.dart';

/// Modal bottom sheet presented upon successful document export, allowing
/// direct A4 PDF export/print, Gallery save via ResultScreen, or Image sharing.
class OverlayExportModal {
  static Future<void> show(BuildContext context, ProcessResult result) async {
    final file = File(result.outputPath);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Document Ready!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '300 DPI High-Quality Print Ready (${result.outputWidth} × ${result.outputHeight})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text(
                      'Export & Print as A4 PDF',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Direct printable PDF file'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final pdfFile =
                          await DocumentScannerService.createPdfFromImages([
                            file,
                          ]);
                      if (context.mounted) {
                        await ShareService.shareImage(
                          pdfFile.path,
                          text: 'Printable Document A4',
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.amber,
                    ),
                    title: const Text(
                      'View & Save to Gallery',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('Open in Result Screen to save image'),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ResultScreen(result: result),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.share_rounded,
                      color: AppColors.secondary,
                    ),
                    title: const Text(
                      'Share Image',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ShareService.shareImage(file.path);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
