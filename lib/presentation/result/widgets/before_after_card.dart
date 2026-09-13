import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_result.dart';
import 'fullscreen_image_preview.dart';

class BeforeAfterCard extends StatefulWidget {
  final ProcessResult result;

  const BeforeAfterCard({super.key, required this.result});

  @override
  State<BeforeAfterCard> createState() => _BeforeAfterCardState();
}

class _BeforeAfterCardState extends State<BeforeAfterCard> {
  bool _showOriginal = false;

  void _openImagePreview(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withValues(alpha: 0.95),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: FullscreenImagePreview(
              result: widget.result,
              initialShowOriginal: _showOriginal,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = widget.result;

    final currentPath = _showOriginal ? result.originalPath : result.outputPath;
    final currentFile = File(currentPath);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Compact Image Preview with Tap to Zoom & Toggle Pill
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
                child: Material(
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  child: InkWell(
                    onTap: () => _openImagePreview(context),
                    child: SizedBox(
                      height: 165,
                      width: double.infinity,
                      child: currentFile.existsSync()
                          ? Hero(
                              tag: 'result_image_preview',
                              child: Image.file(
                                currentFile,
                                fit: BoxFit.contain,
                                cacheWidth: 800,
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.broken_image, size: 40),
                            ),
                    ),
                  ),
                ),
              ),
              // Top-right: Tap to Preview Pill Badge
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openImagePreview(context),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Tap to preview',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Toggle Button Overlay
              Positioned(
                bottom: 8,
                right: 8,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      setState(() {
                        _showOriginal = !_showOriginal;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showOriginal ? Icons.visibility : Icons.compare,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _showOriginal
                                ? 'Viewing Original'
                                : 'Tap for Original',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 2. Streamlined Comparison & Savings Section
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Original Size Tile
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceVariantDark
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ORIGINAL SIZE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              result.originalSizeBytes.toReadableFileSize(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    // Output Size Tile
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: result.isSizeReduced
                              ? (isDark
                                    ? const Color(
                                        0xFF14532D,
                                      ).withValues(alpha: 0.35)
                                    : AppColors.successContainer)
                              : (isDark
                                    ? AppColors.surfaceVariantDark
                                    : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(10),
                          border: result.isSizeReduced
                              ? Border.all(
                                  color: AppColors.success.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 0.8,
                                )
                              : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result.isSizeReduced
                                  ? 'OPTIMIZED'
                                  : 'OUTPUT SIZE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: result.isSizeReduced
                                    ? (isDark
                                          ? const Color(0xFF4ADE80)
                                          : AppColors.success)
                                    : (isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              result.outputSizeBytes.toReadableFileSize(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: result.isSizeReduced
                                    ? (isDark
                                          ? const Color(0xFF4ADE80)
                                          : AppColors.success)
                                    : (isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Inline Savings Pill or Size Increase Notice
                if (result.isSizeReduced) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF14532D).withValues(alpha: 0.25)
                          : AppColors.successContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            'Saved ${result.savedPercentage.toStringAsFixed(1)}% of original size (${(result.originalSizeBytes - result.outputSizeBytes).toReadableFileSize()})',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF4ADE80)
                                  : AppColors.success,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (result.outputSizeBytes >
                    result.originalSizeBytes) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Size increased by ${(result.outputSizeBytes - result.originalSizeBytes).toReadableFileSize()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : Colors.amber.shade900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
