import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radii.dart';

/// Standard drag handle indicator for all modal bottom sheets across the app.
class BottomSheetDragHandle extends StatelessWidget {
  final double width;
  final double height;
  final EdgeInsetsGeometry margin;

  const BottomSheetDragHandle({
    super.key,
    this.width = 38,
    this.height = 4,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        width: width,
        height: height,
        margin: margin,
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}

/// Unified header row for modal bottom sheets with optional icon, title, subtitle, and close button.
class AppBottomSheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onClose;
  final Widget? trailing;

  const AppBottomSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.onClose,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = iconColor ?? (isDark ? AppColors.primaryLight : AppColors.primary);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          trailing!
        else if (onClose != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            tooltip: 'Close',
            onPressed: onClose,
          ),
      ],
    );
  }
}

/// Unified modal container with standard corner radii, theme-adapted colors, and insets.
class AppBottomSheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool showDragHandle;
  final double maxWidth;

  const AppBottomSheetContainer({
    super.key,
    required this.child,
    this.padding,
    this.showDragHandle = true,
    this.maxWidth = 560,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final navBarInset = MediaQuery.viewPaddingOf(context).bottom;
    final bottomInset = keyboardInset > 0 ? keyboardInset : navBarInset;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: padding ?? EdgeInsets.fromLTRB(18, 12, 18, 18 + bottomInset),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: AppRadii.sheetRadius,
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDragHandle) const BottomSheetDragHandle(),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
