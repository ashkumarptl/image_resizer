import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';

/// Live animated estimate banner showing approximate output size and savings
class BatchEstimatorBanner extends StatelessWidget {
  final int totalOriginalBytes;
  final int estimatedOutputBytes;
  final int estimatedSavedBytes;
  final double estimatedSavedPercentage;

  const BatchEstimatorBanner({
    super.key,
    required this.totalOriginalBytes,
    required this.estimatedOutputBytes,
    required this.estimatedSavedBytes,
    required this.estimatedSavedPercentage,
  });

  @override
  Widget build(BuildContext context) {
    if (totalOriginalBytes <= 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSavings = estimatedSavedBytes > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: hasSavings
            ? AppColors.success.withValues(alpha: isDark ? 0.2 : 0.1)
            : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasSavings
              ? AppColors.success.withValues(alpha: 0.4)
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: hasSavings
                  ? AppColors.success.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasSavings
                  ? Icons.auto_awesome_rounded
                  : Icons.info_outline_rounded,
              size: 16,
              color: hasSavings ? AppColors.success : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Est. Output: ~${estimatedOutputBytes.toReadableFileSize()}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (hasSavings) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.successContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${estimatedSavedPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (hasSavings)
                  Text(
                    'Saving ~${estimatedSavedBytes.toReadableFileSize()} in total',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
