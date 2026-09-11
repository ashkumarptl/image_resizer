import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import 'bouncy_tap.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double height;
  final Gradient gradient;

  const GradientButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 52,
    this.gradient = AppColors.primaryGradient,
  });

  @override
  Widget build(BuildContext context) {
    final pillRadius = BorderRadius.circular(height / 2);
    final isEnabled = onPressed != null && !isLoading;

    Widget buttonContent = Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: onPressed == null ? null : gradient,
        color: onPressed == null ? Colors.grey.shade400 : null,
        borderRadius: pillRadius,
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: pillRadius,
          onTap: isEnabled
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      key: ValueKey('loading'),
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      key: const ValueKey('content'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (isEnabled) {
      return BouncyTap(
        pressedScale: 0.97,
        enableHaptic: false, // InkWell already does lightImpact
        child: buttonContent,
      );
    }

    return buttonContent;
  }
}

