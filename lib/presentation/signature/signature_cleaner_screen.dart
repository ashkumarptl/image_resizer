import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_result.dart';
import '../../data/repositories/tool_guide_repository.dart';
import '../../services/image_service/safe_image_decoder.dart';
import '../../services/image_service/signature_enhancer.dart';
import 'signature_cropper_helper.dart';
import 'widgets/signature_studio_bottom_toolbar.dart';
import 'widgets/signature_studio_contextual_dock.dart';
import '../result/result_screen.dart';
import '../studio/widgets/studio_info_card.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/hold_to_compare_button.dart';
import '../widgets/image_source_picker_sheet.dart';
import '../widgets/tool_instruction_sheet.dart';

class SignatureCleanerScreen extends StatefulWidget {
  final File initialImage;

  const SignatureCleanerScreen({super.key, required this.initialImage});

  @override
  State<SignatureCleanerScreen> createState() => _SignatureCleanerScreenState();
}

class _SignatureCleanerScreenState extends State<SignatureCleanerScreen> {
  late File _currentImage;
  late int _originalSizeBytes;
  int _originalWidth = 0;
  int _originalHeight = 0;

  // Active Studio Tool
  SignatureStudioTool _activeTool = SignatureStudioTool.clean;

  // Processing & Adjustment state
  double _threshold = 0.0;
  int _targetSizeKB = 19;
  late TextEditingController _sizeController;
  SignatureInkColor _inkColor = SignatureInkColor.darkNavy;
  int? _targetWidth = 400;
  int? _targetHeight = 200;
  int _quarterTurns = 0;
  bool _hasCropped = false;

  // Interactive Viewer & Zoom state
  late TransformationController _transformationController;
  bool _isZoomedIn = false;

  // Live preview state
  Timer? _debounceTimer;
  int _previewRequestId = 0;
  bool _isGeneratingPreview = false;
  ProcessResult? _previewResult;
  File? _previewImageFile;
  bool _showOriginal = false;
  bool _isProcessing = false;

