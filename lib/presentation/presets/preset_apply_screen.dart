import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/image_preset.dart';
import '../../data/models/process_options.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class PresetApplyScreen extends ConsumerStatefulWidget {
  final File initialImage;
  final ImagePreset preset;

  const PresetApplyScreen({
    super.key,
    required this.initialImage,
    required this.preset,
  });

  @override
  ConsumerState<PresetApplyScreen> createState() => _PresetApplyScreenState();
}

class _PresetApplyScreenState extends ConsumerState<PresetApplyScreen> {
  late File _currentImage;
  bool _isProcessing = false;
  int _currentSizeBytes = 0;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
    _currentSizeBytes = _currentImage.lengthSync();
  }

  Future<void> _handleReCrop() async {
    final preset = widget.preset;
    final hasDimensions = preset.targetWidth != null && preset.targetHeight != null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: _currentImage.path,
      aspectRatio: hasDimensions
          ? CropAspectRatio(
              ratioX: preset.targetWidth!.toDouble(),
              ratioY: preset.targetHeight!.toDouble(),
            )
          : null,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Frame ${preset.name}',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: hasDimensions,
          hideBottomControls: hasDimensions,
        ),
        IOSUiSettings(
          title: 'Frame ${preset.name}',
          aspectRatioLockEnabled: hasDimensions,
        ),
      ],
    );

    if (cropped != null && mounted) {
      setState(() {
        _currentImage = File(cropped.path);
        _currentSizeBytes = _currentImage.lengthSync();
      });
    }
  }

  Future<void> _handleApplyPreset() async {
    final preset = widget.preset;
    setState(() => _isProcessing = true);

    await CrashlyticsService.setProcessingContext(
      operation: 'preset_${preset.id}',
      inputWidth: preset.targetWidth ?? 0,
      inputHeight: preset.targetHeight ?? 0,
      inputSizeKb: (_currentSizeBytes / 1024).round(),
      outputFormat: preset.outputFormat,
    );

    try {
      final options = ProcessOptions(
        sourcePath: _currentImage.path,
        targetSizeKB: preset.targetSizeKB,
        outputFormat: preset.outputFormat,
        resizeMode: (preset.targetWidth != null && preset.targetHeight != null)
            ? ResizeMode.exactPixels
            : ResizeMode.none,
        targetWidth: preset.targetWidth,
        targetHeight: preset.targetHeight,
        keepAspectRatio: false, // Already cropped to exact aspect ratio
        strictDimensions: true,
      );

      final result = await ImageProcessor.processImage(options);

      AnalyticsService.logCompressionUsed(
        targetQuality: result.finalQuality,
        originalSizeKb: (_currentSizeBytes / 1024).round(),
        compressedSizeKb: (result.outputSizeBytes / 1024).round(),
      );

      await CrashlyticsService.clearProcessingContext();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'Preset processing error');

      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processing failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final preset = widget.preset;

    return Scaffold(
      appBar: AppBar(
        title: Text(preset.name),
        actions: [
          IconButton(
            tooltip: 'Adjust Framing',
            icon: const Icon(Icons.crop_rotate_rounded),
            onPressed: _isProcessing ? null : _handleReCrop,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Preset Requirement Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
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
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Image Preview Container
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      width: double.infinity,
                      color: isDark ? Colors.black26 : Colors.black12,
                      child: Image.file(
                        _currentImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 16,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Current: ${_currentSizeBytes.toReadableFileSize()}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: _isProcessing ? null : _handleReCrop,
                            icon: const Icon(Icons.crop, size: 15),
                            label: const Text('Adjust Crop', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Portal Compliance Checklist
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.verified_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Portal Requirements To Be Applied',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCheckItem(
                      icon: Icons.aspect_ratio_rounded,
                      title: 'Dimensions',
                      value: preset.targetWidth != null && preset.targetHeight != null
                          ? '${preset.targetWidth} × ${preset.targetHeight} px (Strict)'
                          : 'Original Aspect',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCheckItem(
                      icon: Icons.data_usage_rounded,
                      title: 'Target Size',
                      value: preset.minSizeKB != null
                          ? '${preset.minSizeKB} KB to ${preset.targetSizeKB} KB'
                          : '< ${preset.targetSizeKB} KB',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildCheckItem(
                      icon: Icons.file_present_rounded,
                      title: 'Output Format',
                      value: '${preset.outputFormat.toUpperCase()} (Standard)',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // 4. One-Click Apply Button
              GradientButton(
                text: 'Make Exam-Ready',
                icon: Icons.bolt_rounded,
                isLoading: _isProcessing,
                onPressed: _handleApplyPreset,
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  '100% Offline & Private · Strict Portal Validation',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
        ),
        const Icon(Icons.check_circle, size: 16, color: AppColors.success),
      ],
    );
  }
}
