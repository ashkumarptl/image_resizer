import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../core/constants/preset_constants.dart';
import '../../data/models/history_item.dart';
import '../../data/models/image_preset.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/usage_limit_repository.dart';
import '../batch/batch_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../presets/preset_apply_screen.dart';
import '../presets/presets_hub_screen.dart';
import '../result/result_screen.dart';
import '../settings/settings_screen.dart';
import '../signature/signature_cleaner_screen.dart';
import '../studio/image_studio_screen.dart';
import '../widgets/account_section.dart';
import '../widgets/login_gate_dialog.dart';
import 'widgets/preset_carousel.dart';
import 'widgets/recent_files_section.dart';
import 'widgets/tool_card.dart';

final recentHistoryProvider = FutureProvider.autoDispose<List<HistoryItem>>((ref) async {
  return ref.watch(historyRepositoryProvider).getRecentHistory();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
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

  Future<void> _handleStudioTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(initialImage: file),
      ),
    );
  }



  Future<void> _handleBatchTool() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BatchScreen(),
      ),
    );
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

  void _handlePresetSelected(ImagePreset preset) async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final file = await _pickImage();
    if (file == null || !mounted) return;

    File currentImage = file;
    final hasDimensions = preset.targetWidth != null && preset.targetHeight != null;

    if (hasDimensions) {
      try {
        final cropped = await ImageCropper().cropImage(
          sourcePath: file.path,
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

        if (cropped == null || !mounted) {
          // User cancelled crop
          return;
        }
        currentImage = File(cropped.path);
      } catch (e) {
        debugPrint('Image cropper not supported on this platform: $e');
        // Fallback to uncropped source image on desktop platforms
        currentImage = file;
      }
    }

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PresetApplyScreen(
          initialImage: currentImage,
          preset: preset,
        ),
      ),
    );
  }

  void _handleHistoryItemTap(HistoryItem item) {
    final originalFile = File(item.originalPath.isNotEmpty ? item.originalPath : item.filePath);

    final dummyResult = ProcessResult(
      originalPath: originalFile.path,
      outputPath: item.filePath,
      originalSizeBytes: item.originalSizeBytes,
      outputSizeBytes: item.outputSizeBytes,
      originalWidth: item.width,
      originalHeight: item.height,
      outputWidth: item.width,
      outputHeight: item.height,
      outputFormat: item.format,
      finalQuality: 85,
      processingTime: Duration.zero,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(result: dummyResult),
      ),
    );
  }

  Future<void> _handleClearHistory() async {
    await ref.read(historyRepositoryProvider).clearHistory();
    ref.invalidate(recentHistoryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final historyAsync = ref.watch(recentHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  AppConstants.appName,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainerLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'OFFLINE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              AppConstants.appTagline,
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Theme',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(recentHistoryProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: AdaptivePageContainer(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Guest Usage Trial Banner
                  _buildGuestUsageBanner(context, isDark),

                  // 1. Quick Image Tools Grid
                  // 1. Core Studio & Batch Tools
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: Text(
                      'Core Studio',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: context.responsiveValue<double>(
                        compact: 1.05,
                        medium: 1.30,
                        expanded: 1.50,
                      ),
                      children: [
                        ToolCard(
                          title: 'Single Studio',
                          subtitle: 'Crop, Resize, Compress, Convert',
                          iconEmoji: '🎨',
                          accentColor: AppColors.primary,
                          onTap: _handleStudioTool,
                        ),
                        ToolCard(
                          title: 'Batch Optimizer',
                          subtitle: 'Multiple Images & Zip Export',
                          iconEmoji: '⚡',
                          accentColor: Colors.indigo,
                          onTap: _handleBatchTool,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 2. Exam & Document Utilities Section
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: Row(
                      children: [
                        Text(
                          'Exam & Document Tools',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'SPECIAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.adaptiveMargin),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: context.responsiveValue<double>(
                        compact: 1.05,
                        medium: 1.30,
                        expanded: 1.50,
                      ),
                      children: [
                        ToolCard(
                          title: 'Signature B&W',
                          subtitle: 'Shadow Removal Filter',
                          iconEmoji: '✍️',
                          accentColor: Colors.teal,
                          onTap: _handleSignatureTool,
                        ),
                        ToolCard(
                          title: 'Photo Stamp',
                          subtitle: 'Name & Date on Photo',
                          iconEmoji: '🏷️',
                          accentColor: Colors.deepOrange,
                          onTap: _handlePhotoStampTool,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Govt & Exam Presets Carousel
                  PresetCarousel(
                    presets: PresetConstants.indianGovtPresets,
                    onPresetTap: _handlePresetSelected,
                    onSeeAllTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PresetsHubScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. Recent Processed Files Section
                  historyAsync.when(
                    data: (historyList) => RecentFilesSection(
                      historyItems: historyList,
                      onItemTap: _handleHistoryItemTap,
                      onClearHistory: _handleClearHistory,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestUsageBanner(BuildContext context, bool isDark) {
    final isDeveloper = ref.watch(isDeveloperProvider);
    if (isDeveloper) {
      // Developer has unlimited access and should not see limit banner
      return const SizedBox.shrink();
    }

    final user = ref.watch(currentUserProvider);
    if (user != null) {
      // Authenticated user has unlimited access
      return const SizedBox.shrink();
    }

    final usageCount = ref.watch(guestUsageCountProvider);
    final remaining = (AppConstants.maxFreeGuestUses - usageCount).clamp(0, AppConstants.maxFreeGuestUses);
    final isLimitReached = usageCount >= AppConstants.maxFreeGuestUses;

    return Padding(
      padding: EdgeInsets.fromLTRB(context.adaptiveMargin, 0, context.adaptiveMargin, 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLimitReached) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (ctx) => const LoginGateBottomSheet(),
              );
            } else {
              showAccountBottomSheet(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isLimitReached
                    ? [
                        AppColors.error.withValues(alpha: isDark ? 0.25 : 0.12),
                        AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.08),
                      ]
                    : [
                        AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.1),
                        AppColors.primaryDark.withValues(alpha: isDark ? 0.15 : 0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isLimitReached
                    ? AppColors.error.withValues(alpha: 0.5)
                    : AppColors.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLimitReached
                        ? AppColors.error.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLimitReached ? Icons.lock_outline_rounded : Icons.bolt_rounded,
                    size: 20,
                    color: isLimitReached ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLimitReached
                            ? 'Free Limit Reached (${AppConstants.maxFreeGuestUses}/${AppConstants.maxFreeGuestUses} used)'
                            : 'Free Trial: $remaining of ${AppConstants.maxFreeGuestUses} uses remaining',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLimitReached
                              ? (isDark ? Colors.red.shade300 : AppColors.error)
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLimitReached
                            ? 'Sign in with Google for unlimited access'
                            : 'Sign in to unlock unlimited usage & presets',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLimitReached ? AppColors.error : AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isLimitReached ? 'Sign In' : 'Unlock',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