  bool get _hasChanges =>
      _currentImage.path != widget.initialImage.path ||
      _threshold != 0.0 ||
      _targetSizeKB != 19 ||
      _inkColor != SignatureInkColor.darkNavy ||
      _quarterTurns != 0 ||
      _hasCropped ||
      _targetWidth != 400 ||
      _targetHeight != 200;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);
    _sizeController = TextEditingController(text: '$_targetSizeKB');

    _currentImage = widget.initialImage;
    _originalSizeBytes = _currentImage.lengthSync();
    _loadImageMetadata();
    _triggerPreviewUpdate(debounce: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToolInstructionSheet.show(context, ToolGuideType.signatureCleaner);
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _sizeController.dispose();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = (scale - 1.0).abs() > 0.05;
    if (isZoomed != _isZoomedIn && mounted) {
      setState(() => _isZoomedIn = isZoomed);
    }
  }

  void _resetZoom() {
    HapticFeedback.selectionClick();
    _transformationController.value = Matrix4.identity();
  }

  void _handleDoubleTap() {
    if (_isZoomedIn) {
      _resetZoom();
    } else {
      HapticFeedback.selectionClick();
      _transformationController.value = Matrix4.diagonal3Values(2.2, 2.2, 1.0);
    }
  }

  Future<void> _loadImageMetadata() async {
    try {
      final bytes = await _currentImage.readAsBytes();
      final decoded = await SafeImageDecoder.decodeSafe(
        bytes,
        maxDimension: 1200,
      );
      if (decoded != null && mounted) {
        setState(() {
          _originalWidth = decoded.width;
          _originalHeight = decoded.height;
        });
      }
    } catch (_) {}
  }

  void _triggerPreviewUpdate({bool debounce = true}) {
    _debounceTimer?.cancel();
    if (debounce) {
      _debounceTimer = Timer(
        const Duration(milliseconds: 180),
        _generatePreview,
      );
    } else {
      _generatePreview();
    }
  }

  Future<void> _handleCropArea() async {
    final cropped = await SignatureCropperHelper.cropSignature(_currentImage);
    if (cropped != null && mounted) {
      setState(() {
        _currentImage = cropped;
        _originalSizeBytes = cropped.lengthSync();
        _hasCropped = true;
      });
      _loadImageMetadata();
      _triggerPreviewUpdate(debounce: false);
    }
  }

  void _handleRotate() {
    HapticFeedback.selectionClick();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      // Swap width and height display if rotated
      if (_originalWidth > 0 && _originalHeight > 0) {
        final temp = _originalWidth;
        _originalWidth = _originalHeight;
        _originalHeight = temp;
      }
    });
    _triggerPreviewUpdate(debounce: false);
  }

  Future<void> _handleRePickImage() async {
    final picked = await ImageSourcePickerSheet.show(
      context,
      title: 'Change Signature Photo',
    );
    if (picked != null && mounted) {
      setState(() {
        _currentImage = picked;
        _originalSizeBytes = picked.lengthSync();
        _hasCropped = false;
        _quarterTurns = 0;
        _showOriginal = false;
      });
      _resetZoom();
      _loadImageMetadata();
      _triggerPreviewUpdate(debounce: false);
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
        targetWidth: _targetWidth,
        targetHeight: _targetHeight,
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

  void _handleReset() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentImage = widget.initialImage;
      _originalSizeBytes = widget.initialImage.lengthSync();
      _threshold = 0.0;
      _targetSizeKB = 19;
      _sizeController.text = '19';
      _inkColor = SignatureInkColor.darkNavy;
      _targetWidth = 400;
      _targetHeight = 200;
      _quarterTurns = 0;
      _hasCropped = false;
      _showOriginal = false;
      _activeTool = SignatureStudioTool.clean;
    });
    _resetZoom();
    _loadImageMetadata();
    _triggerPreviewUpdate(debounce: false);
  }

  Future<void> _handlePopScope(bool didPop) async {
    if (didPop) return;
    final shouldDiscard = await DiscardChangesSheet.show(
      context,
      title: 'Discard Signature Edits?',
      message:
          'You have customized signature enhancement settings. Are you sure you want to exit?',
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
        targetWidth: _targetWidth,
        targetHeight: _targetHeight,
        quarterTurns: _quarterTurns,
        inkColor: _inkColor,
      );

      final result = await SignatureEnhancer.enhanceSignature(options);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => ResultScreen(result: result)));
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
    final isTablet = context.isMediumOrWider;
    final appBarBg = isDark ? AppColors.surfaceDark : Colors.white;
    final appBarFg = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;

    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) => _handlePopScope(didPop),
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFF6F8FB),
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: appBarFg,
          elevation: 0,
          titleSpacing: 4,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          leading: BackButton(
            color: appBarFg,
            onPressed: () async {
              if (_hasChanges) {
                await _handlePopScope(false);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: Text(
            'Signature Studio',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (Theme.of(context).appBarTheme.titleTextStyle ??
                        const TextStyle())
                    .copyWith(
                      color: appBarFg,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
          ),
          actions: [
            // Standard Crop Signature Area button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              icon: const Icon(Icons.crop_free_rounded, size: 21),
              tooltip: 'Crop Signature Area',
              color: appBarFg,
              onPressed: _handleCropArea,
            ),
            // Rotate button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              icon: const Icon(Icons.rotate_90_degrees_cw_outlined, size: 21),
              tooltip: 'Rotate',
              color: appBarFg,
              onPressed: _handleRotate,
            ),
            // Reset Adjustments
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              icon: const Icon(Icons.refresh_rounded, size: 21),
              tooltip: 'Reset Adjustments',
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              onPressed: (_isProcessing || !_hasChanges) ? null : _handleReset,
            ),
            // Re-pick image
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              icon: const Icon(Icons.photo_library_outlined, size: 20),
              tooltip: 'Change Image',
              color: appBarFg,
              onPressed: _isProcessing ? null : _handleRePickImage,
            ),
            // Guide / Help
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 40),
              icon: const Icon(Icons.help_outline_rounded, size: 21),
              tooltip: 'How to use Signature Studio',
              color: appBarFg,
              onPressed: () {
                ToolInstructionSheet.show(
                  context,
                  ToolGuideType.signatureCleaner,
                  isManualTrigger: true,
                );
              },
            ),
            // Primary Save Action Checkmark
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 2),
              child: _isProcessing
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : IconButton.filled(
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      tooltip: 'Save Clean Signature',
                      onPressed: _handleEnhance,
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top File & Output Info HUD
              RepaintBoundary(
                child: StudioInfoCard(
                  filePath: _currentImage.path,
                  width: _originalWidth > 0 ? _originalWidth : 400,
                  height: _originalHeight > 0 ? _originalHeight : 200,
                  fileSizeBytes: _originalSizeBytes,
                  targetSummary: 'Gov Exam: < $_targetSizeKB KB',
                  estimatedSizeBytes: (!_showOriginal && _previewResult != null)
                      ? _previewResult!.outputSizeBytes
                      : null,
                  outputWidth: (!_showOriginal && _previewResult != null)
                      ? _previewResult!.outputWidth
                      : (_targetWidth ?? 400),
                  outputHeight: (!_showOriginal && _previewResult != null)
                      ? _previewResult!.outputHeight
                      : (_targetHeight ?? 200),
                  outputFormat: 'JPG',
                  isCalculating: _isGeneratingPreview,
                  isDark: isDark,
                ),
              ),

              // 2. Large Central Viewport (Dominant Canvas - Maximized Height)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 4,
                  ),
                  child: _buildImagePreviewCanvas(isDark, isTablet: isTablet),
                ),
              ),

              // 3. Contextual Tool Controls Dock (Docked directly above bottom toolbar)
              SignatureStudioContextualDock(
                activeTool: _activeTool,
                threshold: _threshold,
                onThresholdChanged: (val) {
                  setState(() => _threshold = val);
                  _triggerPreviewUpdate();
                },
                inkColor: _inkColor,
                onInkColorChanged: (color) {
                  setState(() => _inkColor = color);
                  _triggerPreviewUpdate();
                },
                targetSizeKB: _targetSizeKB,
                sizeController: _sizeController,
                onTargetSizeKBChanged: (val) {
                  setState(() {
                    _targetSizeKB = val;
                    _sizeController.text = '$val';
                  });
                  _triggerPreviewUpdate();
                },
                targetWidth: _targetWidth,
                targetHeight: _targetHeight,
                onDimensionsChanged: (w, h) {
                  setState(() {
                    _targetWidth = w;
                    _targetHeight = h;
                  });
                  _triggerPreviewUpdate();
                },
                isDark: isDark,
              ),

              const SizedBox(height: 4),
            ],
          ),
        ),
        bottomNavigationBar: SignatureStudioBottomToolbar(
          activeTool: _activeTool,
          onToolSelected: (tool) {
            HapticFeedback.selectionClick();
            setState(() => _activeTool = tool);
          },
          isDark: isDark,
        ),
      ),
    );
  }

  // --- Dominant Canvas ---
  Widget _buildImagePreviewCanvas(bool isDark, {bool isTablet = false}) {
    final hasPreview =
        _previewImageFile != null && _previewImageFile!.existsSync();

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white, // Signatures preview on pure white paper
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.borderDark : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black38
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle background paper texture/tint
              Positioned.fill(
                child: Container(
                  color: _showOriginal
                      ? (isDark
                            ? const Color(0xFF1E222B)
                            : const Color(0xFFF3F4F6))
                      : Colors.white,
                ),
              ),

              // Live preview generating linear progress bar at the top
              if (_isGeneratingPreview && !_showOriginal)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),

              // Zoomable & Transformed Signature Canvas
              GestureDetector(
                onDoubleTap: _handleDoubleTap,
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 0.8,
                  maxScale: 5.0,
                  clipBehavior: Clip.none,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: _showOriginal
                          ? Image.file(
                              _currentImage,
                              fit: BoxFit.contain,
                              cacheWidth: 900,
                            )
                          : (hasPreview
                                ? Image.file(
                                    _previewImageFile!,
                                    fit: BoxFit.contain,
                                    cacheWidth: 900,
                                  )
                                : Image.file(
                                    _currentImage,
                                    fit: BoxFit.contain,
                                    cacheWidth: 900,
                                  )),
                    ),
                  ),
                ),
              ),

              // Top-left: Zoom instruction badge or Reset Zoom button
              Positioned(
                top: 10,
                left: 10,
                child: _isZoomedIn
                    ? Material(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: _resetZoom,
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(
                                  Icons.zoom_out_map_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Reset Zoom',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(
                              Icons.pinch_rounded,
                              size: 12,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pinch to Zoom',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Top-right: Status Mode Badge (CLEANED PREVIEW vs ORIGINAL SCAN)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: _showOriginal
                        ? Colors.amber.withValues(alpha: 0.9)
                        : AppColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showOriginal
                            ? Icons.image_outlined
                            : Icons.auto_fix_high_rounded,
                        size: 12,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showOriginal ? 'ORIGINAL SCAN' : 'CLEANED PREVIEW',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom-right: Hold to Compare Button
              Positioned(
                bottom: 10,
                right: 10,
                child: HoldToCompareButton(
                  isComparing: _showOriginal,
                  onComparisonChanged: (active) {
                    setState(() => _showOriginal = active);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
