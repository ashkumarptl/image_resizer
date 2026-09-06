import 'dart:async';
import 'dart:io' hide ProcessResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/processing_progress_modal.dart';
import 'widgets/compress_options_sheet.dart';
import 'widgets/flip_options_sheet.dart';
import 'widgets/format_options_sheet.dart';
import 'widgets/resize_options_sheet.dart';
import 'widgets/studio_bottom_toolbar.dart';
import 'widgets/studio_info_card.dart';

class ImageStudioScreen extends StatefulWidget {
  final File initialImage;
  final StudioActiveTool initialTool;

  const ImageStudioScreen({
    super.key,
    required this.initialImage,
    this.initialTool = StudioActiveTool.compress,
  });

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  late File _currentImage;
  int _originalWidth = 0;
  int _originalHeight = 0;
  int _fileSizeBytes = 0;
  bool _isLoadingInfo = true;
  bool _isProcessing = false;

  // 1. Orientation & Transform State
  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // 2. Crop State
  bool _hasCropped = false;

  // 3. Resize State
  ResizeSheetOption _resizeOption = ResizeSheetOption.none;
  int _targetWidth = 0;
  int _targetHeight = 0;
  int _selectedPercentage = 50;
  bool _keepAspectRatio = true;

  // 4. Compress & Quality State
  CompressionSheetMode _compressionMode = CompressionSheetMode.targetSize;
  int _selectedTargetSizeKB = 50;
  double _quality = 85;

  // 5. Format State
  String _outputFormat = 'jpg';

  // 6. Active Tool in Toolbar
  late StudioActiveTool _activeTool;

  // 7. Interactive Viewer & Zoom State
  late TransformationController _transformationController;
  bool _isZoomedIn = false;

  // 8. Live Preview & Toggle Original State
  bool _showOriginal = false;
  File? _previewImageFile;
  ProcessResult? _previewResult;
  bool _isGeneratingPreview = false;
  int _previewRequestId = 0;
  Timer? _previewDebounceTimer;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    _currentImage = widget.initialImage;
    _fileSizeBytes = _currentImage.lengthSync();
    _activeTool = widget.initialTool;

    // Auto-detect format from file extension
    final ext = p.extension(_currentImage.path).replaceAll('.', '').toLowerCase();
    if (ext == 'png' || ext == 'webp') {
      _outputFormat = ext;
    } else {
      _outputFormat = 'jpg';
    }

