import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/format_selector.dart';
import '../../widgets/scale_percentage_selector.dart';
import '../../widgets/target_size_selector.dart';
import '../models/batch_item_model.dart';
import '../notifiers/batch_notifier.dart';

/// Dynamic & Ultra-Compact Settings Card:
/// - If [focusedItem] is null: Displays Global "Default Batch Settings"
/// - If [focusedItem] is non-null: Displays Item-specific "Custom Settings" with thumbnail & reset option.
class BatchSettingsCard extends StatelessWidget {
  final BatchItemModel? focusedItem;
  final int selectedCount;
  final BatchMode activeMode;
  final int selectedTargetSizeKB;
  final int selectedScalePercentage;
  final String outputFormat;
  final TextEditingController customSizeController;
  final ValueChanged<BatchMode> onModeChanged;
  final ValueChanged<int> onTargetSizeKBChanged;
  final ValueChanged<int> onScalePercentageChanged;
  final ValueChanged<String> onOutputFormatChanged;
  final VoidCallback? onResetItemCustom;
  final VoidCallback? onCloseFocus;

  const BatchSettingsCard({
    super.key,
    this.focusedItem,
    this.selectedCount = 0,
    required this.activeMode,
    required this.selectedTargetSizeKB,
    required this.selectedScalePercentage,
    required this.outputFormat,
    required this.customSizeController,
    required this.onModeChanged,
    required this.onTargetSizeKBChanged,
    required this.onScalePercentageChanged,
    required this.onOutputFormatChanged,
    this.onResetItemCustom,
    this.onCloseFocus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMultiSelect = selectedCount > 1;
    final isCustomItem = focusedItem != null || isMultiSelect;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCustomItem
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isCustomItem ? 1.6 : 1.0,
        ),
        boxShadow: [
          if (isCustomItem)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Multi-select vs Single Focused Item vs Global Defaults
          if (isMultiSelect) ...[
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.photo_library_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$selectedCount SELECTED',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Customizing $selectedCount images',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Settings apply to all $selectedCount images',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onResetItemCustom != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: onResetItemCustom,
                    icon: const Icon(Icons.refresh_rounded, size: 13),
                    label: const Text('Reset', style: TextStyle(fontSize: 11)),
                  ),
                if (onCloseFocus != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Back to Batch Defaults',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onCloseFocus,
                  ),
              ],
            ),
          ] else if (focusedItem != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(
                    focusedItem!.file,
                    width: 34,
                    height: 34,
                    fit: BoxFit.cover,
                    cacheWidth: 100,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'CUSTOM IMAGE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              focusedItem!.resolutionString,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        focusedItem!.fileName,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (focusedItem!.hasCustomOptions && onResetItemCustom != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: onResetItemCustom,
                    icon: const Icon(Icons.refresh_rounded, size: 13),
                    label: const Text('Reset', style: TextStyle(fontSize: 11)),
                  ),
                if (onCloseFocus != null)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Back to Batch Defaults',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    onPressed: onCloseFocus,
                  ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Default Batch Settings',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        'Tap any image above to customize individually',
                        style: TextStyle(
                          fontSize: 10,
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
          ],
          const SizedBox(height: 8),

          // 2. Compact Segmented Button: Target Size vs Scale %
          SizedBox(
            width: double.infinity,
            height: 36,
            child: SegmentedButton<BatchMode>(
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 4),
                ),
              ),
              segments: const [
                ButtonSegment<BatchMode>(
                  value: BatchMode.targetSize,
                  label: Text(
                    'Target Size (KB)',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  icon: Icon(Icons.compress_rounded, size: 14),
                ),
                ButtonSegment<BatchMode>(
                  value: BatchMode.scalePercentage,
                  label: Text(
                    'Scale Dimensions',
                    style: TextStyle(fontSize: 11.5),
                  ),
                  icon: Icon(Icons.aspect_ratio_rounded, size: 14),
                ),
              ],
              selected: {activeMode},
              onSelectionChanged: (newSelection) {
                onModeChanged(newSelection.first);
              },
            ),
          ),
          const SizedBox(height: 8),

          // 3. Mode-specific Options (Target Size vs Scale)
          if (activeMode == BatchMode.targetSize)
            TargetSizeSelector(
              selectedSizeKB: selectedTargetSizeKB,
              onSizeChanged: onTargetSizeKBChanged,
              customSizeController: customSizeController,
              isCompact: true,
            )
          else
            ScalePercentageSelector(
              selectedScalePercentage: selectedScalePercentage,
              onScalePercentageChanged: onScalePercentageChanged,
              isSegmented: true,
            ),
          const SizedBox(height: 8),

          // 4. Output Format: Clean Single-Row 3-Segment selector
          FormatSelector(
            selectedFormat: outputFormat,
            onFormatChanged: onOutputFormatChanged,
            isSegmented: true,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
