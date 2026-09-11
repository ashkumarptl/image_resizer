import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(hasPinned ? '⭐ ' : '🇮🇳 ', style: const TextStyle(fontSize: 18)),
                    Flexible(
                      child: Text(
                        hasPinned ? 'Pinned & Popular' : 'Govt & Exam Presets',
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
                    if (hasPinned) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${favoritePresetIds.length} PINNED',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD97706),
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
                child: const Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 13,
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
          height: 108,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: sortedPresets.length > 8 ? 8 : sortedPresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
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

    return BouncyTap(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 158,
            padding: const EdgeInsets.all(12),
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
                        Text(preset.iconEmoji, style: const TextStyle(fontSize: 18)),
                        if (isPinned) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                            fontSize: 10,
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
                        fontSize: 13,
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
                        fontSize: 10,
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
