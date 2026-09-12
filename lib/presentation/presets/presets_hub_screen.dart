import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_radii.dart';
import '../../core/constants/preset_constants.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/image_preset.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/preset_favorites_repository.dart';
import '../perspective_crop/perspective_crop_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../signature/signature_cleaner_screen.dart';
import '../widgets/account_section.dart';
import '../widgets/image_source_picker_sheet.dart';
import '../widgets/login_gate_dialog.dart';
import 'preset_apply_screen.dart';

class PresetsHubScreen extends ConsumerStatefulWidget {
  final bool isTab;
  final int initialTabIndex;

  const PresetsHubScreen({
    super.key,
    this.isTab = false,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<PresetsHubScreen> createState() => _PresetsHubScreenState();
}

class _PresetsHubScreenState extends ConsumerState<PresetsHubScreen> {
  late int _selectedTabIndex;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Central Govt',
    'State PSC',
    'Banking',
    'Defence',
    'Academic',
    'ID & Docs',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ImagePreset> get _filteredPresets {
    var list = PresetConstants.indianGovtPresets;

    if (_selectedCategory == 'Central Govt') {
      list = list
          .where(
            (p) =>
                p.examCategory == ExamCategory.centralGovt ||
                p.id.startsWith('ssc_') ||
                p.id.startsWith('upsc_') ||
                p.id.startsWith('rrb_'),
          )
          .toList();
    } else if (_selectedCategory == 'State PSC') {
      list = list
          .where(
            (p) =>
                p.examCategory == ExamCategory.statePsc ||
                p.id.startsWith('cg_vyapam_') ||
                p.id.startsWith('bpsc_') ||
                p.id.startsWith('uppsc_') ||
                p.id.startsWith('mppsc_'),
          )
          .toList();
    } else if (_selectedCategory == 'Banking') {
      list = list
          .where(
            (p) =>
                p.examCategory == ExamCategory.banking ||
                p.id.startsWith('ibps_') ||
                p.id.startsWith('sbi_'),
          )
          .toList();
    } else if (_selectedCategory == 'Defence') {
      list = list
          .where(
            (p) =>
                p.examCategory == ExamCategory.defence ||
                p.id.startsWith('nda_') ||
                p.id.startsWith('afcat_') ||
                p.id.startsWith('agniveer_'),
          )
          .toList();
    } else if (_selectedCategory == 'Academic') {
      list = list
          .where(
            (p) =>
                p.examCategory == ExamCategory.academic ||
                p.id.startsWith('gate_') ||
                p.id.startsWith('jee_') ||
                p.id.startsWith('neet_') ||
                p.id.startsWith('cuet_'),
          )
          .toList();
    } else if (_selectedCategory == 'ID & Docs') {
      list = list
          .where(
            (p) =>
                p.category == PresetCategory.identity ||
                p.examCategory == ExamCategory.identity,
          )
          .toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      list = list.where((p) => p.matchesQuery(_searchQuery)).toList();
    }

    return list;
  }

  Future<File?> _pickImage({String title = 'Select Image Source'}) async {
    return ImageSourcePickerSheet.show(context, title: title);
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
      MaterialPageRoute(builder: (_) => PhotoStampScreen(initialImage: file)),
    );
  }

  Future<void> _handlePerspectiveCropTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage(title: 'Select Document / Photo to Deskew');
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerspectiveCropScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleSelectPreset(
    BuildContext context,
    WidgetRef ref,
    ImagePreset preset,
  ) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !context.mounted) return;

    final pickedFile = await ImageSourcePickerSheet.show(
      context,
      title: 'Frame for ${preset.name}',
    );
    if (pickedFile == null || !context.mounted) return;

    File currentImage = pickedFile;
    final hasDimensions =
        preset.targetWidth != null && preset.targetHeight != null;

