import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/image_service/document_overlay_compositor.dart';

/// Bottom dock displaying page format switches (A4 Portrait, A4 Landscape, Original Doc)
/// and the Move/Center on A4 toggle.
class OverlayPageFormatDock extends StatelessWidget {
  final CanvasPageSize pageSize;
  final bool hasInitialImage;
  final bool isBaseDocumentDeleted;
  final bool baseDocumentAsLayer;
  final bool isDark;
  final ValueChanged<CanvasPageSize> onPageSizeChanged;
  final VoidCallback onToggleBaseDocumentAsLayer;

  const OverlayPageFormatDock({
    super.key,
    required this.pageSize,
    required this.hasInitialImage,
    required this.isBaseDocumentDeleted,
    required this.baseDocumentAsLayer,
    required this.isDark,
    required this.onPageSizeChanged,
    required this.onToggleBaseDocumentAsLayer,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.aspect_ratio_rounded,
                  size: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 5),
                Text(
                  'PAGE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            if (hasInitialImage && !isBaseDocumentDeleted) ...[
              _buildPresetChip(
                label: 'Original Doc',
                icon: Icons.image_outlined,
                isSelected: pageSize == CanvasPageSize.matchDocument,
                onTap: () => onPageSizeChanged(CanvasPageSize.matchDocument),
              ),
              const SizedBox(width: 8),
            ],
            _buildPresetChip(
              label: 'A4 Portrait',
              icon: Icons.portrait_rounded,
              isSelected: pageSize == CanvasPageSize.a4Portrait,
              onTap: () => onPageSizeChanged(CanvasPageSize.a4Portrait),
            ),
            const SizedBox(width: 8),
            _buildPresetChip(
              label: 'A4 Landscape',
              icon: Icons.landscape_rounded,
              isSelected: pageSize == CanvasPageSize.a4Landscape,
              onTap: () => onPageSizeChanged(CanvasPageSize.a4Landscape),
            ),
            if (hasInitialImage &&
                !isBaseDocumentDeleted &&
                pageSize != CanvasPageSize.matchDocument) ...[
              const SizedBox(width: 8),
              _buildPresetChip(
                label: baseDocumentAsLayer ? 'Center on A4' : 'Move on A4',
                icon: baseDocumentAsLayer
                    ? Icons.center_focus_strong_rounded
                    : Icons.open_with_rounded,
                isSelected: baseDocumentAsLayer,
                isAccent: true,
                onTap: onToggleBaseDocumentAsLayer,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    bool isAccent = false,
  }) {
    final activeBg = AppColors.primary;
    final inactiveBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 2 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isAccent
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : (isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isAccent
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isAccent
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
