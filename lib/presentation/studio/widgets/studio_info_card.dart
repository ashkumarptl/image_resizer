import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/extensions/file_size_extension.dart';

class StudioInfoCard extends StatelessWidget {
  final String filePath;
  final int width;
  final int height;
  final int fileSizeBytes;
  final String? targetSummary;
  final int? estimatedSizeBytes;
  final int? outputWidth;
  final int? outputHeight;
  final String? outputFormat;
  final String? targetGoal;
  final bool isCalculating;
  final bool isDark;
  final bool stripMetadata;
  final int? dpi;
  final int? targetDpi;

  const StudioInfoCard({
    super.key,
    required this.filePath,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
    this.targetSummary,
    this.estimatedSizeBytes,
    this.outputWidth,
    this.outputHeight,
    this.outputFormat,
    this.targetGoal,
    this.isCalculating = false,
    required this.isDark,
    this.stripMetadata = true,
    this.dpi,
    this.targetDpi,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(filePath);
    final originalExt = p.extension(filePath).replaceAll('.', '').toUpperCase();
    final targetExt = (outputFormat ?? originalExt).toUpperCase();
    final isFormatConverted = targetExt.isNotEmpty && originalExt.isNotEmpty && targetExt != originalExt;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Compact File Type / Photo Icon Badge
          _buildCompactBadge(originalExt),
          const SizedBox(width: 10),

          // 2. Structured Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: File Name & Format Conversion Badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildFormatBadge(originalExt, targetExt, isFormatConverted),
                  ],
                ),
                const SizedBox(height: 2),

                // Original Specs (Dimensions & File Size)
                Text(
                  (width > 0 && height > 0)
                      ? '$width × $height px   •   ${fileSizeBytes.toReadableFileSize()}${dpi != null ? '   •   $dpi DPI' : ''}'
                      : '${fileSizeBytes.toReadableFileSize()}${dpi != null ? '   •   $dpi DPI' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),

                // Live Output & Status Row (Shown when calculating or estimate available)
                if (isCalculating || estimatedSizeBytes != null || (targetSummary != null && targetSummary!.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  _buildStatusRow(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBadge(String originalExt) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: const Icon(
        Icons.photo_outlined,
        color: AppColors.primary,
        size: 18,
      ),
    );
  }

  Widget _buildFormatBadge(String originalExt, String targetExt, bool isFormatConverted) {
    if (isFormatConverted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              originalExt,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.arrow_forward_rounded, size: 9, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              targetExt,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        originalExt.isNotEmpty ? originalExt : 'IMG',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    if (isCalculating) {
      return const Row(
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Calculating estimate...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    if (estimatedSizeBytes != null) {
      final estKb = (estimatedSizeBytes! / 1024).toStringAsFixed(1);
      final isReduced = estimatedSizeBytes! < fileSizeBytes;
      final isIncreased = estimatedSizeBytes! > fileSizeBytes;
      final pct = fileSizeBytes > 0
          ? (((fileSizeBytes - estimatedSizeBytes!) / fileSizeBytes) * 100).abs().toStringAsFixed(0)
          : '0';

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Est size
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 13,
                  color: AppColors.primary,
                ),
                Text(
                  'Est: $estKb KB',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),

            // Savings badge (green) or Increased badge (amber)
            if (isReduced && int.parse(pct) > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.5) : AppColors.successContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '-$pct% saved',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFF4ADE80) : AppColors.success,
                  ),
                ),
              ),
            ] else if (isIncreased && int.parse(pct) > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 11,
                      color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '+$pct% larger',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Target Goal Chip
            if (targetGoal != null && targetGoal!.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceVariantDark : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : Colors.grey.shade300,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  targetGoal!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],

            // Resize delta chip if dimensions changed
            if (outputWidth != null && outputHeight != null && (outputWidth != width || outputHeight != height)) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '➔ $outputWidth×$outputHeight',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
            if (targetDpi != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '➔ $targetDpi DPI',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            if (stripMetadata) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14532D).withValues(alpha: 0.4) : AppColors.successContainer,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 10,
                      color: AppColors.success,
                    ),
                    SizedBox(width: 2.5),
                    Text(
                      'No GPS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Fallback: when targetSummary is explicitly provided without estimatedSizeBytes
    if (targetSummary != null && targetSummary!.isNotEmpty) {
      return Row(
        children: [
          const Icon(
            Icons.bolt_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 2),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                targetSummary!,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
