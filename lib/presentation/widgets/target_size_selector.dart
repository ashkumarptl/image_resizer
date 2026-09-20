import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';

/// Reusable Target Size Selector widget providing:
/// - Quick preset size chips (e.g. 20, 50, 100, 200, 500 KB)
/// - Integrated or standalone Custom KB input field with validation
class TargetSizeSelector extends StatelessWidget {
  final int selectedSizeKB;
  final ValueChanged<int> onSizeChanged;
  final TextEditingController? customSizeController;
  final List<int> presetSizes;
  final bool isCompact;
  final bool showCustomField;
  final int minKB;
  final int maxKB;
  final String customLabel;

  const TargetSizeSelector({
    super.key,
    required this.selectedSizeKB,
    required this.onSizeChanged,
    this.customSizeController,
    this.presetSizes = AppConstants.defaultTargetSizesKB,
    this.isCompact = true,
    this.showCustomField = true,
    this.minKB = 5,
    this.maxKB = 50000,
    this.customLabel = 'Custom Target Size',
  });

  void _handleCustomInput(String val) {
    final parsed = int.tryParse(val.trim());
    if (parsed != null && parsed >= minKB && parsed <= maxKB) {
      onSizeChanged(parsed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final chipsList = presetSizes.map((sizeKB) {
      final isSelected = selectedSizeKB == sizeKB;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            if (customSizeController != null) {
              customSizeController!.text = sizeKB.toString();
            }
            onSizeChanged(sizeKB);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            child: Row(
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
                  '$sizeKB KB',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
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
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isCompact)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(children: chipsList),
          )
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chipsList,
          ),
        if (showCustomField && customSizeController != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: TextField(
              controller: customSizeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                labelText: customLabel,
                labelStyle: const TextStyle(fontSize: 11),
                hintText: 'e.g. 75, 150',
                hintStyle: const TextStyle(fontSize: 11),
                isDense: true,
                suffixText: 'KB',
                suffixStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: _handleCustomInput,
            ),
          ),
        ],
      ],
    );
  }
}
