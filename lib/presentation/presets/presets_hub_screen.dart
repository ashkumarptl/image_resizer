import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/preset_constants.dart';
import '../../data/models/image_preset.dart';
import '../../data/repositories/auth_repository.dart';
import '../widgets/account_section.dart';
import '../widgets/login_gate_dialog.dart';
import 'preset_apply_screen.dart';

class PresetsHubScreen extends ConsumerStatefulWidget {
  final bool isTab;

  const PresetsHubScreen({
    super.key,
    this.isTab = false,
  });

  @override
  ConsumerState<PresetsHubScreen> createState() => _PresetsHubScreenState();
}

class _PresetsHubScreenState extends ConsumerState<PresetsHubScreen> {
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'SSC Exams',
    'UPSC & PSC',
    'Banking (IBPS)',
    'ID & Docs',
  ];

  List<ImagePreset> get _filteredPresets {
    if (_selectedCategory == 'All') {
      return PresetConstants.indianGovtPresets;
    }
    if (_selectedCategory == 'SSC Exams') {
      return PresetConstants.indianGovtPresets
          .where((p) => p.id.startsWith('ssc_'))
          .toList();
    }
    if (_selectedCategory == 'UPSC & PSC') {
      return PresetConstants.indianGovtPresets
          .where((p) => p.id.startsWith('upsc_') || p.id.startsWith('cg_vyapam_'))
          .toList();
    }
    if (_selectedCategory == 'Banking (IBPS)') {
      return PresetConstants.indianGovtPresets
          .where((p) => p.id.startsWith('ibps_'))
          .toList();
    }
    if (_selectedCategory == 'ID & Docs') {
      return PresetConstants.indianGovtPresets
          .where((p) => p.category == PresetCategory.identity)
          .toList();
    }
    return PresetConstants.indianGovtPresets;
  }

  Future<void> _handleSelectPreset(BuildContext context, WidgetRef ref, ImagePreset preset) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !context.mounted) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    File currentImage = File(picked.path);
    final hasDimensions = preset.targetWidth != null && preset.targetHeight != null;

    if (hasDimensions) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: CropAspectRatio(
          ratioX: preset.targetWidth!.toDouble(),
          ratioY: preset.targetHeight!.toDouble(),
        ),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Frame ${preset.name}',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Frame ${preset.name}',
            aspectRatioLockEnabled: true,
          ),
        ],
      );

      if (cropped == null) {
        // User cancelled crop
        return;
      }
      currentImage = File(cropped.path);
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresetApplyScreen(
          initialImage: currentImage,
          preset: preset,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final presets = _filteredPresets;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isTab,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Govt & Exam Presets',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Exact dimensions & strict KB limits for forms',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
        child: Column(
          children: [
            // Category Filter Bar
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;

                  return FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _selectedCategory = category);
                      }
                    },
                    selectedColor: AppColors.primary.withValues(alpha: isDark ? 0.25 : 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // Presets List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: presets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final preset = presets[index];

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _handleSelectPreset(context, ref, preset),
                      borderRadius: BorderRadius.circular(16),
                      child: Ink(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainerLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                preset.iconEmoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          preset.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? AppColors.textPrimaryDark
                                                : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          preset.badgeText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    preset.description,
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
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
