import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radii.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_result.dart';

class CelebratorySavingsBanner extends StatefulWidget {
  final ProcessResult result;

  const CelebratorySavingsBanner({super.key, required this.result});

  @override
  State<CelebratorySavingsBanner> createState() =>
      _CelebratorySavingsBannerState();
}

class _CelebratorySavingsBannerState extends State<CelebratorySavingsBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    final ratio = widget.result.originalSizeBytes > 0
        ? (widget.result.outputSizeBytes / widget.result.originalSizeBytes)
              .clamp(0.02, 1.0)
        : 1.0;

    _progressAnimation = Tween<double>(begin: 0.0, end: ratio).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = widget.result;
    final isReduced = result.isSizeReduced;

    if (!isReduced) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.surfaceVariantDark.withValues(alpha: 0.4)
              : Colors.blue.shade50.withValues(alpha: 0.7),
          borderRadius: AppRadii.cardInnerRadius,
          border: Border.all(
            color: isDark ? AppColors.borderDark : Colors.blue.shade200,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Dimensions matched exact portal specs: ${result.outputWidth}×${result.outputHeight} px (${result.outputSizeBytes.toReadableFileSize()})',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final savedBytes = result.originalSizeBytes - result.outputSizeBytes;
    final savedPct = result.savedPercentage.round();
    final originalFormatted = result.originalSizeBytes.toReadableFileSize();
    final outputFormatted = result.outputSizeBytes.toReadableFileSize();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF064E3B).withValues(alpha: 0.55),
                  const Color(0xFF0F766E).withValues(alpha: 0.35),
                ]
              : [const Color(0xFFECFDF5), const Color(0xFFF0FDFA)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : const Color(0xFF6EE7B7),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: isDark ? 0.12 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: 🎉 Reduced by X% (Original ➔ Output)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF10B981,
                  ).withValues(alpha: isDark ? 0.25 : 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 16)),
              ).animate().scale(
                delay: 100.ms,
                duration: 350.ms,
                curve: Curves.easeOutBack,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Reduced by $savedPct%',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? const Color(0xFF34D399)
                                  : const Color(0xFF065F46),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF10B981,
                                ).withValues(alpha: isDark ? 0.25 : 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '-${savedBytes.toReadableFileSize()}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? const Color(0xFF6EE7B7)
                                      : const Color(0xFF047857),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 200.ms)
                            .shimmer(delay: 600.ms, duration: 1200.ms),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$originalFormatted ➔ $outputFormatted',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Animated Progress Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RepaintBoundary(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    width: double.infinity,
                    color: isDark ? Colors.black38 : const Color(0xFFE2E8F0),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, child) {
                        return FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _progressAnimation.value.clamp(
                            0.02,
                            1.0,
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Optimized: $outputFormatted (${(100 - savedPct).clamp(1, 100)}%)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Original: $originalFormatted (100%)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
