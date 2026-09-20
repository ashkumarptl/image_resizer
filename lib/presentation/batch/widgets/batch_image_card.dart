import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../models/batch_item_model.dart';

/// Card widget representing an individual image in the batch selection
/// with selection toggle, thumbnail, metadata, and quick actions.
class BatchImageCard extends StatelessWidget {
  final BatchItemModel item;
  final VoidCallback onRemove;
  final VoidCallback onTapPreview;
  final VoidCallback? onTapCrop;
  final VoidCallback? onCustomize;
  final bool isSelected;
  final bool isFocused;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onTapFocus;
  final Widget? dragHandle;

  const BatchImageCard({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onTapPreview,
    this.onTapCrop,
    this.onCustomize,
    this.isSelected = false,
    this.isFocused = false,
    this.onToggleSelect,
    this.onTapFocus,
    this.dragHandle,
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
          color: isFocused
              ? AppColors.primary
              : (isSelected
                    ? AppColors.primary
                    : (item.hasCustomOptions
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight))),
          width: isFocused
              ? 2.5
              : (isSelected ? 2.0 : (item.hasCustomOptions ? 1.5 : 1.0)),
        ),
        boxShadow: [
          BoxShadow(
            color: isFocused
                ? AppColors.primary.withValues(alpha: 0.35)
                : (isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05)),
            blurRadius: isFocused ? 12 : (isSelected ? 10 : 8),
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
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (onTapFocus != null) {
                        onTapFocus!();
                      } else if (onToggleSelect != null) {
                        onToggleSelect!();
                      } else {
                        onTapPreview();
                      }
                    },
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
                    child: IgnorePointer(
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
                  ),

                  // File size tag
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: IgnorePointer(
                      child: Text(
                        item.readableSize,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Focused or Custom badge indicator
                  if (isFocused)
                    Positioned(
                      top: 6,
                      left: onToggleSelect != null ? 34 : 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 10,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'EDITING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (item.hasCustomOptions)
                    Positioned(
                      top: 6,
                      left: onToggleSelect != null ? 34 : 6,
                      child: IgnorePointer(
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
                    ),

                  // Multi-select Checkbox Badge (Top Left)
                  if (onToggleSelect != null)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: GestureDetector(
                        key: ValueKey('batch_card_select_${item.path}'),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onToggleSelect!();
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0x99000000),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: Icon(
                            isSelected ? Icons.check_rounded : null,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),

                  // Reorder drag handle (if provided)
                  if (dragHandle != null)
                    Positioned(bottom: 4, right: 4, child: dragHandle!),

                  // Delete / Remove Button (Top Right)
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

            // Card Mid Section: File Name & Resolution (100% Clickable)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onTapFocus?.call();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
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
                  ],
                ),
              ),
            ),

            // Card Bottom Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                children: [
                  // Preview Button
                  Expanded(
                    child: Tooltip(
                      message: 'Fullscreen Preview',
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
                  ),
                  const SizedBox(width: 6),
                  // Studio / Crop Editing Button
                  Expanded(
                    child: Tooltip(
                      message: 'Crop & Studio Editing',
                      child: InkWell(
                        onTap: onTapCrop,
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
                            child: Icon(Icons.crop_rounded, size: 16),
                          ),
                        ),
                      ),
                    ),
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
