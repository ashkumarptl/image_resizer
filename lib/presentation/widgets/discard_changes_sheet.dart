import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import 'gradient_button.dart';

class DiscardChangesSheet extends StatelessWidget {
  final String title;
  final String message;

  const DiscardChangesSheet({
    super.key,
    this.title = 'Discard Changes?',
    this.message =
        'You have unsaved adjustments on this image. If you exit now, all your progress will be lost.',
  });

  /// Shows the thumb-friendly discard confirmation sheet.
  /// Returns `true` if user confirmed discarding changes, `false` otherwise.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? message,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => DiscardChangesSheet(
        title: title ?? 'Discard Changes?',
        message:
            message ??
            'You have unsaved adjustments on this image. If you exit now, all your progress will be lost.',
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            12,
            24,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Warning Icon Container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.edit_off_rounded,
                  color: AppColors.warning,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                message,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Primary Action: Keep Editing
              GradientButton(
                text: 'Keep Editing',
                icon: Icons.edit_rounded,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 10),

              // Secondary Action: Discard & Exit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Discard & Exit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                    shape: const StadiumBorder(),
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
