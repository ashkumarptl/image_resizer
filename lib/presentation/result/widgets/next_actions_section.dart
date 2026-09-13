import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radii.dart';
import '../../perspective_crop/perspective_crop_screen.dart';
import '../../photo_stamp/photo_stamp_screen.dart';
import '../../scan_to_pdf/scan_to_pdf_screen.dart';
import '../../signature/signature_cleaner_screen.dart';
import '../../widgets/bouncy_tap.dart';
import '../../widgets/image_source_picker_sheet.dart';

class NextActionsSection extends ConsumerWidget {
  const NextActionsSection({super.key});

  Future<File?> _pickImage(
    BuildContext context, {
    String title = 'Select Photo',
  }) async {
    return ImageSourcePickerSheet.show(context, title: title);
  }

  void _navigateTo(BuildContext context, Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(
            children: [
              const Icon(
                Icons.bolt_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'NEXT ACTIONS FOR YOUR FORM',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),

        // Action Cards
        _NextActionCard(
          iconEmoji: '✍️',
          icon: Icons.draw_rounded,
          iconColor: const Color(0xFF6366F1),
          title: 'Need Signature for same form?',
          subtitle: 'Clean ink signature, remove shadow & set under 20 KB',
          badge: 'Most Common',
          isDark: isDark,
          onTap: () async {
            final file = await _pickImage(
              context,
              title: 'Select Signature Photo',
            );
            if (file != null && context.mounted) {
              _navigateTo(context, SignatureCleanerScreen(initialImage: file));
            }
          },
        ),
        const SizedBox(height: 8),

        _NextActionCard(
          iconEmoji: '📄',
          icon: Icons.picture_as_pdf_rounded,
          iconColor: const Color(0xFFDC2626),
          title: 'Scan another document to PDF',
          subtitle: 'Multi-page scanner with < 2MB preset & deskew',
          badge: 'New',
          isDark: isDark,
          onTap: () => _navigateTo(context, const ScanToPdfScreen()),
        ),
        const SizedBox(height: 8),

        _NextActionCard(
          iconEmoji: '📅',
          icon: Icons.badge_rounded,
          iconColor: const Color(0xFF0D9488),
          title: 'Name & Date Photo Stamp',
          subtitle: 'Add mandatory Candidate Name & DOP stamp for SSC / NEET',
          badge: 'Exam Mandatory',
          isDark: isDark,
          onTap: () async {
            final file = await _pickImage(
              context,
              title: 'Select Passport Photo to Stamp',
            );
            if (file != null && context.mounted) {
              _navigateTo(context, PhotoStampScreen(initialImage: file));
            }
          },
        ),
        const SizedBox(height: 8),

        _NextActionCard(
          iconEmoji: '📐',
          icon: Icons.crop_rotate_rounded,
          iconColor: const Color(0xFF8B5CF6),
          title: 'Straighten / Deskew Document',
          subtitle:
              'Fix tilted certificate or ID card with 4-corner perspective crop',
          isDark: isDark,
          onTap: () async {
            final file = await _pickImage(
              context,
              title: 'Select Document to Deskew',
            );
            if (file != null && context.mounted) {
              _navigateTo(context, PerspectiveCropScreen(initialImage: file));
            }
          },
        ),
      ],
    );
  }
}

class _NextActionCard extends StatelessWidget {
  final String iconEmoji;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final bool isDark;
  final VoidCallback onTap;

  const _NextActionCard({
    required this.iconEmoji,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      pressedScale: 0.96,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardInnerRadius,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppRadii.cardInnerRadius,
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(iconEmoji, style: const TextStyle(fontSize: 18)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          if (badge != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(
                                  alpha: isDark ? 0.25 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badge!,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: iconColor,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
