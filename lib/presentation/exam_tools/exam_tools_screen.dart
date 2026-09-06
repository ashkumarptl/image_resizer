import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/repositories/auth_repository.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../signature/signature_cleaner_screen.dart';
import '../widgets/account_section.dart';
import '../widgets/login_gate_dialog.dart';

class ExamToolsScreen extends ConsumerStatefulWidget {
  final VoidCallback? onNavigateToPresets;

  const ExamToolsScreen({
    super.key,
    this.onNavigateToPresets,
  });

  @override
  ConsumerState<ExamToolsScreen> createState() => _ExamToolsScreenState();
}

class _ExamToolsScreenState extends ConsumerState<ExamToolsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<File?> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (picked != null) {
        return File(picked.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open image picker: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
    return null;
  }

  Future<void> _handleSignatureTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureCleanerScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handlePhotoStampTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoStampScreen(initialImage: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exam Document Tools',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 2),
            Text(
              'Specialized utilities for Govt & Exam portals',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final authState = ref.watch(authStateProvider);
              return authState.when(
                data: (user) {
                  if (user != null) {
                    final photoUrl = user.photoURL;
                    final displayName = user.displayName ?? 'User';
                    return IconButton(
                      tooltip: 'Account (${user.displayName ?? 'Signed in'})',
                      onPressed: () => showAccountBottomSheet(context),
                      icon: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primaryContainerLight,
                        backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                        child: photoUrl == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              )
                            : null,
                      ),
                    );
                  } else {
                    return IconButton(
                      icon: const Icon(Icons.account_circle_outlined),
                      tooltip: 'Sign In / Account',
                      onPressed: () => showAccountBottomSheet(context),
                    );
                  }
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (err, stack) => IconButton(
                  icon: const Icon(Icons.account_circle_outlined),
                  tooltip: 'Sign In / Account',
                  onPressed: () => showAccountBottomSheet(context),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: AdaptivePageContainer(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [
                                Colors.teal.withValues(alpha: 0.25),
                                AppColors.primary.withValues(alpha: 0.15),
                              ]
                            : [
                                Colors.teal.withValues(alpha: 0.12),
                                AppColors.primary.withValues(alpha: 0.08),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.teal.withValues(alpha: isDark ? 0.35 : 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: isDark ? 0.3 : 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🎓', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Exam Ready in Seconds',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.tealAccent : Colors.teal.shade800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tailored processing for SSC, UPSC, IBPS, Vyapam, and State PSC submissions.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Tool 1: Signature B&W Cleaner
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                  child: _buildToolCard(
                    context: context,
                    isDark: isDark,
                    title: 'Signature B&W Cleaner',
                    subtitle: 'Shadow Removal & High Contrast',
                    emoji: '✍️',
                    accentColor: Colors.teal,
                    badges: ['SPECIAL', '< 20 KB', '400×200 px'],
                    description:
                        'Converts paper signatures shot on mobile cameras into crisp monochrome digital signatures. Removes paper grain, yellow tint, and shadows.',
                    buttonText: 'Open Signature Cleaner',
                    onTap: _handleSignatureTool,
                  ),
                ),
                const SizedBox(height: 16),

                // Tool 2: Photo Stamp Utility
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                  child: _buildToolCard(
                    context: context,
                    isDark: isDark,
                    title: 'Name & Date Photo Stamp',
                    subtitle: 'Mandatory for SSC & UPSC Notices',
                    emoji: '🏷️',
                    accentColor: Colors.deepOrange,
                    badges: ['REQUIRED', '< 50 KB', 'Custom DOP'],
                    description:
                        'Superimpose candidate name and Date of Photo (DOP) on passport photos with a clean white footer bar. Auto-compressed under 50 KB.',
                    buttonText: 'Open Photo Stamp',
                    onTap: _handlePhotoStampTool,
                  ),
                ),
                const SizedBox(height: 24),

                // Guidance & Rules Card
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 20,
                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Standard Exam Guidelines',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildGuidelineRow(
                          isDark,
                          '🖼️',
                          'Passport Photo',
                          'Light/white background, 3.5cm × 4.5cm, 20 KB – 50 KB.',
                        ),
                        const SizedBox(height: 8),
                        _buildGuidelineRow(
                          isDark,
                          '✒️',
                          'Signature',
                          'Black/blue ink on white paper, 4.0cm × 2.0cm, strictly 10 KB – 20 KB.',
                        ),
                        const SizedBox(height: 8),
                        _buildGuidelineRow(
                          isDark,
                          '📅',
                          'Photo Date (DOP)',
                          'Must not be older than 3 months from the exam notification date.',
                        ),
                        if (widget.onNavigateToPresets != null) ...[
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: widget.onNavigateToPresets,
                              icon: const Icon(Icons.tune_rounded, size: 18),
                              label: const Text('Browse All Govt & Exam Presets'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Spacing for floating bottom bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required String emoji,
    required Color accentColor,
    required List<String> badges,
    required String description,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.25 : 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: badges.map((badge) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                    letterSpacing: 0.4,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelineRow(bool isDark, String iconEmoji, String title, String detail) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(iconEmoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                TextSpan(text: detail),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
