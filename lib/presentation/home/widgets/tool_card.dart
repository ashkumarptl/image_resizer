import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radii.dart';
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

    return RepaintBoundary(
      child: BouncyTap(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.cardRadius,
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
                          borderRadius: AppRadii.cardInnerRadius,
                          border: Border.all(
                            color: accentColor.withValues(alpha: isDark ? 0.35 : 0.20),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          iconEmoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                      if (badgeText != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: isDark ? 0.20 : 0.10),
                            borderRadius: AppRadii.badgeRadius,
                            border: Border.all(
                              color: accentColor.withValues(alpha: isDark ? 0.35 : 0.22),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badgeText!,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: accentColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        )
                    else
                      Container(
                        width: 26,
                        height: 26,
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
                          size: 13,
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
                    fontSize: 15,
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
                    fontSize: 11,
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
