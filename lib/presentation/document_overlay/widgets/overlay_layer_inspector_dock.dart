import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/overlay_item_model.dart';

/// Bottom inspector dock displayed when a layer is selected.
class OverlayLayerInspectorDock extends StatelessWidget {
  final OverlayItemModel layer;
  final bool isDark;
  final VoidCallback onDeselect;
  final VoidCallback onRotate90;
  final VoidCallback onToggleBorder;
  final VoidCallback onCenter;
  final VoidCallback onFitSize;
  final VoidCallback onBringToFront;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const OverlayLayerInspectorDock({
    super.key,
    required this.layer,
    required this.isDark,
    required this.onDeselect,
    required this.onRotate90,
    required this.onToggleBorder,
    required this.onCenter,
    required this.onFitSize,
    required this.onBringToFront,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inspector Header: Layer Title & Deselect button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      layer.type == OverlayItemType.signature
                          ? Icons.draw_rounded
                          : Icons.photo_library_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EDITING: ${layer.label.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDeselect();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Action Buttons Row
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMiniActionButton(
                      icon: Icons.rotate_90_degrees_cw_rounded,
                      label: 'Rotate 90°',
                      onTap: onRotate90,
                    ),
                    _buildMiniActionButton(
                      icon: layer.hasBorder
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      label: 'Cut Border',
                      isActive: layer.hasBorder,
                      onTap: onToggleBorder,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.filter_center_focus_rounded,
                      label: 'Center',
                      onTap: onCenter,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.fit_screen_rounded,
                      label: 'Fit Size',
                      onTap: onFitSize,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.vertical_align_top_rounded,
                      label: 'Bring Front',
                      onTap: onBringToFront,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Duplicate',
                      onTap: onDuplicate,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: onDelete,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool isActive = false,
  }) {
    final defaultColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final c = color ?? (isActive ? AppColors.primary : defaultColor);
    final activeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: c),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: c,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
