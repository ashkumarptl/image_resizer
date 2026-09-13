import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/batch_item_model.dart';

/// Full-screen interactive image preview with pinch-to-zoom and pan
class BatchImagePreviewDialog extends StatelessWidget {
  final BatchItemModel item;
  final VoidCallback? onRemove;
  final VoidCallback? onCrop;
  final VoidCallback? onCustomize;

  const BatchImagePreviewDialog({
    super.key,
    required this.item,
    this.onRemove,
    this.onCrop,
    this.onCustomize,
  });

  static Future<void> show(
    BuildContext context, {
    required BatchItemModel item,
    VoidCallback? onRemove,
    VoidCallback? onCrop,
    VoidCallback? onCustomize,
  }) {
    return showDialog(
      context: context,
      useSafeArea: false,
      builder: (ctx) => BatchImagePreviewDialog(
        item: item,
        onRemove: onRemove,
        onCrop: onCrop,
        onCustomize: onCustomize,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Interactive Zoomable Image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 5.0,
                child: Image.file(
                  item.file,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white54,
                        size: 64,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Preview unavailable',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Bar Overlay
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                item.readableSize,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              if (item.dimensions != null) ...[
                                const Text(
                                  ' • ',
                                  style: TextStyle(color: Colors.white38),
                                ),
                                Text(
                                  item.resolutionString,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (onRemove != null)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                        tooltip: 'Remove from batch',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onRemove?.call();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Floating Controls
            if (onCrop != null || onCustomize != null)
              Positioned(
                bottom: 16,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (onCrop != null) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white24,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                        label: const Text('Edit in Studio'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onCrop?.call();
                        },
                      ),
                      if (onCustomize != null) const SizedBox(width: 10),
                    ],
                    if (onCustomize != null)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          item.hasCustomOptions
                              ? 'Custom Settings'
                              : 'Customize',
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onCustomize?.call();
                        },
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
