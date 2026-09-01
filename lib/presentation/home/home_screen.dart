import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/preset_constants.dart';
import '../../data/models/history_item.dart';
import '../../data/models/image_preset.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/history_repository.dart';
import '../batch/batch_screen.dart';
import '../compressor/compressor_screen.dart';
import '../converter/converter_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../presets/presets_hub_screen.dart';
import '../resizer/resizer_screen.dart';
import '../result/result_screen.dart';
import '../settings/settings_screen.dart';
import '../signature/signature_cleaner_screen.dart';
import '../widgets/account_section.dart';
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
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked != null) {
      return File(picked.path);
    }
    return null;
  }

  Future<void> _handleCompressTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompressorScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleResizeTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResizerScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleConvertTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConverterScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handleCropTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: file.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Image',
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (cropped == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompressorScreen(
          initialImage: File(cropped.path),
          presetTitle: 'Cropped Image Options',
        ),
      ),
    );
  }

  Future<void> _handleBatchTool() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const BatchScreen(),
      ),
    );
  }

  Future<void> _handleSignatureTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignatureCleanerScreen(initialImage: file),
      ),
    );
  }

  Future<void> _handlePhotoStampTool() async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoStampScreen(initialImage: file),
      ),
    );
  }

  void _handlePresetSelected(ImagePreset preset) async {
    final file = await _pickImage();
    if (file == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompressorScreen(
          initialImage: file,
          prefilledTargetSizeKB: preset.targetSizeKB,
          presetTitle: preset.name,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Indian Govt & Exam Presets Carousel
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

                // 2. Quick Tools Grid
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Quick Tools',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      ToolCard(
                        title: 'Compress',
                        subtitle: 'Target KB / MB Size',
                        iconEmoji: '📦',
                        accentColor: AppColors.primary,
                        onTap: _handleCompressTool,
                      ),
                      ToolCard(
                        title: 'Resize',
                        subtitle: 'Pixels & Percentage',
                        iconEmoji: '🖼️',
                        accentColor: AppColors.secondary,
                        onTap: _handleResizeTool,
                      ),
                      ToolCard(
                        title: 'Convert',
                        subtitle: 'JPG, PNG, WebP',
                        iconEmoji: '🔄',
                        accentColor: Colors.purple,
                        onTap: _handleConvertTool,
                      ),
                      ToolCard(
                        title: 'Crop',
                        subtitle: 'Multi Aspect Ratios',
                        iconEmoji: '✂️',
                        accentColor: Colors.orange,
                        onTap: _handleCropTool,
                      ),
                      ToolCard(
                        title: 'Batch Optimizer',
                        subtitle: 'Multi-Image & Zip',
                        iconEmoji: '⚡',
                        accentColor: Colors.indigo,
                        onTap: _handleBatchTool,
                      ),
                      ToolCard(
                        title: 'Signature B&W',
                        subtitle: 'Shadow Removal Filter',
                        iconEmoji: '✍️',
                        accentColor: Colors.teal,
                        onTap: _handleSignatureTool,
                      ),
                      ToolCard(
                        title: 'Photo Stamp',
                        subtitle: 'Name & Date of Photo',
                        iconEmoji: '🏷️',
                        accentColor: Colors.deepOrange,
                        onTap: _handlePhotoStampTool,
                      ),
                      ToolCard(
                        title: 'Govt Presets',
                        subtitle: 'SSC, Vyapam, UPSC',
                        iconEmoji: '🇮🇳',
                        accentColor: Colors.green,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PresetsHubScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
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
    );
  }
}
