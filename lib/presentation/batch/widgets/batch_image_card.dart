import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/batch_item_model.dart';

/// Card widget representing an individual image in the batch selection
class BatchImageCard extends StatelessWidget {
  final BatchItemModel item;
  final VoidCallback onRemove;
  final VoidCallback onTapPreview;
  final VoidCallback? onTapCrop;
  final VoidCallback onCustomize;

  const BatchImageCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onTapPreview,
    this.onTapCrop,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.hasCustomOptions
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: item.hasCustomOptions ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Thumbnail Stack
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onTap: onTapPreview,
                    child: Image.file(
                      item.file,
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDark ? Colors.white10 : Colors.black12,
                        child: const Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: Colors.grey,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Gradient scrim at bottom of thumbnail for badge readability
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 40,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black87],
                        ),
                      ),
                    ),
                  ),

                  // File size tag
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Text(
                      item.readableSize,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                      ),
                    ),
                  ),

                  // Custom badge indicator
                  if (item.hasCustomOptions)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CUSTOM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                  // Delete / Remove Button
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onRemove();
                      },
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: Color(0x99000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Bottom Actions & Details
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.resolutionString,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Preview Button
                      Expanded(
                        child: InkWell(
                          onTap: onTapPreview,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Center(
                              child: Icon(Icons.fullscreen_rounded, size: 16),
                            ),
                          ),
                        ),
                      ),
                      if (onTapCrop != null) ...[
                        const SizedBox(width: 4),
                        // Studio Edit Button
                        Expanded(
                          child: Tooltip(
                            message: 'Edit in Studio',
                            child: InkWell(
                              onTap: onTapCrop,
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Center(
                                  child: Icon(Icons.crop_rounded, size: 16),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 4),
                      // Customize Button
                      Expanded(
                        child: InkWell(
                          onTap: onCustomize,
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: item.hasCustomOptions
                                  ? AppColors.primaryContainerDark.withValues(
                                      alpha: 0.4,
                                    )
                                  : (isDark
                                        ? Colors.white10
                                        : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.tune_rounded,
                                size: 16,
                                color: item.hasCustomOptions
                                    ? AppColors.primaryLight
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
