import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FormatItem {
  final String id;
  final String label;
  final String? subtitle;

  const FormatItem({required this.id, required this.label, this.subtitle});
}

/// Reusable Format Selector widget supporting JPG, WebP, and PNG.
/// Provides both compact segmented row style and wrapped chip style.
class FormatSelector extends StatelessWidget {
  final String selectedFormat;
  final ValueChanged<String> onFormatChanged;
  final List<FormatItem> formats;
  final bool isSegmented;

  static const List<FormatItem> defaultFormats = [
    FormatItem(id: 'jpg', label: 'JPG', subtitle: 'Universal'),
    FormatItem(id: 'webp', label: 'WEBP', subtitle: 'Compact'),
    FormatItem(id: 'png', label: 'PNG', subtitle: 'Sharp'),
  ];

  const FormatSelector({
    super.key,
    required this.selectedFormat,
    required this.onFormatChanged,
    this.formats = defaultFormats,
    this.isSegmented = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentFormat = selectedFormat.toLowerCase();

    if (isSegmented) {
      return Row(
        children: formats.map((entry) {
          final isSelected = currentFormat == entry.id.toLowerCase();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => onFormatChanged(entry.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 5),
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
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected) ...[
                        const Icon(
                          Icons.check_rounded,
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        entry.label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: formats.map((entry) {
        final isSelected = currentFormat == entry.id.toLowerCase();
        return ChoiceChip(
          label: Text(entry.label),
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
            if (sel) onFormatChanged(entry.id);
          },
        );
      }).toList(),
    );
  }
}
