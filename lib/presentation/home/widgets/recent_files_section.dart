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

    final maxItems = context.isLargeTablet ? 10 : (context.isMediumOrWider ? 8 : 6);
    final displayItems = historyItems.length > maxItems ? historyItems.sublist(0, maxItems) : historyItems;

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
                    fontSize: context.adaptiveFontSize(16, tabletSize: 22, largeTabletSize: 26),
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
                    fontSize: context.adaptiveFontSize(13, tabletSize: 16, largeTabletSize: 18),
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
              // 2-column grid is only used on wide displays with at least 720px available width (e.g. landscape tablets / desktop).
              // On portrait screens (including 800x1280 tablets where content width is ~664px), a single column is used.
              final useGrid = constraints.maxWidth >= 720.0;
              final gridExtent = context.isLargeTablet ? 104.0 : (context.isMediumOrWider ? 92.0 : 78.0);
              if (useGrid) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: context.isLargeTablet ? 14 : (context.isMediumOrWider ? 12 : 10),
                    crossAxisSpacing: context.isLargeTablet ? 16 : (context.isMediumOrWider ? 14 : 12),
                    mainAxisExtent: gridExtent,
                  ),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) => _buildItemTile(context, displayItems[index], isDark),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayItems.length,
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
    final thumbSize = context.isLargeTablet ? 64.0 : (context.isMediumOrWider ? 56.0 : 48.0);
    final brokenIconSize = context.adaptiveIconSize(20, tabletSize: 26, largeTabletSize: 28);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onItemTap(item),
        borderRadius: BorderRadius.circular(context.isLargeTablet ? 16 : (context.isMediumOrWider ? 14 : 12)),
        child: Ink(
          padding: EdgeInsets.all(context.isLargeTablet ? 12 : (context.isMediumOrWider ? 12 : 10)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(context.isLargeTablet ? 16 : (context.isMediumOrWider ? 14 : 12)),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(context.isLargeTablet ? 12 : (context.isMediumOrWider ? 10 : 8)),
                child: displayFile != null
                    ? Image.file(
                        displayFile,
                        width: thumbSize,
                        height: thumbSize,
                        cacheWidth: 160,
                        cacheHeight: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: thumbSize,
                          height: thumbSize,
                          color: isDark
                              ? AppColors.surfaceVariantDark
                              : AppColors.surfaceVariantLight,
                          child: Icon(Icons.broken_image, size: brokenIconSize),
                        ),
                      )
                    : Container(
                        width: thumbSize,
                        height: thumbSize,
                        color: isDark
                            ? AppColors.surfaceVariantDark
                            : AppColors.surfaceVariantLight,
                        child: Icon(Icons.broken_image, size: brokenIconSize),
                      ),
              ),
              SizedBox(width: context.isLargeTablet ? 14 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item.width}x${item.height} · ${item.format.toUpperCase()}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(13, tabletSize: 14.5, largeTabletSize: 15.5),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${item.originalSizeBytes.toReadableFileSize()} ➔ ${item.outputSizeBytes.toReadableFileSize()}',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(12, tabletSize: 13.0, largeTabletSize: 14.0),
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                timeAgo,
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(11, tabletSize: 12.0, largeTabletSize: 12.5),
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
