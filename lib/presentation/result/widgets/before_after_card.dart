import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/process_result.dart';
import '../../widgets/size_badge.dart';

class BeforeAfterCard extends StatefulWidget {
  final ProcessResult result;

  const BeforeAfterCard({
    super.key,
    required this.result,
  });

  @override
  State<BeforeAfterCard> createState() => _BeforeAfterCardState();
}

class _BeforeAfterCardState extends State<BeforeAfterCard> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = widget.result;

    final currentPath = _showOriginal ? result.originalPath : result.outputPath;
    final currentFile = File(currentPath);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Image Preview with Toggle
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Container(
                  height: 260,
                  width: double.infinity,
                  color: isDark ? Colors.black26 : Colors.grey.shade100,
                  child: currentFile.existsSync()
                      ? Image.file(
                          currentFile,
                          fit: BoxFit.contain,
                        )
                      : const Center(child: Icon(Icons.broken_image, size: 48)),
                ),
              ),
              // Toggle Button Overlay
              Positioned(
                bottom: 12,
                right: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      setState(() {
                        _showOriginal = !_showOriginal;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showOriginal ? Icons.visibility : Icons.compare,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showOriginal ? 'Viewing Original' : 'Tap for Original',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
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
          // Comparison Details Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizeBadge(
                    sizeBytes: result.originalSizeBytes,
                    label: 'Original Size',
                    isOriginal: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                Expanded(
                  child: SizeBadge(
                    sizeBytes: result.outputSizeBytes,
                    label: result.isSizeReduced ? 'Optimized' : 'Output Size',
                    isOriginal: false,
                    isIncreased: !result.isSizeReduced && result.outputSizeBytes > result.originalSizeBytes,
                  ),
                ),
              ],
            ),
          ),
          // Savings or Size Notice Banner
          if (result.isSizeReduced)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.secondaryContainerDark : AppColors.successContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved ${result.savedPercentage.toStringAsFixed(1)}% of original size (${(result.originalSizeBytes - result.outputSizeBytes).toReadableFileSize()})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.secondaryLight : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (result.outputSizeBytes > result.originalSizeBytes)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Size increased by ${(result.outputSizeBytes - result.originalSizeBytes).toReadableFileSize()}. ${result.outputFormat.toLowerCase() == 'png' ? 'PNG is lossless and retains uncompressed pixel clarity. Use JPG or WebP for smaller file size.' : 'Original image was already heavily compressed.'}',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
