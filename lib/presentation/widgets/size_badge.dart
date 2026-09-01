import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/file_size_extension.dart';

class SizeBadge extends StatelessWidget {
  final int sizeBytes;
  final String label;
  final bool isOriginal;

  const SizeBadge({
    super.key,
    required this.sizeBytes,
    required this.label,
    this.isOriginal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = isOriginal
        ? (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight)
        : (isDark ? AppColors.secondaryContainerDark : AppColors.successContainer);

    final textColor = isOriginal
        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
        : (isDark ? AppColors.secondaryLight : AppColors.success);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sizeBytes.toReadableFileSize(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