    if (hasDimensions) {
      final cropped = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
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
        return;
      }
      currentImage = File(cropped.path);
    }

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            PresetApplyScreen(initialImage: currentImage, preset: preset),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarRadius = context.isLargeTablet ? 24.0 : (context.isMediumOrWider ? 20.0 : 14.0);
    final avatarFontSize = context.isLargeTablet ? 18.0 : (context.isMediumOrWider ? 15.0 : 12.0);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: context.isLargeTablet ? 84 : (context.isMediumOrWider ? 72 : null),
        automaticallyImplyLeading: !widget.isTab,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedTabIndex == 0
                  ? 'Exam Document Tools'
                  : 'Govt & Exam Presets',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: context.adaptiveFontSize(20, tabletSize: 26, largeTabletSize: 28),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _selectedTabIndex == 0
                  ? 'Specialized utilities for Govt & Exam portals'
                  : 'Exact dimensions & strict KB limits for forms',
              style: TextStyle(
                fontSize: context.adaptiveFontSize(11, tabletSize: 14, largeTabletSize: 15.5),
                fontWeight: FontWeight.normal,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
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
                        radius: avatarRadius,
                        backgroundColor: AppColors.primaryContainerLight,
                        backgroundImage: photoUrl != null
                            ? NetworkImage(photoUrl)
                            : null,
                        child: photoUrl == null
                            ? Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'U',
                                style: TextStyle(
                                  fontSize: avatarFontSize,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryDark,
                                ),
                              )
                            : null,
                      ),
                    );
                  } else {
                    return IconButton(
                      icon: Icon(
                        Icons.account_circle_outlined,
                        size: context.adaptiveIconSize(24, tabletSize: 32, largeTabletSize: 36),
                      ),
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
                  icon: Icon(
                    Icons.account_circle_outlined,
                    size: context.adaptiveIconSize(24, tabletSize: 32, largeTabletSize: 36),
                  ),
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
            // Top Tab Switcher (Exam Tools vs Presets)
            Padding(
              padding: EdgeInsets.fromLTRB(
                context.adaptiveMargin,
                context.isMediumOrWider ? 16 : 12,
                context.adaptiveMargin,
                context.isMediumOrWider ? 12 : 8,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: context.isLargeTablet ? 560 : 480),
                  child: Container(
                    height: context.isLargeTablet ? 54 : (context.isMediumOrWider ? 48 : 44),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(27),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabPill(
                            label: 'Exam Tools',
                            icon: Icons.draw_rounded,
                            isSelected: _selectedTabIndex == 0,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedTabIndex = 0),
                          ),
                        ),
                        Expanded(
                          child: _buildTabPill(
                            label: 'Presets',
                            icon: Icons.tune_rounded,
                            isSelected: _selectedTabIndex == 1,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedTabIndex = 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Tab Content
            Expanded(
              child: _selectedTabIndex == 0
                  ? _buildExamToolsTab(context, isDark)
                  : _buildPresetsTab(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: context.adaptiveIconSize(16, tabletSize: 20, largeTabletSize: 22),
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: context.adaptiveFontSize(13, tabletSize: 16, largeTabletSize: 17.5),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsTab(BuildContext context, bool isDark) {
    final presets = _filteredPresets;
    final favoriteIds = ref.watch(favoritePresetIdsProvider);

    return AdaptivePageContainer(
      maxWidth: 1200,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Sticky Search Bar
          Padding(
            padding: EdgeInsets.fromLTRB(context.adaptiveMargin, 8, context.adaptiveMargin, 8),
            child: Container(
              height: context.isLargeTablet ? 58 : (context.isMediumOrWider ? 48 : 38),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(context.isLargeTablet ? 16 : 12),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(13, tabletSize: 16, largeTabletSize: 18.5),
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search UPSC, SSC, GATE, NEET, 50 KB...',
                  hintStyle: TextStyle(
                    fontSize: context.adaptiveFontSize(13, tabletSize: 16, largeTabletSize: 18.5),
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: context.adaptiveIconSize(20, tabletSize: 24, largeTabletSize: 28),
                    color: AppColors.primary,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: context.adaptiveIconSize(18, tabletSize: 22, largeTabletSize: 26),
                          ),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: context.isLargeTablet ? 18 : (context.isMediumOrWider ? 14 : 12)),
                ),
              ),
            ),
          ),

          // 2. Category Filter Chips Bar
          Container(
            height: context.isLargeTablet ? 52 : (context.isMediumOrWider ? 48 : 44),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
              itemCount: _categories.length,
              separatorBuilder: (_, _) => SizedBox(width: context.isLargeTablet ? 12 : (context.isMediumOrWider ? 10 : 8)),
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;

                return FilterChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = category);
                    }
                  },
                  selectedColor: AppColors.primary.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: context.adaptiveFontSize(12, tabletSize: 14.5, largeTabletSize: 16),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? (isDark ? AppColors.primaryLight : AppColors.primary)
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                  ),
                  backgroundColor: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.surfaceVariantLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.isLargeTablet ? 14 : 10),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.borderDark
                                : AppColors.borderLight),
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: context.isLargeTablet ? 14 : (context.isMediumOrWider ? 12 : 10),
                    vertical: context.isLargeTablet ? 4 : 2,
                  ),
                );
              },
            ),
          ),

          // 3. Pinned Presets Quick Access Bar
          if (favoriteIds.isNotEmpty && _searchQuery.isEmpty) ...[
            Padding(
              padding: EdgeInsets.fromLTRB(context.adaptiveMargin, 8, context.adaptiveMargin, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: context.adaptiveIconSize(14, tabletSize: 18, largeTabletSize: 20),
                    color: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Pinned Presets',
                    style: TextStyle(
                      fontSize: context.adaptiveFontSize(11, tabletSize: 14, largeTabletSize: 15.5),
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Shown on Home Screen',
                    style: TextStyle(
                      fontSize: context.adaptiveFontSize(10, tabletSize: 12.5, largeTabletSize: 14),
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: context.isLargeTablet ? 48 : (context.isMediumOrWider ? 44 : 38),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                children: PresetConstants.indianGovtPresets
                    .where((p) => favoriteIds.contains(p.id))
                    .map(
                      (p) => Padding(
                        padding: EdgeInsets.only(right: context.isMediumOrWider ? 10 : 8),
                        child: ActionChip(
                          avatar: Text(
                            p.iconEmoji,
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 17),
                            ),
                          ),
                          label: Text(
                            p.name,
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(11, tabletSize: 13.5, largeTabletSize: 15),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: const Color(
                            0xFFF59E0B,
                          ).withValues(alpha: 0.12),
                          side: const BorderSide(
                            color: Color(0xFFF59E0B),
                            width: 1,
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: context.isMediumOrWider ? 8 : 4,
                            vertical: context.isMediumOrWider ? 4 : 0,
                          ),
                          onPressed: () => _handleSelectPreset(context, ref, p),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 4),
          ],

          const Divider(height: 1),

          // 4. Presets List (Responsive Grid on Horizontal/Wide Screens, ListView on Mobile)
          Expanded(
            child: presets.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No presets found',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No presets match "$_searchQuery". Try a different search.'
                                : 'Try a different exam name, keyword (e.g. UPSC, SSC, GATE) or clear filters.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Clear Search & Filters'),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                                _selectedCategory = 'All';
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 640;

                      if (isWide) {
                        return GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            context.adaptiveMargin,
                            context.isMediumOrWider ? 16 : 12,
                            context.adaptiveMargin,
                            100,
                          ),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: context.isLargeTablet ? 20 : (context.isMediumOrWider ? 16 : 14),
                            mainAxisSpacing: context.isLargeTablet ? 16 : (context.isMediumOrWider ? 14 : 10),
                            mainAxisExtent: context.isLargeTablet ? 142 : (context.isMediumOrWider ? 114 : 94),
                          ),
                          itemCount: presets.length,
                          itemBuilder: (context, index) {
                            return _buildPresetCard(
                              context,
                              ref,
                              presets[index],
                              favoriteIds,
                              isDark,
                            );
                          },
                        );
                      }

                      return Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              context.adaptiveMargin,
                              12,
                              context.adaptiveMargin,
                              100,
                            ),
                            itemCount: presets.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildPresetCard(
                                context,
                                ref,
                                presets[index],
                                favoriteIds,
                                isDark,
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetCard(
    BuildContext context,
    WidgetRef ref,
    ImagePreset preset,
    Set<String> favoriteIds,
    bool isDark,
  ) {
    final isPinned = favoriteIds.contains(preset.id);
    final emojiBoxSize = context.adaptiveIconSize(44, tabletSize: 56, largeTabletSize: 68);
    final starIconSize = context.adaptiveIconSize(24, tabletSize: 30, largeTabletSize: 36);
    final starBtnBox = context.isLargeTablet ? 52.0 : (context.isMediumOrWider ? 44.0 : 36.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _handleSelectPreset(context, ref, preset);
        },
        borderRadius: AppRadii.cardRadius,
        child: Ink(
          padding: EdgeInsets.all(context.isLargeTablet ? 20 : (context.isMediumOrWider ? 16 : 14)),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.surfaceDark
                : AppColors.surfaceLight,
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: isPinned
                  ? const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: 0.6)
                  : (isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight),
              width: isPinned ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isPinned
                    ? const Color(
                        0xFFF59E0B,
                      ).withValues(alpha: 0.08)
                    : Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.03,
                      ),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: emojiBoxSize,
                height: emojiBoxSize,
                decoration: BoxDecoration(
                  color: isPinned
                      ? const Color(
                          0xFFF59E0B,
                        ).withValues(alpha: 0.15)
                      : AppColors.primaryContainerLight,
                  borderRadius: AppRadii.cardInnerRadius,
                ),
                alignment: Alignment.center,
                child: Text(
                  preset.iconEmoji,
                  style: TextStyle(
                    fontSize: context.adaptiveFontSize(22, tabletSize: 28, largeTabletSize: 34),
                  ),
                ),
              ),
              SizedBox(width: context.isLargeTablet ? 16 : (context.isMediumOrWider ? 14 : 12)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            preset.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(14.5, tabletSize: 18, largeTabletSize: 21.5),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: context.isLargeTablet ? 12 : (context.isMediumOrWider ? 9 : 7),
                            vertical: context.isLargeTablet ? 5 : (context.isMediumOrWider ? 3.5 : 2),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: AppRadii.badgeRadius,
                          ),
                          child: Text(
                            preset.badgeText,
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(10.5, tabletSize: 13, largeTabletSize: 15.5),
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preset.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(11.5, tabletSize: 14.5, largeTabletSize: 16.5),
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Star / Pin Button
              IconButton(
                icon: Icon(
                  isPinned
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: isPinned
                      ? const Color(0xFFF59E0B)
                      : (isDark
                            ? Colors.white38
                            : Colors.black38),
                  size: starIconSize,
                ),
                tooltip: isPinned
                    ? 'Unpin Preset'
                    : 'Pin to Home ⭐',
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: starBtnBox,
                  minHeight: starBtnBox,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(favoritePresetIdsProvider.notifier)
                      .toggleFavorite(preset.id);
                  ScaffoldMessenger.of(
                    context,
                  ).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isPinned
                            ? 'Unpinned "${preset.name}"'
                            : 'Pinned "${preset.name}" to Home Screen ⭐',
                      ),
                      duration: const Duration(
                        milliseconds: 1400,
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),

              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamToolsTab(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: AdaptivePageContainer(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sleek info banner
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.isLargeTablet ? 24 : (context.isMediumOrWider ? 18 : 14),
                  vertical: context.isLargeTablet ? 18 : (context.isMediumOrWider ? 14 : 10),
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : AppColors.primaryContainerLight.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(context.isLargeTablet ? 18 : 14),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: context.adaptiveIconSize(34, tabletSize: 46, largeTabletSize: 58),
                      height: context.adaptiveIconSize(34, tabletSize: 46, largeTabletSize: 58),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(
                          alpha: isDark ? 0.25 : 0.12,
                        ),
                        borderRadius: BorderRadius.circular(context.isLargeTablet ? 14 : 10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.verified_outlined,
                        size: context.adaptiveIconSize(18, tabletSize: 24, largeTabletSize: 30),
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                    SizedBox(width: context.isMediumOrWider ? 16 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Exam Document Tools',
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(13, tabletSize: 17, largeTabletSize: 21),
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Specialized utilities for SSC, UPSC, IBPS, Vyapam & State PSC portals',
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(11, tabletSize: 14, largeTabletSize: 16.5),
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
            const SizedBox(height: 14),

            // Tool Cards (Responsive Grid/Row on wide screens, stacked on mobile)
            if (context.isMediumOrWider) ...[
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final is3Cols = context.isLandscape && constraints.maxWidth >= 900;
                    if (is3Cols) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildToolCard(
                                context: context,
                                isDark: isDark,
                                title: 'Signature B&W Cleaner',
                                subtitle: 'Shadow Removal & Pure B&W',
                                icon: Icons.draw_rounded,
                                accentColor: Colors.teal,
                                badges: const ['< 20 KB', '400×200 px', 'Monochrome'],
                                description:
                                    'Converts paper signatures into crisp digital monochrome. Removes shadows, paper grain, and yellow tint.',
                                onTap: _handleSignatureTool,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildToolCard(
                                context: context,
                                isDark: isDark,
                                title: 'Name & Date Photo Stamp',
                                subtitle: 'Mandatory for SSC & UPSC Notices',
                                icon: Icons.badge_outlined,
                                accentColor: Colors.deepOrange,
                                badges: const ['< 50 KB', 'Custom DOP', 'White Footer'],
                                description:
                                    'Superimposes candidate name & Date of Photo (DOP) on passport photos with strict size compression.',
                                onTap: _handlePhotoStampTool,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildToolCard(
                                context: context,
                                isDark: isDark,
                                title: 'Perspective Crop & Deskew',
                                subtitle: '4-Point Keystone Document Straightener',
                                icon: Icons.crop_rotate_rounded,
                                accentColor: AppColors.primary,
                                badges: const ['A4 & ID Cards', 'Auto-Deskew', 'Flat Scan'],
                                description:
                                    'Straightens camera photos of angled documents and certificates into flat, scanner-grade digital scans.',
                                onTap: _handlePerspectiveCropTool,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      return Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _buildToolCard(
                                    context: context,
                                    isDark: isDark,
                                    title: 'Signature B&W Cleaner',
                                    subtitle: 'Shadow Removal & Pure B&W',
                                    icon: Icons.draw_rounded,
                                    accentColor: Colors.teal,
                                    badges: const ['< 20 KB', '400×200 px'],
                                    description:
                                        'Converts paper signatures into crisp digital monochrome.',
                                    onTap: _handleSignatureTool,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildToolCard(
                                    context: context,
                                    isDark: isDark,
                                    title: 'Name & Date Photo Stamp',
                                    subtitle: 'SSC & UPSC Notices',
                                    icon: Icons.badge_outlined,
                                    accentColor: Colors.deepOrange,
                                    badges: const ['< 50 KB', 'Custom DOP'],
                                    description:
                                        'Superimposes candidate name & DOP on photos.',
                                    onTap: _handlePhotoStampTool,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildToolCard(
                            context: context,
                            isDark: isDark,
                            title: 'Perspective Crop & Deskew',
                            subtitle: '4-Point Keystone Document Straightener',
                            icon: Icons.crop_rotate_rounded,
                            accentColor: AppColors.primary,
                            badges: const ['A4 & ID Cards', 'Auto-Deskew', 'Flat Scan'],
                            description:
                                'Straightens camera photos of angled documents and certificates into flat, scanner-grade digital scans.',
                            onTap: _handlePerspectiveCropTool,
                          ),
                        ],
                      );
                    }
                  },
                ),
              ),
            ] else ...[
              // Tool 1: Signature B&W Cleaner
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                child: _buildToolCard(
                  context: context,
                  isDark: isDark,
                  title: 'Signature B&W Cleaner',
                  subtitle: 'Shadow Removal & Pure B&W',
                  icon: Icons.draw_rounded,
                  accentColor: Colors.teal,
                  badges: const ['< 20 KB', '400×200 px', 'Monochrome'],
                  description:
                      'Converts paper signatures into crisp digital monochrome. Removes shadows, paper grain, and yellow tint.',
                  onTap: _handleSignatureTool,
                ),
              ),
              const SizedBox(height: 12),

              // Tool 2: Photo Stamp Utility
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                child: _buildToolCard(
                  context: context,
                  isDark: isDark,
                  title: 'Name & Date Photo Stamp',
                  subtitle: 'Mandatory for SSC & UPSC Notices',
                  icon: Icons.badge_outlined,
                  accentColor: Colors.deepOrange,
                  badges: const ['< 50 KB', 'Custom DOP', 'White Footer'],
                  description:
                      'Superimposes candidate name & Date of Photo (DOP) on passport photos with strict size compression.',
                  onTap: _handlePhotoStampTool,
                ),
              ),
              const SizedBox(height: 12),

              // Tool 3: Perspective Crop & Deskew
              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                child: _buildToolCard(
                  context: context,
                  isDark: isDark,
                  title: 'Perspective Crop & Deskew',
                  subtitle: '4-Point Keystone Document Straightener',
                  icon: Icons.crop_rotate_rounded,
                  accentColor: AppColors.primary,
                  badges: const ['A4 & ID Cards', 'Auto-Deskew', 'Flat Scan'],
                  description:
                      'Straightens camera photos of angled documents and certificates into flat, scanner-grade digital scans.',
                  onTap: _handlePerspectiveCropTool,
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Guidance & Rules Collapsible Card
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
              child: Material(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? AppColors.borderDark
                          : AppColors.borderLight,
                    ),
                  ),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                    initiallyExpanded: false,
                    tilePadding: EdgeInsets.symmetric(
                      horizontal: context.isMediumOrWider ? 18 : 14,
                      vertical: context.isMediumOrWider ? 6 : 2,
                    ),
                    childrenPadding: EdgeInsets.fromLTRB(
                      context.isMediumOrWider ? 18 : 14,
                      0,
                      context.isMediumOrWider ? 18 : 14,
                      context.isMediumOrWider ? 18 : 14,
                    ),
                    leading: Container(
                      width: context.adaptiveIconSize(34, tabletSize: 46, largeTabletSize: 52),
                      height: context.adaptiveIconSize(34, tabletSize: 46, largeTabletSize: 52),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.2 : 0.1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: context.adaptiveIconSize(18, tabletSize: 24, largeTabletSize: 28),
                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                      ),
                    ),
                    title: Text(
                      'Exam Upload Guidelines',
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(13, tabletSize: 17, largeTabletSize: 19),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Common specifications for photo, sign & date',
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(11, tabletSize: 14, largeTabletSize: 15.5),
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    children: [
                      const Divider(height: 16),
                      _buildGuidelineRow(
                        context,
                        isDark,
                        Icons.portrait_rounded,
                        'Passport Photo',
                        'Light/white background, 3.5cm × 4.5cm, strictly 20 KB – 50 KB.',
                      ),
                      const SizedBox(height: 8),
                      _buildGuidelineRow(
                        context,
                        isDark,
                        Icons.draw_rounded,
                        'Signature',
                        'Black/blue ink on white paper, 4.0cm × 2.0cm, 10 KB – 20 KB.',
                      ),
                      const SizedBox(height: 8),
                      _buildGuidelineRow(
                        context,
                        isDark,
                        Icons.calendar_today_rounded,
                        'Photo Date (DOP)',
                        'Must not be older than 3 months from notification date.',
                      ),
                      SizedBox(height: context.isMediumOrWider ? 18 : 14),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _selectedTabIndex = 1),
                          icon: Icon(
                            Icons.tune_rounded,
                            size: context.adaptiveIconSize(16, tabletSize: 20, largeTabletSize: 22),
                          ),
                          label: Text(
                            'Browse All Govt & Exam Presets',
                            style: TextStyle(
                              fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 16.5),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: context.isMediumOrWider ? 14 : 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required List<String> badges,
    required String description,
    required VoidCallback onTap,
  }) {
    final iconBoxSize = context.adaptiveIconSize(40, tabletSize: 52, largeTabletSize: 68);
    final iconActionSize = context.adaptiveIconSize(20, tabletSize: 28, largeTabletSize: 36);
    final arrowCircleSize = context.adaptiveIconSize(30, tabletSize: 38, largeTabletSize: 46);

    return Material(
      color: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(context.isLargeTablet ? 20 : 16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(context.isLargeTablet ? 20 : 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(context.isLargeTablet ? 20 : 16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(context.isLargeTablet ? 24 : (context.isMediumOrWider ? 18 : 14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.22 : 0.1),
                      borderRadius: BorderRadius.circular(context.isLargeTablet ? 16 : 12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      icon,
                      size: iconActionSize,
                      color: accentColor,
                    ),
                  ),
                  SizedBox(width: context.isMediumOrWider ? 16 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(14, tabletSize: 18, largeTabletSize: 22),
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: context.adaptiveFontSize(11, tabletSize: 14, largeTabletSize: 16.5),
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: arrowCircleSize,
                    height: arrowCircleSize,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: isDark ? 0.18 : 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: context.adaptiveIconSize(15, tabletSize: 20, largeTabletSize: 26),
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: context.isLargeTablet ? 16 : (context.isMediumOrWider ? 12 : 8)),
              Text(
                description,
                style: TextStyle(
                  fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 17.0),
                  height: 1.35,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              SizedBox(height: context.isLargeTablet ? 16 : (context.isMediumOrWider ? 12 : 8)),
              Wrap(
                spacing: context.isMediumOrWider ? 8 : 6,
                runSpacing: context.isMediumOrWider ? 6 : 4,
                children: badges.map((badge) {
                  return Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.isLargeTablet ? 12 : (context.isMediumOrWider ? 9 : 7),
                      vertical: context.isLargeTablet ? 6 : (context.isMediumOrWider ? 4 : 3),
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceLight.withValues(alpha: 0.06)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(context.isLargeTablet ? 8 : 6),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark.withValues(alpha: 0.6)
                            : AppColors.borderLight,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: context.adaptiveFontSize(10.5, tabletSize: 13, largeTabletSize: 15.5),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark.withValues(alpha: 0.85)
                            : AppColors.textPrimaryLight.withValues(alpha: 0.85),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineRow(
    BuildContext context,
    bool isDark,
    IconData icon,
    String title,
    String detail,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: context.adaptiveIconSize(16, tabletSize: 20, largeTabletSize: 22),
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        SizedBox(width: context.isMediumOrWider ? 10 : 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: context.adaptiveFontSize(12, tabletSize: 15, largeTabletSize: 16.5),
                height: 1.4,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(
                  text: detail,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