    _loadImageMetadata();
  }

  @override
  void dispose() {
    _previewDebounceTimer?.cancel();
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  void _triggerPreviewUpdate({bool debounce = true}) {
    _previewDebounceTimer?.cancel();
    if (debounce) {
      _previewDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _generatePreview();
      });
    } else {
      _generatePreview();
    }
  }

  Future<void> _generatePreview() async {
    if (!mounted) return;
    final requestId = ++_previewRequestId;

    setState(() => _isGeneratingPreview = true);

    try {
      final options = ProcessOptions(
        sourcePath: _currentImage.path,
        targetSizeKB: _compressionMode == CompressionSheetMode.targetSize
            ? _selectedTargetSizeKB
            : null,
        quality: _quality.round(),
        outputFormat: _outputFormat,
        resizeMode: _getResizeMode(),
        targetWidth: _resizeOption == ResizeSheetOption.exactPixels ? _targetWidth : null,
        targetHeight: _resizeOption == ResizeSheetOption.exactPixels ? _targetHeight : null,
        resizePercentage: _resizeOption == ResizeSheetOption.percentage
            ? _selectedPercentage
            : null,
        keepAspectRatio: _keepAspectRatio,
        quarterTurns: _quarterTurns,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      );

      final result = await ImageProcessor.processImage(options);
      if (!mounted || requestId != _previewRequestId) return;

      setState(() {
        _previewResult = result;
        _previewImageFile = File(result.outputPath);
        _isGeneratingPreview = false;
      });
    } catch (e, stack) {
      if (!mounted || requestId != _previewRequestId) return;
      setState(() => _isGeneratingPreview = false);
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Failed to generate live preview in ImageStudioScreen',
      );
    }
  }

  void _onTransformationChanged() {
    final isZoomed = !_transformationController.value.isIdentity();
    if (isZoomed != _isZoomedIn) {
      setState(() => _isZoomedIn = isZoomed);
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_isZoomedIn) {
        _transformationController.value = Matrix4.identity();
      } else {
        _transformationController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      }
    });
  }

  void _resetZoom() {
    HapticFeedback.lightImpact();
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  Future<void> _loadImageMetadata() async {
    try {
      final dims = await ImageProcessor.readImageDimensions(_currentImage.path);
      if (dims != null) {
        if (mounted) {
          setState(() {
            _originalWidth = dims.width;
            _originalHeight = dims.height;
            _targetWidth = (_originalWidth * 0.5).round();
            _targetHeight = (_originalHeight * 0.5).round();
            _isLoadingInfo = false;
          });
          _triggerPreviewUpdate(debounce: false);
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingInfo = false);
          _triggerPreviewUpdate(debounce: false);
        }
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Failed to read image metadata in ImageStudioScreen',
      );
      if (mounted) {
        setState(() => _isLoadingInfo = false);
      }
    }
  }

  Future<void> _handleRePickImage() async {
    setState(() => _activeTool = StudioActiveTool.none);
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked != null && mounted) {
      setState(() {
        _currentImage = File(picked.path);
        _fileSizeBytes = _currentImage.lengthSync();
        _hasCropped = false;
        _quarterTurns = 0;
        _flipHorizontal = false;
        _flipVertical = false;
        _isLoadingInfo = true;
      });
      await _loadImageMetadata();
    }
  }

  Future<void> _handleCrop() async {
    setState(() => _activeTool = StudioActiveTool.crop);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentImage.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop & Frame',
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
            title: 'Crop & Frame',
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

      if (cropped != null && mounted) {
        final croppedFile = File(cropped.path);
        setState(() {
          _currentImage = croppedFile;
          _fileSizeBytes = croppedFile.lengthSync();
          _hasCropped = true;
          _quarterTurns = 0;
          _flipHorizontal = false;
          _flipVertical = false;
          _showOriginal = false;
          _previewImageFile = null;
          _previewResult = null;
          _isLoadingInfo = true;
        });
        await _loadImageMetadata();
      }
    } catch (e) {
      debugPrint('Image Cropper error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open crop tool: $e')),
        );
      }
    }
  }

  void _handleRotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _activeTool = StudioActiveTool.rotate;
      _quarterTurns = (_quarterTurns + 1) % 4;
      _showOriginal = false;
      _previewImageFile = null;
    });
    _triggerPreviewUpdate(debounce: false);
  }

  void _handleFlip() {
    setState(() => _activeTool = StudioActiveTool.flip);
    FlipOptionsSheet.show(
      context,
      initialFlipHorizontal: _flipHorizontal,
      initialFlipVertical: _flipVertical,
      onApply: (flipH, flipV) {
        setState(() {
          _flipHorizontal = flipH;
          _flipVertical = flipV;
          _showOriginal = false;
          _previewImageFile = null;
        });
        _triggerPreviewUpdate(debounce: false);
      },
    );
  }

  void _openCompressSheet() {
    setState(() => _activeTool = StudioActiveTool.compress);
    CompressOptionsSheet.show(
      context,
      initialMode: _compressionMode,
      initialTargetSizeKB: _selectedTargetSizeKB,
      initialQuality: _quality,
      originalSizeBytes: _fileSizeBytes,
      onApply: (mode, targetKB, quality) {
        setState(() {
          _compressionMode = mode;
          _selectedTargetSizeKB = targetKB;
          _quality = quality;
          _showOriginal = false;
        });
        _triggerPreviewUpdate(debounce: false);
      },
    );
  }

  void _handleCompressToolbar() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_activeTool == StudioActiveTool.compress) {
        _activeTool = StudioActiveTool.none;
      } else {
        _activeTool = StudioActiveTool.compress;
      }
    });
  }

  void _handleResize() {
    setState(() => _activeTool = StudioActiveTool.resize);
    ResizeOptionsSheet.show(
      context,
      initialOption: _resizeOption,
      originalWidth: _originalWidth,
      originalHeight: _originalHeight,
      originalSizeBytes: _fileSizeBytes,
      initialTargetWidth: _targetWidth,
      initialTargetHeight: _targetHeight,
      initialPercentage: _selectedPercentage,
      initialKeepAspectRatio: _keepAspectRatio,
      onApply: ({
        required option,
        required targetWidth,
        required targetHeight,
        required percentage,
        required keepAspectRatio,
      }) {
        setState(() {
          _resizeOption = option;
          _targetWidth = targetWidth;
          _targetHeight = targetHeight;
          _selectedPercentage = percentage;
          _keepAspectRatio = keepAspectRatio;
          _showOriginal = false;
        });
        _triggerPreviewUpdate(debounce: false);
      },
    );
  }

  void _handleFormat() {
    setState(() => _activeTool = StudioActiveTool.format);
    FormatOptionsSheet.show(
      context,
      initialFormat: _outputFormat,
      initialQuality: _quality,
      onApply: (format, quality) {
        setState(() {
          _outputFormat = format;
          _quality = quality;
          _showOriginal = false;
        });
        _triggerPreviewUpdate(debounce: false);
      },
    );
  }

  void _resetAllAdjustments() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = 0;
      _flipHorizontal = false;
      _flipVertical = false;
      _resizeOption = ResizeSheetOption.none;
      _compressionMode = CompressionSheetMode.targetSize;
      _selectedTargetSizeKB = 50;
      _quality = 85;
      _showOriginal = false;
      _previewImageFile = null;
      _previewResult = null;
    });
    _triggerPreviewUpdate(debounce: false);
  }

  ResizeMode _getResizeMode() {
    switch (_resizeOption) {
      case ResizeSheetOption.exactPixels:
        return ResizeMode.exactPixels;
      case ResizeSheetOption.percentage:
        return ResizeMode.percentage;
      case ResizeSheetOption.none:
        return ResizeMode.none;
    }
  }

  String _getTargetSummary() {
    String compressStr;
    switch (_compressionMode) {
      case CompressionSheetMode.targetSize:
        compressStr = 'Target: < $_selectedTargetSizeKB KB';
        break;
      case CompressionSheetMode.quality:
        compressStr = '${_quality.round()}% Quality';
        break;
      case CompressionSheetMode.none:
        compressStr = 'Original Quality';
        break;
    }

    String resizeStr = '';
    if (_resizeOption == ResizeSheetOption.exactPixels && _targetWidth > 0 && _targetHeight > 0) {
      resizeStr = '$_targetWidth×$_targetHeight px • ';
    } else if (_resizeOption == ResizeSheetOption.percentage) {
      resizeStr = '$_selectedPercentage% scale • ';
    }

    String previewEstStr = '';
    if (_previewResult != null && !_showOriginal) {
      final kb = (_previewResult!.outputSizeBytes / 1024).toStringAsFixed(1);
      previewEstStr = 'Est: $kb KB • ';
    }

    return '$previewEstStr$resizeStr$compressStr • ${_outputFormat.toUpperCase()}';
  }

  String _getTargetGoal() {
    switch (_compressionMode) {
      case CompressionSheetMode.targetSize:
        return 'Target: < $_selectedTargetSizeKB KB';
      case CompressionSheetMode.quality:
        return '${_quality.round()}% Quality';
      case CompressionSheetMode.none:
        return 'Original Quality';
    }
  }

  Future<void> _processImage() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final progressNotifier = ValueNotifier<ProcessingProgressState>(
      const ProcessingProgressState(
        progress: 0.05,
        stage: 'Starting background isolate...',
      ),
    );

    ProcessingProgressModal.show(
      context: context,
      progressNotifier: progressNotifier,
      title: 'Processing High-Res Image',
    );

    try {
      final options = ProcessOptions(
        sourcePath: _currentImage.path,
        targetSizeKB: _compressionMode == CompressionSheetMode.targetSize
            ? _selectedTargetSizeKB
            : null,
        quality: _quality.round(),
        outputFormat: _outputFormat,
        resizeMode: _getResizeMode(),
        targetWidth: _resizeOption == ResizeSheetOption.exactPixels ? _targetWidth : null,
        targetHeight: _resizeOption == ResizeSheetOption.exactPixels ? _targetHeight : null,
        resizePercentage: _resizeOption == ResizeSheetOption.percentage
            ? _selectedPercentage
            : null,
        keepAspectRatio: _keepAspectRatio,
        quarterTurns: _quarterTurns,
        flipHorizontal: _flipHorizontal,
        flipVertical: _flipVertical,
      );

      await CrashlyticsService.setProcessingContext(
        operation: 'ImageStudio_PreviewFirst',
        inputWidth: _originalWidth,
        inputHeight: _originalHeight,
        inputSizeKb: (_fileSizeBytes / 1024).round(),
        outputFormat: options.outputFormat,
      );

      final result = await ImageProcessor.processImage(
        options,
        onProgress: (progress, stage) {
          progressNotifier.value = ProcessingProgressState(
            progress: progress,
            stage: stage,
            isCompleted: progress >= 1.0,
          );
        },
      );

      progressNotifier.value = const ProcessingProgressState(
        progress: 1.0,
        stage: 'Done! Opening result...',
        isCompleted: true,
      );

      AnalyticsService.logCompressionUsed(
        targetQuality: result.finalQuality,
        originalSizeKb: (_fileSizeBytes / 1024).round(),
        compressedSizeKb: (result.outputSizeBytes / 1024).round(),
      );

      await CrashlyticsService.clearProcessingContext();

      // Give brief visual feedback of 100% completion before screen transition
      await Future.delayed(const Duration(milliseconds: 150));

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'ImageStudio processing error');

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  bool get _hasUnsavedChanges {
    return _quarterTurns != 0 ||
        _flipHorizontal ||
        _flipVertical ||
        _hasCropped ||
        _resizeOption != ResizeSheetOption.none ||
        _compressionMode != CompressionSheetMode.targetSize ||
        _selectedTargetSizeKB != 50 ||
        _quality != 85 ||
        _outputFormat != 'jpg';
  }

  Future<void> _handlePopScope(bool didPop) async {
    if (didPop) return;
    final shouldDiscard = await DiscardChangesSheet.show(context);
    if (shouldDiscard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;
    final appBarBg = isDark ? AppColors.surfaceDark : AppColors.primary;
    const appBarFg = Colors.white;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) => _handlePopScope(didPop),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF6F8FB),
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: appBarFg,
          iconTheme: const IconThemeData(color: appBarFg),
          actionsIconTheme: const IconThemeData(color: appBarFg),
          systemOverlayStyle: SystemUiOverlayStyle.light,
          elevation: 0,
          titleSpacing: 4,
          leading: BackButton(
            color: appBarFg,
            onPressed: () async {
              if (_hasUnsavedChanges) {
                await _handlePopScope(false);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Compress & Resize',
              style: (Theme.of(context).appBarTheme.titleTextStyle ?? const TextStyle()).copyWith(
                color: appBarFg,
                fontWeight: FontWeight.bold,
                fontSize: 19,
              ),
            ),
          ),
          actions: [
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: appBarFg,
              tooltip: 'Reset Adjustments',
              onPressed: _isProcessing ? null : _resetAllAdjustments,
            ),
            IconButton(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
              icon: const Icon(Icons.photo_library_outlined, size: 22),
              color: appBarFg,
              tooltip: 'Change Image',
              onPressed: _isProcessing ? null : _handleRePickImage,
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 2),
              child: _isProcessing
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(appBarFg),
                        ),
                      ),
                    )
                  : IconButton.filled(
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: isDark ? AppColors.primary : Colors.white,
                        foregroundColor: isDark ? Colors.white : AppColors.primary,
                      ),
                      icon: const Icon(Icons.check_rounded, size: 22),
                      tooltip: _compressionMode == CompressionSheetMode.targetSize
                          ? 'Compress to < $_selectedTargetSizeKB KB & Save'
                          : (_compressionMode == CompressionSheetMode.none
                              ? 'Save with Original Quality'
                              : 'Compress with ${_quality.round()}% Quality & Save'),
                      onPressed: _processImage,
                    ),
            ),
          ],
        ),
        body: SafeArea(
          child: _isLoadingInfo
              ? Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.photo_size_select_actual_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading High-Res Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Analyzing resolution in background isolate...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const SizedBox(
                            height: 6,
                            child: LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : isWide
                  ? _buildWideLayout(isDark)
                  : _buildMobileLayout(isDark),
        ),
        bottomNavigationBar: _isLoadingInfo
            ? null
            : StudioBottomToolbar(
                activeTool: _activeTool,
                hasRotated: _quarterTurns != 0,
                hasFlipped: _flipHorizontal || _flipVertical,
                hasCropped: _hasCropped,
                onRotate: _handleRotate,
                onFlip: _handleFlip,
                onCrop: _handleCrop,
                onCompress: _handleCompressToolbar,
                onCompressLongPress: _openCompressSheet,
                onResize: _handleResize,
                onFormat: _handleFormat,
              ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Column(
      children: [
        // 1. Top File Info Card
        StudioInfoCard(
          filePath: _currentImage.path,
          width: _originalWidth,
          height: _originalHeight,
          fileSizeBytes: _fileSizeBytes,
          targetSummary: _getTargetSummary(),
          estimatedSizeBytes: (!_showOriginal && _previewResult != null)
              ? _previewResult!.outputSizeBytes
              : null,
          outputWidth: (!_showOriginal && _previewResult != null && _previewResult!.outputWidth > 0)
              ? _previewResult!.outputWidth
              : null,
          outputHeight: (!_showOriginal && _previewResult != null && _previewResult!.outputHeight > 0)
              ? _previewResult!.outputHeight
              : null,
          outputFormat: _outputFormat,
          targetGoal: _getTargetGoal(),
          isCalculating: _isGeneratingPreview,
          isDark: isDark,
        ),

        // Quick KB Preset Chips (Fastest Workflow for Android users, shown only when Compress is active)
        if (_activeTool == StudioActiveTool.compress)
          _buildQuickKbPresetRow(isDark),

        // 2. Large Central Image Preview (Dominant Viewport)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildImagePreviewCanvas(isDark),
          ),
        ),

        // 3. Thumb-Zone Quick Controls Deck (Bottom 40% Area)
        _buildThumbQuickDeck(isDark),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildQuickKbPresetRow(bool isDark) {
    const presets = [20, 50, 100, 200];
    final isOriginalSelected = _compressionMode == CompressionSheetMode.none;
    final isCustomActive = _compressionMode == CompressionSheetMode.quality ||
        (_compressionMode == CompressionSheetMode.targetSize && !presets.contains(_selectedTargetSizeKB));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 0. Original Preset Chip
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: isOriginalSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(16),
                elevation: isOriginalSelected ? 2 : 0,
                shadowColor: AppColors.primary.withValues(alpha: 0.3),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _compressionMode = CompressionSheetMode.none;
                      _quality = 100;
                      _showOriginal = false;
                    });
                    _triggerPreviewUpdate(debounce: false);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isOriginalSelected
                            ? AppColors.primary
                            : (isDark ? AppColors.borderDark : AppColors.borderLight),
                        width: isOriginalSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 14,
                          color: isOriginalSelected ? Colors.white : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Original',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isOriginalSelected ? FontWeight.bold : FontWeight.w600,
                            color: isOriginalSelected
                                ? Colors.white
                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            ...presets.map((kb) {
              final isSelected = _compressionMode == CompressionSheetMode.targetSize &&
                  _selectedTargetSizeKB == kb;
              final isQuick = kb == 20 || kb == 50;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? AppColors.surfaceDark : Colors.white),
                  borderRadius: BorderRadius.circular(16),
                  elevation: isSelected ? 2 : 0,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _compressionMode = CompressionSheetMode.targetSize;
                        _selectedTargetSizeKB = kb;
                        _showOriginal = false;
                      });
                      _triggerPreviewUpdate(debounce: false);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isQuick) ...[
                            Icon(
                              Icons.bolt_rounded,
                              size: 14,
                              color: isSelected ? Colors.white : AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            '$kb KB',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Custom... Chip
            Material(
              color: isCustomActive
                  ? AppColors.primary
                  : (isDark ? AppColors.surfaceDark : Colors.white),
              borderRadius: BorderRadius.circular(16),
              elevation: isCustomActive ? 2 : 0,
              shadowColor: AppColors.primary.withValues(alpha: 0.3),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _openCompressSheet();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCustomActive
                          ? AppColors.primary
                          : (isDark ? AppColors.borderDark : AppColors.borderLight),
                      width: isCustomActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        size: 13,
                        color: isCustomActive
                            ? Colors.white
                            : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCustomActive
                            ? (_compressionMode == CompressionSheetMode.targetSize
                                ? '$_selectedTargetSizeKB KB'
                                : '${_quality.round()}%')
                            : 'Custom...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCustomActive ? FontWeight.bold : FontWeight.w600,
                          color: isCustomActive
                              ? Colors.white
                              : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbQuickDeck(bool isDark) {
    final hasChanges = _hasUnsavedChanges;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            // 1. Target KB Quick Pill
            _buildThumbChip(
              icon: Icons.compress_rounded,
              label: _compressionMode == CompressionSheetMode.targetSize
                  ? '< $_selectedTargetSizeKB KB'
                  : (_compressionMode == CompressionSheetMode.none
                      ? 'Original'
                      : '${_quality.round()}% Qual'),
              isActive: _activeTool == StudioActiveTool.compress,
              isDark: isDark,
              onTap: _openCompressSheet,
            ),
            const SizedBox(width: 8),

            // 2. Resize Dimensions Quick Pill
            _buildThumbChip(
              icon: Icons.open_in_full_rounded,
              label: _resizeOption == ResizeSheetOption.exactPixels
                  ? '$_targetWidth×$_targetHeight'
                  : _resizeOption == ResizeSheetOption.percentage
                      ? '$_selectedPercentage%'
                      : 'Original Size',
              isActive: _activeTool == StudioActiveTool.resize || _resizeOption != ResizeSheetOption.none,
              isDark: isDark,
              onTap: _handleResize,
            ),
            const SizedBox(width: 8),

            // 3. Format Quick Pill
            _buildThumbChip(
              icon: Icons.tune_rounded,
              label: _outputFormat.toUpperCase(),
              isActive: _activeTool == StudioActiveTool.format,
              isDark: isDark,
              onTap: _handleFormat,
            ),

            if (hasChanges) ...[
              const SizedBox(width: 8),
              // 4. Reset Adjustments Quick Pill (thumb-accessible)
              _buildThumbChip(
                icon: Icons.replay_rounded,
                label: 'Reset',
                isActive: false,
                isDark: isDark,
                accentColor: AppColors.warning,
                onTap: _resetAllAdjustments,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbChip({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    Color? accentColor,
    required VoidCallback onTap,
  }) {
    final activeColor = accentColor ?? AppColors.primary;
    return Material(
      color: isActive
          ? activeColor.withValues(alpha: 0.14)
          : (isDark ? AppColors.surfaceDark : Colors.white),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? activeColor
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isActive ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive
                    ? activeColor
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive
                      ? activeColor
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: Large Preview Canvas with Quick Presets Row
          Expanded(
            flex: 6,
            child: Column(
              children: [
                if (_activeTool == StudioActiveTool.compress) ...[
                  _buildQuickKbPresetRow(isDark),
                  const SizedBox(height: 6),
                ],
                Expanded(child: _buildImagePreviewCanvas(isDark)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Right: Info & Primary Controls Pane
          Expanded(
            flex: 4,
            child: Column(
              children: [
                StudioInfoCard(
                  filePath: _currentImage.path,
                  width: _originalWidth,
                  height: _originalHeight,
                  fileSizeBytes: _fileSizeBytes,
                  targetSummary: _getTargetSummary(),
                  estimatedSizeBytes: (!_showOriginal && _previewResult != null)
                      ? _previewResult!.outputSizeBytes
                      : null,
                  outputWidth: (!_showOriginal && _previewResult != null && _previewResult!.outputWidth > 0)
                      ? _previewResult!.outputWidth
                      : null,
                  outputHeight: (!_showOriginal && _previewResult != null && _previewResult!.outputHeight > 0)
                      ? _previewResult!.outputHeight
                      : null,
                  outputFormat: _outputFormat,
                  targetGoal: _getTargetGoal(),
                  isCalculating: _isGeneratingPreview,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCanvasImage() {
    if (_showOriginal) {
      return Image.file(
        _currentImage,
        key: const ValueKey('canvas_original_image'),
        fit: BoxFit.contain,
      );
    }

    if (_previewImageFile != null && _previewImageFile!.existsSync()) {
      return Image.file(
        _previewImageFile!,
        key: ValueKey(_previewImageFile!.path),
        fit: BoxFit.contain,
      );
    }

    return Transform.flip(
      flipX: _flipHorizontal,
      flipY: _flipVertical,
      child: RotatedBox(
        quarterTurns: _quarterTurns,
        child: Image.file(
          _currentImage,
          key: const ValueKey('canvas_fallback_image'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildImagePreviewCanvas(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E222B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : Colors.grey.shade200,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background subtle grid pattern / canvas
            Positioned.fill(
              child: Container(
                color: isDark ? Colors.black12 : const Color(0xFFFAFBFC),
              ),
            ),
            // Live preview rendering linear progress indicator
            if (_isGeneratingPreview)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SizedBox(
                  height: 3,
                  child: LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),
            // Zoomable & Transformed Image Preview with Double-Tap Support
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
                    child: _buildCanvasImage(),
                  ),
                ),
              ),
            ),
            // Top-left: Zoom instruction badge (at 1.0x) or Floating Reset Zoom Button (when zoomed in)
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
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_out_map_rounded, size: 14, color: Colors.white),
                              SizedBox(width: 4),
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
                  : IgnorePointer(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pinch_rounded, size: 12, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'Pinch or double-tap to inspect',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
            // Toggle Button Overlay (matching ResultScreen BeforeAfterCard)
            Positioned(
              bottom: 12,
              right: 12,
              child: Material(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  key: const ValueKey('studio_toggle_original_button'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _showOriginal = !_showOriginal;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showOriginal ? Icons.visibility : Icons.compare,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showOriginal ? 'Viewing Original' : 'Tap for Original',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Live preview updating indicator
            if (_isGeneratingPreview)
              Positioned(
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Updating preview...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Status overlay chips (Rotation or Flip indicator if active)
            if (_quarterTurns != 0 || _flipHorizontal || _flipVertical)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_quarterTurns != 0) ...[
                        const Icon(Icons.rotate_right, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${_quarterTurns * 90}°',
                          style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        if (_flipHorizontal || _flipVertical) const SizedBox(width: 8),
                      ],
                      if (_flipHorizontal) ...[
                        const Icon(Icons.swap_horiz, size: 14, color: Colors.white),
                        const SizedBox(width: 2),
                        const Text('Flip H', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                      if (_flipVertical) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.swap_vert, size: 14, color: Colors.white),
                        const SizedBox(width: 2),
                        const Text('Flip V', style: TextStyle(fontSize: 11, color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
