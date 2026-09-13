import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radii.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../widgets/bouncy_tap.dart';

class ToolCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String iconEmoji;
  final Color accentColor;
  final String? badgeText;
  final VoidCallback onTap;

  const ToolCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconEmoji,
    this.accentColor = AppColors.primary,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBoxSize = context.adaptiveIconSize(42, tabletSize: 52);
    final emojiSize = context.adaptiveFontSize(22, tabletSize: 28);
    final badgeFontSize = context.adaptiveFontSize(9.5, tabletSize: 12);
    final arrowBoxSize = context.adaptiveIconSize(26, tabletSize: 32);
    final arrowIconSize = context.adaptiveIconSize(13, tabletSize: 17);
    final titleFontSize = context.adaptiveFontSize(15, tabletSize: 18);
    final subtitleFontSize = context.adaptiveFontSize(11, tabletSize: 13.5);

    return RepaintBoundary(
      child: BouncyTap(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.cardRadius,
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: context.isMediumOrWider ? 16 : 14,
                vertical: context.isMediumOrWider ? 14 : 12,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: AppRadii.cardRadius,
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Top Row: Icon Container + Action Arrow / Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: iconBoxSize,
                        height: iconBoxSize,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.20 : 0.10,
                          ),
                          borderRadius: AppRadii.cardInnerRadius,
                          border: Border.all(
                            color: accentColor.withValues(
                              alpha: isDark ? 0.35 : 0.20,
                            ),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          iconEmoji,
                          style: TextStyle(fontSize: emojiSize),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.isMediumOrWider ? 9 : 7,
                            vertical: context.isMediumOrWider ? 4 : 3,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(
                              alpha: isDark ? 0.20 : 0.10,
                            ),
                            borderRadius: AppRadii.badgeRadius,
                            border: Border.all(
                              color: accentColor.withValues(
                                alpha: isDark ? 0.35 : 0.22,
                              ),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              fontSize: badgeFontSize,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                      else
                        Container(
                          width: arrowBoxSize,
                          height: arrowBoxSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.surfaceVariantDark
                                : AppColors.surfaceVariantLight,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.borderLight,
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            size: arrowIconSize,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // 2. Bottom Section: Title & Subtitle
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: subtitleFontSize,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
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
