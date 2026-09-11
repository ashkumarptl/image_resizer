import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_result.dart';
import '../../services/image_service/signature_enhancer.dart';
import '../result/result_screen.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/gradient_button.dart';

class SignatureCleanerScreen extends StatefulWidget {
  final File initialImage;

  const SignatureCleanerScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<SignatureCleanerScreen> createState() => _SignatureCleanerScreenState();
}

class _SignatureCleanerScreenState extends State<SignatureCleanerScreen> {
  late File _currentImage;
  late int _originalSizeBytes;

  // Processing & Adjustment state
  double _threshold = 0.65;
  int _targetSizeKB = 19;
  int _quarterTurns = 0;
  SignatureInkColor _inkColor = SignatureInkColor.darkNavy;

  // Live preview state
  Timer? _debounceTimer;
  int _previewRequestId = 0;
  bool _isGeneratingPreview = false;
  ProcessResult? _previewResult;
  File? _previewImageFile;
  bool _showOriginal = false;
  bool _isProcessing = false;

  bool get _hasChanges =>
      _threshold != 0.65 ||
      _targetSizeKB != 19 ||
      _quarterTurns != 0 ||
      _inkColor != SignatureInkColor.darkNavy ||
      _currentImage.path != widget.initialImage.path;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
    _originalSizeBytes = widget.initialImage.lengthSync();
    _triggerPreviewUpdate(debounce: false);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _triggerPreviewUpdate({bool debounce = true}) {
    _debounceTimer?.cancel();
    if (debounce) {
      _debounceTimer = Timer(const Duration(milliseconds: 180), _generatePreview);
    } else {
      _generatePreview();
    }
  }

  Future<void> _generatePreview() async {
    if (!mounted) return;
    final requestId = ++_previewRequestId;

    setState(() => _isGeneratingPreview = true);

    try {
      final options = SignatureEnhanceOptions(
        sourcePath: _currentImage.path,
        threshold: _threshold,
        targetSizeKB: _targetSizeKB,
        targetWidth: 400,
        targetHeight: 200,
        quarterTurns: _quarterTurns,
        inkColor: _inkColor,
      );

      final result = await SignatureEnhancer.enhanceSignature(options);
      if (!mounted || requestId != _previewRequestId) return;

      setState(() {
        _previewResult = result;
        _previewImageFile = File(result.outputPath);
        _isGeneratingPreview = false;
      });
    } catch (_) {
      if (!mounted || requestId != _previewRequestId) return;
      setState(() => _isGeneratingPreview = false);
    }
  }

  Future<void> _handleRotate() async {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
    _triggerPreviewUpdate(debounce: false);
  }

