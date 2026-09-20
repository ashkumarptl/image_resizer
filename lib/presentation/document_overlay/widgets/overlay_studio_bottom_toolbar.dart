import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';

/// Bottom toolbar matching Edit Studio visual design with quick actions for
/// Add Photo, Signature, ID Cards, Format, and Layers.
class OverlayStudioBottomToolbar extends StatelessWidget {
  final bool isDark;
  final bool isLayerSelected;
  final int layerCount;
  final VoidCallback onAddPhoto;
  final VoidCallback onAddSignature;
  final VoidCallback onIdCardDuo;
  final VoidCallback onFormatTap;
  final VoidCallback onLayersTap;

  const OverlayStudioBottomToolbar({
    super.key,
    required this.isDark,
    required this.isLayerSelected,
    required this.layerCount,
    required this.onAddPhoto,
    required this.onAddSignature,
    required this.onIdCardDuo,
    required this.onFormatTap,
    required this.onLayersTap,
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
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildToolButton(
                  context,
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'ADD PHOTO',
                  isActive: false,
                  onTap: onAddPhoto,
                ),
              ),
              Expanded(
                child: _buildToolButton(
                  context,
                  icon: Icons.draw_rounded,
                  label: 'SIGNATURE',
                  isActive: false,
                  onTap: onAddSignature,
                ),
              ),
              Expanded(
                child: _buildToolButton(
                  context,
                  icon: Icons.badge_rounded,
                  label: 'ID CARDS',
                  badgeText: 'A4',
                  isActive: false,
                  onTap: onIdCardDuo,
                ),
              ),
              Expanded(
                child: _buildToolButton(
                  context,
                  icon: Icons.description_outlined,
                  label: 'FORMAT',
                  isActive: !isLayerSelected,
                  onTap: onFormatTap,
                ),
              ),
              Expanded(
                child: _buildToolButton(
                  context,
                  icon: Icons.layers_rounded,
                  label: layerCount > 0 ? 'LAYERS ($layerCount)' : 'LAYERS',
                  isActive: isLayerSelected,
                  onTap: onLayersTap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.12);
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    const selectedColor = AppColors.primary;

    final iconSize = context.adaptiveIconSize(
      22,
      tabletSize: 26,
      largeTabletSize: 28,
    );
    final labelFontSize = context.adaptiveFontSize(
      9.5,
      tabletSize: 11.5,
      largeTabletSize: 12.5,
    );

    return Material(
      color: isActive ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: context.isMediumOrWider ? 8 : 6,
            horizontal: context.isMediumOrWider ? 6 : 2,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: isActive ? selectedColor : unselectedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: isActive ? selectedColor : unselectedColor,
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
