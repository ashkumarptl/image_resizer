import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';

/// Displays image count, total raw file size, scan more button,
/// and custom overrides indicator banner.
class BatchHeaderStats extends StatelessWidget {
  final int itemCount;
  final int totalBytes;
  final int customizedCount;
  final bool isProcessing;
  final VoidCallback onScanMorePressed;
  final VoidCallback onResetAllOverrides;

  final bool showCustomOverridesBanner;

  const BatchHeaderStats({
    super.key,
    required this.itemCount,
    required this.totalBytes,
    required this.customizedCount,
    required this.isProcessing,
    required this.onScanMorePressed,
    required this.onResetAllOverrides,
    this.showCustomOverridesBanner = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Row: Count, Size & Add/Scan Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$itemCount Images Selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Total: ${totalBytes.toReadableFileSize()}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isProcessing ? null : onScanMorePressed,
              icon: const Icon(Icons.document_scanner_rounded, size: 16),
              label: const Text('+ Scan More'),
            ),
          ],
        ),

        // Custom Override Banner (only if explicitly enabled to show on top)
        if (showCustomOverridesBanner && customizedCount > 0) ...[
          const SizedBox(height: 12),
          BatchCustomOverridesBanner(
            customizedCount: customizedCount,
            onResetAllOverrides: onResetAllOverrides,
          ),
        ],
      ],
    );
  }
}

/// Standalone indicator banner for custom settings overrides (displayed below cards)
class BatchCustomOverridesBanner extends StatelessWidget {
  final int customizedCount;
  final VoidCallback onResetAllOverrides;

  const BatchCustomOverridesBanner({
    super.key,
    required this.customizedCount,
    required this.onResetAllOverrides,
  });

  @override
  Widget build(BuildContext context) {
    if (customizedCount <= 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryContainerDark.withValues(
          alpha: isDark ? 0.3 : 0.15,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.tune_rounded,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$customizedCount item(s) have custom settings applied.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ),
          TextButton(
            onPressed: onResetAllOverrides,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Reset All',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
