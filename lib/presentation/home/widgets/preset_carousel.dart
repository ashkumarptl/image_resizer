import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/layout/adaptive_layout.dart';
import '../../../data/models/image_preset.dart';
import '../../widgets/bouncy_tap.dart';

class PresetCarousel extends StatelessWidget {
  final List<ImagePreset> presets;
  final Set<String> favoritePresetIds;
  final Function(ImagePreset preset) onPresetTap;
  final VoidCallback onSeeAllTap;

  const PresetCarousel({
    super.key,
    required this.presets,
    this.favoritePresetIds = const {},
    required this.onPresetTap,
    required this.onSeeAllTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;
    final horizontalMargin = context.adaptiveMargin;

    // Prioritize pinned/favorite presets at the very front of the carousel
    final sortedPresets = List<ImagePreset>.from(presets);
    if (favoritePresetIds.isNotEmpty) {
      sortedPresets.sort((a, b) {
        final aFav = favoritePresetIds.contains(a.id);
        final bFav = favoritePresetIds.contains(b.id);
        if (aFav && !bFav) return -1;
        if (!aFav && bFav) return 1;
        return 0;
      });
    }

    final hasPinned = favoritePresetIds.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      hasPinned ? '⭐ ' : '🇮🇳 ',
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(18, tabletSize: 22),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        hasPinned ? 'Pinned & Popular' : 'Govt & Exam Presets',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: context.adaptiveFontSize(16, tabletSize: 20),
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    if (hasPinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 8 : 6,
                          vertical: isWide ? 3 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${favoritePresetIds.length} PINNED',
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(9, tabletSize: 11.5),
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFD97706),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              TextButton(
                onPressed: onSeeAllTap,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: context.adaptiveFontSize(13, tabletSize: 15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isWide ? 126 : 108,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: horizontalMargin),
            scrollDirection: Axis.horizontal,
            itemCount: sortedPresets.length > 8 ? 8 : sortedPresets.length,
            separatorBuilder: (_, _) => SizedBox(width: isWide ? 16 : 12),
            itemBuilder: (context, index) {
              final preset = sortedPresets[index];
              final isPinned = favoritePresetIds.contains(preset.id);
              return _PresetCardItem(
                preset: preset,
                isPinned: isPinned,
                onTap: () => onPresetTap(preset),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PresetCardItem extends StatelessWidget {
  final ImagePreset preset;
  final bool isPinned;
  final VoidCallback onTap;

  const _PresetCardItem({
    required this.preset,
    this.isPinned = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;

    return BouncyTap(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: isWide ? 190 : 158,
            padding: EdgeInsets.all(isWide ? 14 : 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isPinned
                    ? const Color(0xFFF59E0B)
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: isPinned ? 1.5 : 1,
              ),
              boxShadow: [
                if (isPinned)
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.iconEmoji,
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(18, tabletSize: 22),
                          ),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.star_rounded,
                            size: context.adaptiveIconSize(16, tabletSize: 20),
                            color: const Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isWide ? 8 : 6,
                          vertical: isWide ? 3 : 2,
                        ),
                        decoration: BoxDecoration(
                          color: isPinned
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                              : AppColors.primaryContainerLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          preset.badgeText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(10, tabletSize: 12),
                            fontWeight: FontWeight.bold,
                            color: isPinned ? const Color(0xFFD97706) : AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(13, tabletSize: 15.5),
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preset.outputFormat.toUpperCase(),
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(10, tabletSize: 12),
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
