import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/file_size_extension.dart';

class SizeBadge extends StatelessWidget {
  final int sizeBytes;
  final String label;
  final bool isOriginal;
  final bool isIncreased;

  const SizeBadge({
    super.key,
    required this.sizeBytes,
    required this.label,
    this.isOriginal = false,
    this.isIncreased = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor;
    final Color textColor;

    if (isOriginal) {
      bgColor = isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight;
      textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    } else if (isIncreased) {
      bgColor = isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber.shade100;
      textColor = isDark ? Colors.amber.shade300 : Colors.amber.shade900;
    } else {
      bgColor = isDark ? AppColors.secondaryContainerDark : AppColors.successContainer;
      textColor = isDark ? AppColors.secondaryLight : AppColors.success;
    }

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
