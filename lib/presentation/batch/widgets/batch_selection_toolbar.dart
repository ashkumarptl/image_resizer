import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';

/// Contextual toolbar displayed when one or more images are selected for bulk action
class BatchSelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int totalCount;
  final bool isAllSelected;
  final VoidCallback onToggleSelectAll;
  final VoidCallback onRemoveSelected;
  final VoidCallback onApplySettingsToSelected;
  final VoidCallback onDeselectAll;

  const BatchSelectionToolbar({
    super.key,
    required this.selectedCount,
    required this.totalCount,
    required this.isAllSelected,
    required this.onToggleSelectAll,
    required this.onRemoveSelected,
    required this.onApplySettingsToSelected,
    required this.onDeselectAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Selection counter & close
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Deselect All',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.lightImpact();
              onDeselectAll();
            },
          ),
          Text(
            '$selectedCount / $totalCount selected',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const Spacer(),

          // Select All / Deselect All
          TextButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              onToggleSelectAll();
            },
            icon: Icon(
              isAllSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 18,
            ),
            label: Text(
              isAllSelected ? 'Deselect' : 'All',
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),

          // Apply current settings to selected (Right/Check icon)
          IconButton(
            icon: const Icon(Icons.check_rounded, size: 21),
            tooltip: 'Apply Settings to Selected Only',
            color: AppColors.primary,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.lightImpact();
              onApplySettingsToSelected();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Applied batch settings to $selectedCount selected items',
                  ),
                  backgroundColor: AppColors.success,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),

          // Remove selected
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            tooltip: 'Delete Selected',
            color: AppColors.error,
            visualDensity: VisualDensity.compact,
            onPressed: () {
              HapticFeedback.lightImpact();
              onRemoveSelected();
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }
}