  Future<void> _handleCrop() async {
    HapticFeedback.lightImpact();
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentImage.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Signature',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Signature',
          ),
        ],
      );

      if (cropped != null && mounted) {
        final newFile = File(cropped.path);
        setState(() {
          _currentImage = newFile;
          _originalSizeBytes = newFile.lengthSync();
          _quarterTurns = 0;
        });
        _triggerPreviewUpdate(debounce: false);
      }
    } catch (_) {}
  }

  void _handleReset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentImage = widget.initialImage;
      _originalSizeBytes = widget.initialImage.lengthSync();
      _threshold = 0.65;
      _targetSizeKB = 19;
      _quarterTurns = 0;
      _inkColor = SignatureInkColor.darkNavy;
      _showOriginal = false;
    });
    _triggerPreviewUpdate(debounce: false);
  }

  Future<void> _handlePopScope(bool didPop) async {
    if (didPop) return;
    final shouldDiscard = await DiscardChangesSheet.show(
      context,
      title: 'Discard Signature Edits?',
      message: 'You have customized signature enhancement settings. Are you sure you want to exit?',
    );
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleEnhance() async {
    setState(() => _isProcessing = true);

    try {
      final options = SignatureEnhanceOptions(
        sourcePath: _currentImage.path,
        threshold: _threshold,
        targetSizeKB: _targetSizeKB,
        targetWidth: 400,
        targetHeight: 200,
        quarterTurns: _quarterTurns,
        inkColor: _inkColor,
      );

      final result = await SignatureEnhancer.enhanceSignature(options);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cleaning signature: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) => _handlePopScope(didPop),
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () async {
              if (_hasChanges) {
                await _handlePopScope(false);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: const Text('Signature B&W Cleaner'),
          actions: [
            if (_hasChanges)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Reset to Defaults',
                onPressed: _handleReset,
              ),
          ],
        ),
        body: SafeArea(
          child: AdaptiveSupportingPane(
            stretchPrimaryPane: false,
            primaryFlex: 6,
            supportingFlex: 5,
            primaryPane: _buildPreviewCard(isDark, isWide: isWide),
            supportingPane: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildExplanationBanner(isDark),
                const SizedBox(height: 16),
                _buildThresholdSection(isDark),
                const SizedBox(height: 16),
                _buildInkToneSection(isDark),
                const SizedBox(height: 16),
                _buildTargetSizeSection(isDark),
                const SizedBox(height: 8),
              ],
            ),
            bottomAction: _buildBottomActionBar(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(bool isDark, {bool isWide = false}) {
    final hasPreview = _previewImageFile != null && _previewImageFile!.existsSync();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: Mode Badge & Quick Toolbar (Rotate, Crop)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: _showOriginal
                        ? Colors.amber.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showOriginal
                          ? Colors.amber.withValues(alpha: 0.35)
                          : AppColors.primary.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOriginal ? Icons.image_outlined : Icons.auto_fix_high_rounded,
                        size: 13,
                        color: _showOriginal
                            ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showOriginal ? 'ORIGINAL SCAN' : 'CLEANED PREVIEW',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: _showOriginal
                              ? (isDark ? Colors.amber.shade300 : Colors.amber.shade900)
                              : AppColors.primary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Rotate Action Button
                IconButton(
                  icon: const Icon(Icons.rotate_right_rounded, size: 20),
                  tooltip: 'Rotate 90°',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  onPressed: _handleRotate,
                ),
                const SizedBox(width: 6),

                // Crop Action Button
                IconButton(
                  icon: const Icon(Icons.crop_rounded, size: 19),
                  tooltip: 'Crop Tightly',
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  ),
                  onPressed: _handleCrop,
                ),
              ],
            ),
          ),

          // Central Canvas Viewport
          Container(
            height: isWide ? 280 : 190,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white, // Signatures always preview on crisp pure white paper
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Display Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Center(
                    child: _showOriginal
                        ? RotatedBox(
                            quarterTurns: _quarterTurns,
                            child: Image.file(
                              _currentImage,
                              fit: BoxFit.contain,
                            ),
                          )
                        : (hasPreview
                            ? Image.file(
                                _previewImageFile!,
                                fit: BoxFit.contain,
                              )
                            : RotatedBox(
                                quarterTurns: _quarterTurns,
                                child: Image.file(
                                  _currentImage,
                                  fit: BoxFit.contain,
                                ),
                              )),
                  ),
                ),

                // Preview Generating Indicator
                if (_isGeneratingPreview && !_showOriginal)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Bottom Specifications & Compare Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Specs pill (Resolution + Estimated Size)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 15, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            _previewResult != null
                                ? 'Est: ${(_previewResult!.outputSizeBytes / 1024).toStringAsFixed(1)} KB'
                                : 'Target: < $_targetSizeKB KB',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (_previewResult != null && _originalSizeBytes > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF14532D).withValues(alpha: 0.5)
                                    : AppColors.successContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${_previewResult!.savedPercentage.toStringAsFixed(0)}% saved',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF4ADE80) : AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Original: ${_originalSizeBytes.toReadableFileSize()}  •  Output: 400 × 200 px',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Press & Hold to Compare Button
                GestureDetector(
                  onTapDown: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _showOriginal = true);
                  },
                  onTapUp: (_) {
                    setState(() => _showOriginal = false);
                  },
                  onTapCancel: () {
                    setState(() => _showOriginal = false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white12 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 15,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Hold Compare',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primaryContainerDark : AppColors.primaryContainerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Paper grain, yellowing, and shadows removed. Crisp ink on pure white background (Government Exam Ready).',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textPrimaryDark : AppColors.primaryDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Shadow Removal Strength',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${(_threshold * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Quick threshold presets
          Row(
            children: [
              _buildThresholdChip(label: 'Light (50%)', value: 0.50, isDark: isDark),
              const SizedBox(width: 8),
              _buildThresholdChip(label: 'Balanced (65%)', value: 0.65, isDark: isDark, isRecommended: true),
              const SizedBox(width: 8),
              _buildThresholdChip(label: 'Deep (80%)', value: 0.80, isDark: isDark),
            ],
          ),
          const SizedBox(height: 12),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
            ),
            child: Slider(
              value: _threshold,
              min: 0.30,
              max: 0.90,
              divisions: 12,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if ((val * 100).round() != (_threshold * 100).round()) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _threshold = val);
                _triggerPreviewUpdate();
              },
            ),
          ),
          Text(
            'Increase if your scanned photo has heavy background shadows or dark paper grain.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThresholdChip({
    required String label,
    required double value,
    required bool isDark,
    bool isRecommended = false,
  }) {
    final isSelected = (_threshold - value).abs() < 0.02;

    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary
            : (isDark ? AppColors.surfaceVariantDark : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _threshold = value);
            _triggerPreviewUpdate(debounce: false);
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  ),
                ),
                if (isRecommended && !isSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Default',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.primary,
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

  Widget _buildInkToneSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
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
              const Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Ink Appearance',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Preserves natural ink color or converts to official monochrome tones.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              _buildInkChoice(
                label: 'Original',
                isOriginal: true,
                inkColor: SignatureInkColor.original,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildInkChoice(
                label: 'Deep Black',
                color: Colors.black,
                inkColor: SignatureInkColor.pureBlack,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInkChoice(
                label: 'Classic Navy',
                color: const Color(0xFF0F172A),
                inkColor: SignatureInkColor.darkNavy,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildInkChoice(
                label: 'Royal Blue',
                color: const Color(0xFF0E37A0),
                inkColor: SignatureInkColor.royalBlue,
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInkChoice({
    required String label,
    Color color = Colors.black,
    bool isOriginal = false,
    required SignatureInkColor inkColor,
    required bool isDark,
  }) {
    final isSelected = _inkColor == inkColor;

    return Expanded(
      child: Material(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.12)
            : (isDark ? AppColors.surfaceVariantDark : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _inkColor = inkColor);
            _triggerPreviewUpdate(debounce: false);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: isSelected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: isOriginal
                        ? const SweepGradient(
                            colors: [
                              Color(0xFFEF4444),
                              Color(0xFFF59E0B),
                              Color(0xFF10B981),
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                              Color(0xFFEF4444),
                            ],
                          )
                        : null,
                    color: isOriginal ? null : color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isOriginal ? Colors.grey.shade400 : Colors.grey.shade400,
                      width: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
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

  Widget _buildTargetSizeSection(bool isDark) {
    const sizeOptions = [
      (size: 19, label: '< 20 KB (SSC/UPSC)'),
      (size: 50, label: '< 50 KB (IBPS/Bank)'),
      (size: 10, label: '< 10 KB (State PSC)'),
      (size: 30, label: '< 30 KB'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
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
              const Icon(Icons.compress_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Target File Size',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Strictly compressed to fit government & job exam application portals.',
            style: TextStyle(
              fontSize: 11.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: sizeOptions.map((opt) {
              final isSelected = _targetSizeKB == opt.size;
              return ChoiceChip(
                label: Text(opt.label),
                selected: isSelected,
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                shape: const StadiumBorder(),
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (sel) {
                  if (sel) {
                    HapticFeedback.selectionClick();
                    setState(() => _targetSizeKB = opt.size);
                    _triggerPreviewUpdate();
                  }
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: GradientButton(
        text: _isProcessing ? 'Enhancing Signature...' : '✍️ Save Clean Signature',
        isLoading: _isProcessing,
        onPressed: _isProcessing ? null : _handleEnhance,
      ),
    );
  }
}
