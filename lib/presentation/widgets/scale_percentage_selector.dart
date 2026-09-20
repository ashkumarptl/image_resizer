import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Reusable Scale Percentage Selector widget for quick image dimension resizing:
/// Defaults to [100%, 75%, 50%, 25%].
class ScalePercentageSelector extends StatelessWidget {
  final int selectedScalePercentage;
  final ValueChanged<int> onScalePercentageChanged;
  final List<int> percentages;
  final bool showHeader;
  final String headerLabel;
  final bool isSegmented;

  const ScalePercentageSelector({
    super.key,
    required this.selectedScalePercentage,
    required this.onScalePercentageChanged,
    this.percentages = const [100, 75, 50, 25],
    this.showHeader = true,
    this.headerLabel = 'Resize Dimensions (% of original)',
    this.isSegmented = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chips = percentages.map((pct) {
      final isSelected = selectedScalePercentage == pct;

      if (!isSegmented) {
        return ChoiceChip(
          label: Text('$pct%'),
          selected: isSelected,
          selectedColor: AppColors.primary,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          onSelected: (sel) {
            if (sel) onScalePercentageChanged(pct);
          },
        );
      }

      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onScalePercentageChanged(pct),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.04)),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.borderDark : AppColors.borderLight),
                ),
              ),
              child: Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  headerLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$selectedScalePercentage%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (isSegmented)
          Row(children: chips)
        else
          Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }
}
