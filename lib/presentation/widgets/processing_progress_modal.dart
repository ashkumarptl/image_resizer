import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Holds real-time progress information for image processing operations
class ProcessingProgressState {
  final double progress; // 0.0 to 1.0
  final String stage;
  final bool isCompleted;

  const ProcessingProgressState({
    required this.progress,
    required this.stage,
    this.isCompleted = false,
  });
}

/// A premium, responsive modal dialog displaying a determinate smooth
/// linear progress indicator with real-time stage updates and memory-safety assurance.
class ProcessingProgressModal extends StatelessWidget {
  final ValueNotifier<ProcessingProgressState> progressNotifier;
  final String title;

  const ProcessingProgressModal({
    super.key,
    required this.progressNotifier,
    this.title = 'Processing Image',
  });

  /// Helper to display the modal dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required ValueNotifier<ProcessingProgressState> progressNotifier,
    String title = 'Processing Image',
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ProcessingProgressModal(
        progressNotifier: progressNotifier,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1,
          ),
        ),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: ValueListenableBuilder<ProcessingProgressState>(
            valueListenable: progressNotifier,
            builder: (context, state, _) {
              final clampedProgress = state.progress.clamp(0.0, 1.0);
              final percentInt = (clampedProgress * 100).round();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header with Gradient Ring
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: state.isCompleted
                        ? const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                        : const Icon(Icons.bolt_rounded, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Large Percent Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$percentInt',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        '%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Smooth Animated Linear Progress Indicator
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: clampedProgress),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: isDark
                                ? AppColors.surfaceVariantDark
                                : AppColors.surfaceVariantLight,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // Active Stage Message
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Row(
                      key: ValueKey<String>(state.stage),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!state.isCompleted) ...[
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            state.stage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Reassurance Badge for Low-End / Budget Phones
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceVariantDark.withValues(alpha: 0.7)
                          : AppColors.surfaceVariantLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark.withValues(alpha: 0.5)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.memory_rounded,
                          size: 14,
                          color: AppColors.secondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Background Isolate • UI stays responsive',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
