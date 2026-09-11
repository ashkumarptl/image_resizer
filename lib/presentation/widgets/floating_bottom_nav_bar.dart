import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import 'bouncy_tap.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class FloatingBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const FloatingBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    // Hide floating navigation bar when keyboard is open
    if (bottomInset > 0) {
      return const SizedBox.shrink();
    }

    final paddingBottom = MediaQuery.paddingOf(context).bottom;
    final viewPaddingBottom = MediaQuery.viewPaddingOf(context).bottom;
    final safeBottom = math.max(paddingBottom, viewPaddingBottom);

    // Differentiate Android navigation modes:
    // 1. Android 3-Button Navigation (typically ~48dp inset) -> Needs 12-14dp clearance
    //    so user's thumb does not accidentally hit Android Back/Home/Recents buttons.
    // 2. Gesture Navigation (typically ~16-24dp inset) -> Needs 8-10dp clearance above gesture pill.
    // 3. Zero Inset (legacy/immersive) -> 16dp baseline margin.
    final double bottomMargin;
    if (safeBottom >= 36) {
      bottomMargin = safeBottom + 12.0;
    } else if (safeBottom > 0) {
      bottomMargin = safeBottom + 8.0;
    } else {
      bottomMargin = 16.0;
    }

    final mediaQuery = MediaQuery.of(context);
    final clampedMediaQuery = mediaQuery.copyWith(
      textScaler: mediaQuery.textScaler.clamp(
        minScaleFactor: 0.80,
        maxScaleFactor: 1.10,
      ),
    );

    return MediaQuery(
      data: clampedMediaQuery,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: bottomMargin,
          left: 20,
          right: 20,
        ),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(33),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(33),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark.withValues(alpha: 0.88)
                          : Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(33),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark.withValues(alpha: 0.8)
                            : AppColors.borderLight.withValues(alpha: 0.9),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(items.length, (index) {
                        final item = items[index];
                        final isSelected = index == currentIndex;

                        return Expanded(
                          child: _NavBarItemWidget(
                            item: item,
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () {
                              if (!isSelected) {
                                HapticFeedback.lightImpact();
                                onTap(index);
                              }
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.35, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _NavBarItemWidget extends StatelessWidget {
  final FloatingNavItem item;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _NavBarItemWidget({
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return BouncyTap(
      pressedScale: 0.90,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: activeColor.withValues(alpha: 0.1),
          highlightColor: activeColor.withValues(alpha: 0.05),
          child: RepaintBoundary(
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: isSelected
                  ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isSelected
                    ? activeColor.withValues(alpha: isDark ? 0.35 : 0.22)
                    : Colors.transparent,
                width: 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: isDark ? 0.30 : 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    transitionBuilder: (child, anim) =>
                        ScaleTransition(scale: anim, child: child),
                    child: Icon(
                      isSelected ? item.activeIcon : item.icon,
                      key: ValueKey('${item.label}_$isSelected'),
                      size: 22,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 200),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? activeColor : inactiveColor,
                        letterSpacing: isSelected ? 0.2 : 0.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: Text(item.label),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: isSelected ? 14 : 0,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
