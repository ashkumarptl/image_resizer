import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_result.dart';
import '../../../services/image_service/batch_processor.dart';
import '../../widgets/bouncy_tap.dart';
import '../../widgets/gradient_button.dart';
import '../models/batch_item_model.dart';
import 'batch_image_preview_dialog.dart';

/// Card showing completed batch summary (stats, size saved percentage, list of items)
/// plus failure tracking with 1-tap retry, and bulk action buttons.
class BatchResultsView extends StatelessWidget {
  final BatchResult batchResult;
  final VoidCallback onSaveAllToGallery;
  final VoidCallback onExportAsPdf;
  final VoidCallback onShareZip;
  final VoidCallback onSendAllToPc;
  final VoidCallback onReProcess;
  final VoidCallback? onRetryFailed;
  final ValueChanged<ProcessResult> onSaveSingleResult;
  final ValueChanged<ProcessResult> onShareSingleResult;

  const BatchResultsView({
    super.key,
    required this.batchResult,
    required this.onSaveAllToGallery,
    required this.onExportAsPdf,
    required this.onShareZip,
    required this.onSendAllToPc,
    required this.onReProcess,
    this.onRetryFailed,
    required this.onSaveSingleResult,
    required this.onShareSingleResult,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final results = batchResult.results;
    final failures = batchResult.failures;

    final totalOrigBytes = results.fold<int>(
      0,
      (sum, r) => sum + r.originalSizeBytes,
    );
    final totalOutBytes = results.fold<int>(
      0,
      (sum, r) => sum + r.outputSizeBytes,
    );
    final savedBytes = totalOrigBytes - totalOutBytes;
    final savedPct = totalOrigBytes > 0
        ? (savedBytes / totalOrigBytes * 100).clamp(0, 100)
        : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Summary Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: batchResult.isCancelled
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                  : AppColors.success.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: (batchResult.isCancelled
                        ? const Color(0xFFF59E0B)
                        : AppColors.success)
                    .withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    batchResult.isCancelled
                        ? Icons.pause_circle_rounded
                        : Icons.check_circle_rounded,
                    color: batchResult.isCancelled
                        ? const Color(0xFFF59E0B)
                        : AppColors.success,
                    size: 24,
                  ).animate().scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1, 1),
                    curve: Curves.easeOutBack,
                    duration: 350.ms,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      batchResult.isCancelled
                          ? 'Batch Paused (${results.length} Files)'
                          : 'Batch Complete (${results.length} Files)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (savedBytes > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '-${savedPct.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    )
                        .animate()
                        .scale(delay: 150.ms, curve: Curves.easeOutBack)
                        .shimmer(delay: 500.ms, duration: 1200.ms),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Size: ${totalOrigBytes.toReadableFileSize()} ➔ ${totalOutBytes.toReadableFileSize()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    'Time: ${batchResult.totalDuration.inSeconds}s',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),

              if (results.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                // Individual Results List
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: results.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (context, idx) {
                    final item = results[idx];
                    return Row(
                      children: [
                        // Thumbnail of processed image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(item.outputPath),
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            cacheWidth: 100,
                            errorBuilder: (_, _, _) => Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.image, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Text details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Image #${idx + 1} (${item.outputFormat.toUpperCase()})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.originalSizeBytes.toReadableFileSize()} ➔ ${item.outputSizeBytes.toReadableFileSize()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action icons
                        IconButton(
                          icon: const Icon(
                            Icons.fullscreen_rounded,
                            size: 20,
                          ),
                          tooltip: 'Preview',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            final batchItem = BatchItemModel.fromFile(
                              File(item.outputPath),
                            );
                            BatchImagePreviewDialog.show(
                              context,
                              item: batchItem,
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.save_alt_rounded, size: 20),
                          tooltip: 'Save to Gallery',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onSaveSingleResult(item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 20),
                          tooltip: 'Share',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => onShareSingleResult(item),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

        // 2. Failed Items Section & Single-Tap Retry Button
        if (failures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${failures.length} Image${failures.length > 1 ? 's' : ''} Failed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    if (onRetryFailed != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          onRetryFailed!();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Retry Failed',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                ...failures.map((fail) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cancel_outlined,
                          size: 14,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            fail.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms),
        ],

        const SizedBox(height: 20),

        // 3. Bulk Actions
        if (results.isNotEmpty) ...[
          GradientButton(
            text: '💾 Save All to Gallery',
            icon: Icons.download_rounded,
            onPressed: onSaveAllToGallery,
          ),
          const SizedBox(height: 12),

          BouncyTap(
            pressedScale: 0.97,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onExportAsPdf,
                icon: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: AppColors.primary,
                ),
                label: const Text(
                  '📄 Export / Save as PDF Document',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          if (batchResult.zipFilePath != null) ...[
            BouncyTap(
              pressedScale: 0.97,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: onShareZip,
                  icon: const Icon(Icons.folder_zip_outlined),
                  label: const Text('Share ZIP Archive'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          BouncyTap(
            pressedScale: 0.97,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: onSendAllToPc,
                icon: const Icon(Icons.laptop_chromebook_rounded),
                label: const Text('Send All to PC (Wi-Fi Share)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Reset / Process another batch
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton.icon(
            onPressed: onReProcess,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Adjust Settings & Re-process'),
          ),
        ),
      ],
    );
  }
}
