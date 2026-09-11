import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/file_size_extension.dart';
import '../../../data/models/history_item.dart';

import '../../../core/layout/adaptive_layout.dart';

class RecentFilesSection extends StatelessWidget {
  final List<HistoryItem> historyItems;
  final Function(HistoryItem item) onItemTap;
  final VoidCallback onClearHistory;

  const RecentFilesSection({
    super.key,
    required this.historyItems,
    required this.onItemTap,
    required this.onClearHistory,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final horizontalMargin = context.adaptiveMargin;

    if (historyItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = historyItems.length > 6 ? historyItems.sublist(0, 6) : historyItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Recent Files',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClearHistory,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 2-column grid is only used when the container has at least 600px width.
              // On smaller screens or mobile landscape, a single column is used to prevent cramped overflow.
              final useGrid = constraints.maxWidth >= 600;
              if (useGrid) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 74,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) => _buildItemTile(context, displayItems[index], isDark),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayItems.length > 5 ? 5 : displayItems.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _buildItemTile(context, displayItems[index], isDark),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildItemTile(BuildContext context, HistoryItem item, bool isDark) {
    final thumbPath = item.thumbnailPath;
    final thumbFile = (thumbPath != null && thumbPath.isNotEmpty) ? File(thumbPath) : null;
    final fullFile = File(item.filePath);
    final displayFile = (thumbFile != null && thumbFile.existsSync())
        ? thumbFile
        : (fullFile.existsSync() ? fullFile : null);
    final timeAgo = _formatTimeAgo(item.processedAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: displayFile != null
                    ? Image.file(
                        displayFile,
                        width: 44,
                        height: 44,
                        cacheWidth: 120,
                        cacheHeight: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 44,
                          height: 44,
                          color: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariantLight,
                          child: const Icon(Icons.broken_image, size: 20),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: isDark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,
                        child: const Icon(Icons.broken_image, size: 20),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${item.width}x${item.height} · ${item.format.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.originalSizeBytes.toReadableFileSize()} ➔ ${item.outputSizeBytes.toReadableFileSize()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.MMMd().format(dt);
  }
}
