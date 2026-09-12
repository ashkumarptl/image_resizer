import 'dart:async';
import 'dart:io' hide ProcessResult;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_options.dart';
import '../../data/models/process_result.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/dpi_service.dart';
import '../../services/image_service/heic_converter.dart';
import '../../services/image_service/image_processor.dart';
import '../document_filter/document_filter_screen.dart';
import '../perspective_crop/perspective_crop_screen.dart';
import '../result/result_screen.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/gradient_button.dart';
import '../widgets/image_source_picker_sheet.dart';
import '../widgets/processing_progress_modal.dart';
import 'models/studio_history_state.dart';
import 'widgets/bg_remover_sheet.dart';
import 'widgets/compress_options_sheet.dart';
import 'widgets/flip_options_sheet.dart';
import 'widgets/format_options_sheet.dart';
import 'widgets/resize_options_sheet.dart';
import 'widgets/studio_bottom_toolbar.dart';
import 'widgets/studio_info_card.dart';

class ImageStudioScreen extends StatefulWidget {
  final File initialImage;
  final StudioActiveTool initialTool;
  final bool returnResultDirectly;
  final bool allowRePick;

  const ImageStudioScreen({
    super.key,
    required this.initialImage,
    this.initialTool = StudioActiveTool.none,
    this.returnResultDirectly = false,
    this.allowRePick = true,
  });

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  late File _currentImage;
  int _originalWidth = 0;
  int _originalHeight = 0;
  int _fileSizeBytes = 0;
  bool _isProcessing = false;

  // 1. Orientation & Transform State
  int _quarterTurns = 0;
  bool _flipHorizontal = false;
  bool _flipVertical = false;

  // 2. Crop & Cutout State
  bool _hasCropped = false;
  bool _hasRemovedBg = false;
  bool _hasAppliedFilter = false;

  // 3. Resize State
  ResizeSheetOption _resizeOption = ResizeSheetOption.none;
  int _targetWidth = 0;
  int _targetHeight = 0;
  int _selectedPercentage = 50;
  bool _keepAspectRatio = true;

  // 4. Compress & Quality State
  CompressionSheetMode _compressionMode = CompressionSheetMode.none;
  int _selectedTargetSizeKB = 50;
  double _quality = 85;

  // 5. Format & Resolution State
  String _outputFormat = 'jpg';
  int? _imageDpi;
  int? _targetDpi;

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

  // 9. Undo / Redo History Stack State
  final List<StudioHistoryState> _history = [];
  int _historyIndex = -1;

  bool get _canUndo => _historyIndex > 0;
  bool get _canRedo => _historyIndex >= 0 && _historyIndex < _history.length - 1;

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
        targetDpi: _targetDpi,
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

  StudioHistoryState _createCurrentSnapshot() {
    return StudioHistoryState(
      imageFile: _currentImage,
      originalWidth: _originalWidth,
      originalHeight: _originalHeight,
      fileSizeBytes: _fileSizeBytes,
      quarterTurns: _quarterTurns,
      flipHorizontal: _flipHorizontal,
      flipVertical: _flipVertical,
      hasCropped: _hasCropped,
      hasRemovedBg: _hasRemovedBg,
      resizeOption: _resizeOption,
      targetWidth: _targetWidth,
      targetHeight: _targetHeight,
      selectedPercentage: _selectedPercentage,
      keepAspectRatio: _keepAspectRatio,
      compressionMode: _compressionMode,
      selectedTargetSizeKB: _selectedTargetSizeKB,
      quality: _quality,
      outputFormat: _outputFormat,
      imageDpi: _imageDpi,
      targetDpi: _targetDpi,
    );
  }

  void _recordHistory() {
    final current = _createCurrentSnapshot();
    if (_history.isNotEmpty && _historyIndex >= 0 && _historyIndex < _history.length) {
      if (_history[_historyIndex].matches(current)) {
        return;
      }
    }

    if (_historyIndex >= 0 && _historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(current);
    if (_history.length > 30) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (!_canUndo) return;
    HapticFeedback.lightImpact();
    _historyIndex--;
    _applyHistoryState(_history[_historyIndex]);
  }

  void _redo() {
    if (!_canRedo) return;
    HapticFeedback.lightImpact();
    _historyIndex++;
    _applyHistoryState(_history[_historyIndex]);
  }

  void _applyHistoryState(StudioHistoryState state) {
    setState(() {
      _currentImage = state.imageFile;
      _originalWidth = state.originalWidth;
      _originalHeight = state.originalHeight;
      _fileSizeBytes = state.fileSizeBytes;
      _quarterTurns = state.quarterTurns;
      _flipHorizontal = state.flipHorizontal;
      _flipVertical = state.flipVertical;
      _hasCropped = state.hasCropped;
      _hasRemovedBg = state.hasRemovedBg;
      _resizeOption = state.resizeOption;
      _targetWidth = state.targetWidth;
      _targetHeight = state.targetHeight;
      _selectedPercentage = state.selectedPercentage;
      _keepAspectRatio = state.keepAspectRatio;
      _compressionMode = state.compressionMode;
      _selectedTargetSizeKB = state.selectedTargetSizeKB;
      _quality = state.quality;
      _outputFormat = state.outputFormat;
      _imageDpi = state.imageDpi;
      _targetDpi = state.targetDpi;
      _showOriginal = false;
      _previewImageFile = null;
      _previewResult = null;
    });

    _triggerPreviewUpdate(debounce: false);
  }

  Future<void> _loadImageMetadata() async {
    try {
      if (HeicConverter.isHeicFile(_currentImage.path)) {
        final converted = await HeicConverter.ensureCompatibleImage(_currentImage.path);
        if (mounted && converted != _currentImage.path) {
          _currentImage = File(converted);
        }
      }

      final dims = await ImageProcessor.readImageDimensions(_currentImage.path);
      int? detectedDpi;
      try {
        if (_currentImage.existsSync()) {
          final bytes = await _currentImage.readAsBytes();
          detectedDpi = DpiService.readDpi(bytes);
        }
      } catch (_) {}

      if (dims != null) {
        if (mounted) {
          setState(() {
            _originalWidth = dims.width;
            _originalHeight = dims.height;
            _targetWidth = (_originalWidth * 0.5).round();
            _targetHeight = (_originalHeight * 0.5).round();
            _fileSizeBytes = _currentImage.existsSync() ? _currentImage.lengthSync() : 0;
            _imageDpi = detectedDpi;
          });
          if (_hasUnsavedChanges) {
            _triggerPreviewUpdate(debounce: false);
          }
          if (_history.isEmpty) {
            _recordHistory();
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _imageDpi = detectedDpi;
          });
          if (_hasUnsavedChanges) {
            _triggerPreviewUpdate(debounce: false);
          }
          if (_history.isEmpty) {
            _recordHistory();
          }
        }
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Failed to read image metadata in ImageStudioScreen',
      );
    }
  }

  Future<void> _handleRePickImage() async {
    setState(() => _activeTool = StudioActiveTool.none);
    final pickedFile = await ImageSourcePickerSheet.show(
      context,
      title: 'Replace Current Photo',
    );
    if (pickedFile != null && mounted) {
      _history.clear();
      _historyIndex = -1;
      setState(() {
        _currentImage = pickedFile;
        _fileSizeBytes = _currentImage.lengthSync();
        _hasCropped = false;
        _hasRemovedBg = false;
        _quarterTurns = 0;
        _flipHorizontal = false;
        _flipVertical = false;
      });
      await _loadImageMetadata();
    }
  }

  Future<void> _handleCrop() async {
    setState(() => _activeTool = StudioActiveTool.crop);

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select Cropping Mode',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.crop_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Standard Crop & Frame', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Rectangular frame with fixed aspect ratio presets'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop('standard'),
                ),
                const Divider(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.transform_rounded, color: AppColors.secondary),
                  ),
                  title: const Text('Perspective Crop (4-Point Deskew)', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Drag 4 corners to straighten angled documents and ID cards'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(sheetContext).pop('perspective'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    if (choice == 'perspective') {
      await _handlePerspectiveCrop();
    } else if (choice == 'standard') {
      await _handleStandardCrop();
    }
  }



  Future<void> _handleDocumentFilter() async {
    final filteredFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => DocumentFilterScreen(
          initialImage: _currentImage,
          returnFilteredFile: true,
        ),
      ),
    );

    if (filteredFile != null && mounted) {
      setState(() {
        _currentImage = filteredFile;
        _fileSizeBytes = filteredFile.lengthSync();
        _hasAppliedFilter = true;
        _showOriginal = false;
        _previewImageFile = null;
        _previewResult = null;
      });
      await _loadImageMetadata();
      _recordHistory();
    }
  }

  Future<void> _handlePerspectiveCrop() async {
    final croppedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => PerspectiveCropScreen(
          initialImage: _currentImage,
          returnCroppedFile: true,
        ),
      ),
    );

    if (croppedFile != null && mounted) {
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
      });
      await _loadImageMetadata();
      _recordHistory();
    }
  }

  Future<void> _handleStandardCrop() async {
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
        });
        await _loadImageMetadata();
        _recordHistory();
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

  Future<void> _handleBgRemover() async {
    setState(() => _activeTool = StudioActiveTool.bgRemover);
    final result = await BgRemoverSheet.show(
      context,
      imageFile: _currentImage,
    );

    if (result != null && mounted) {
      setState(() {
        _currentImage = result.file;
        _fileSizeBytes = result.file.lengthSync();
        _hasRemovedBg = true;
        if (result.isTransparent) {
          _outputFormat = 'png';
        }
        _quarterTurns = 0;
        _flipHorizontal = false;
        _flipVertical = false;
        _showOriginal = false;
        _previewImageFile = null;
        _previewResult = null;
      });
      await _loadImageMetadata();
      _recordHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isTransparent
                  ? 'Background removed! Output set to PNG.'
                  : 'Background replaced successfully!',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
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
    _recordHistory();
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
        _recordHistory();
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
        _recordHistory();
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
        _recordHistory();
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
      initialDpi: _targetDpi ?? _imageDpi,
      onApply: (format, quality, dpi) {
        setState(() {
          _outputFormat = format;
          _quality = quality;
          _targetDpi = dpi;
          _showOriginal = false;
        });
        _recordHistory();
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
      _compressionMode = CompressionSheetMode.none;
      _selectedTargetSizeKB = 50;
      _quality = 85;
      _targetDpi = null;
      _showOriginal = false;
      _previewImageFile = null;
      _previewResult = null;
    });
    _recordHistory();
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

    final dpiStr = _targetDpi != null ? ' • $_targetDpi DPI' : '';
    return '$previewEstStr$resizeStr$compressStr • ${_outputFormat.toUpperCase()}$dpiStr';
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
        targetDpi: _targetDpi,
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

      if (widget.returnResultDirectly) {
        Navigator.of(context).pop(File(result.outputPath));
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ResultScreen(result: result),
          ),
        );
      }
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
    if (_history.isNotEmpty) {
      return !_history.first.matches(_createCurrentSnapshot());
    }
    return _quarterTurns != 0 ||
        _flipHorizontal ||
        _flipVertical ||
        _hasCropped ||
        _hasRemovedBg ||
        _hasAppliedFilter ||
        _resizeOption != ResizeSheetOption.none ||
        _compressionMode != CompressionSheetMode.none ||
        _quality != 85;
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
    final isTablet = context.isMediumOrWider;
    final isPortrait = context.isPortrait;
    final appBarBg = isDark ? AppColors.surfaceDark : Colors.white;
    final appBarFg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) => _handlePopScope(didPop),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF6F8FB),
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: appBarFg,
          iconTheme: IconThemeData(color: appBarFg),
          actionsIconTheme: IconThemeData(color: appBarFg),
          systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
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
              'Edit Studio',
              style: (Theme.of(context).appBarTheme.titleTextStyle ?? const TextStyle()).copyWith(
                color: appBarFg,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          actions: [
            IconButton(
              key: const ValueKey('studio_undo_button'),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              icon: const Icon(Icons.undo_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Undo',
              onPressed: (_isProcessing || !_canUndo) ? null : _undo,
            ),
            IconButton(
              key: const ValueKey('studio_redo_button'),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              icon: const Icon(Icons.redo_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Redo',
              onPressed: (_isProcessing || !_canRedo) ? null : _redo,
            ),
            IconButton(
              key: const ValueKey('studio_reset_button'),
              padding: const EdgeInsets.symmetric(horizontal: 2),
              constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Reset Adjustments',
              onPressed: (_isProcessing || !_hasUnsavedChanges) ? null : _resetAllAdjustments,
            ),
            if (widget.allowRePick)
              IconButton(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
                icon: const Icon(Icons.photo_library_outlined, size: 21),
                color: appBarFg,
                tooltip: 'Change Image',
                onPressed: _isProcessing ? null : _handleRePickImage,
              ),
            Padding(
              padding: const EdgeInsets.only(right: 10, left: 4),
              child: _isProcessing
                  ? Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    )
                  : IconButton.filled(
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      style: IconButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
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
          child: isTablet
              ? (isPortrait
                  ? _buildTabletPortraitLayout(isDark)
                  : _buildTabletLandscapeLayout(isDark))
              : _buildMobileLayout(isDark),
        ),
        bottomNavigationBar: (isTablet && isPortrait)
            ? null
            : StudioBottomToolbar(
                activeTool: _activeTool,
                hasRotated: _quarterTurns != 0,
                hasFlipped: _flipHorizontal || _flipVertical,
                hasCropped: _hasCropped,
                hasRemovedBg: _hasRemovedBg,
                hasAppliedFilter: _hasAppliedFilter,
                onRotate: _handleRotate,
                onFlip: _handleFlip,
                onCrop: _handleCrop,
                onDocFilter: _handleDocumentFilter,
                onBgRemover: _handleBgRemover,
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
        // 1. Top File Info HUD
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
          dpi: _imageDpi,
          targetDpi: _targetDpi,
        ),

        // 2. Large Central Image Preview (Dominant Viewport - Maximized Height)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _buildImagePreviewCanvas(isDark),
          ),
        ),

        // 3. Contextual Quick KB Presets (Docked directly above bottom toolbar when Compress is active)
        if (_activeTool == StudioActiveTool.compress)
          _buildQuickKbPresetRow(isDark),

        const SizedBox(height: 4),
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
                      _quality = 85;
                      _showOriginal = false;
                    });
                    _recordHistory();
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
                      _recordHistory();
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


  Widget _buildTabletPortraitLayout(bool isDark) {
    return Column(
      children: [
        // 1. Top Section: Large Preview Canvas Viewport
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              children: [
                if (_activeTool == StudioActiveTool.compress) ...[
                  _buildQuickKbPresetRow(isDark),
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: _buildImagePreviewCanvas(isDark, isTablet: true),
                ),
              ],
            ),
          ),
        ),

        // 2. Bottom Section: Studio Pro Control Deck
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: _buildTabletInspectorContent(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLandscapeLayout(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Large Central Canvas Viewport with Quick Presets Row
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Column(
              children: [
                if (_activeTool == StudioActiveTool.compress) ...[
                  _buildQuickKbPresetRow(isDark),
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: _buildImagePreviewCanvas(isDark, isTablet: true),
                ),
              ],
            ),
          ),
        ),

        // 2. Right Side Pro Inspector & Controls Panel
        Container(
          width: 340,
          margin: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? AppColors.borderDark : Colors.grey.shade200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black38 : Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildTabletInspectorContent(isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletInspectorContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top File Info Card
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
          dpi: _imageDpi,
          targetDpi: _targetDpi,
        ),
        const Divider(height: 1),

        // Studio Tool Switcher Tabs
        _buildTabletToolSelector(isDark),
        const Divider(height: 1),

        // Active Tool Inspector Content
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildActiveToolInspectorSection(isDark),
        ),

        // Bottom Action Footer
        _buildTabletInspectorFooter(isDark),
      ],
    );
  }

  Widget _buildTabletToolSelector(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTabletTabItem(
            tool: StudioActiveTool.compress,
            icon: Icons.compress_rounded,
            label: 'Compress',
            isDark: isDark,
          ),
          _buildTabletTabItem(
            tool: StudioActiveTool.resize,
            icon: Icons.open_in_full_rounded,
            label: 'Resize',
            isDark: isDark,
          ),
          _buildTabletTabItem(
            tool: StudioActiveTool.format,
            icon: Icons.tune_rounded,
            label: 'Format',
            isDark: isDark,
          ),
          _buildTabletTabItem(
            tool: StudioActiveTool.bgRemover,
            icon: Icons.auto_fix_high_rounded,
            label: 'Tools',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildTabletTabItem({
    required StudioActiveTool tool,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = _activeTool == tool ||
        (tool == StudioActiveTool.bgRemover &&
            (_activeTool == StudioActiveTool.crop ||
                _activeTool == StudioActiveTool.docFilter ||
                _activeTool == StudioActiveTool.tools ||
                _activeTool == StudioActiveTool.rotate ||
                _activeTool == StudioActiveTool.flip));

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _activeTool = tool);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? AppColors.primary : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.primary)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : AppColors.primary)
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveToolInspectorSection(bool isDark) {
    switch (_activeTool) {
      case StudioActiveTool.compress:
        return _buildTabletCompressInspector(isDark);
      case StudioActiveTool.resize:
        return _buildTabletResizeInspector(isDark);
      case StudioActiveTool.format:
        return _buildTabletFormatInspector(isDark);
      case StudioActiveTool.bgRemover:
      case StudioActiveTool.crop:
      case StudioActiveTool.docFilter:
      case StudioActiveTool.tools:
      case StudioActiveTool.rotate:
      case StudioActiveTool.flip:
        return _buildTabletToolsInspector(isDark);
      case StudioActiveTool.none:
        return _buildTabletCompressInspector(isDark);
    }
  }

  Widget _buildTabletCompressInspector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSegmentTab(
                label: 'Target KB',
                isSelected: _compressionMode == CompressionSheetMode.targetSize,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _compressionMode = CompressionSheetMode.targetSize;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'Quality %',
                isSelected: _compressionMode == CompressionSheetMode.quality,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _compressionMode = CompressionSheetMode.quality;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'Full Quality',
                isSelected: _compressionMode == CompressionSheetMode.none,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _compressionMode = CompressionSheetMode.none;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        if (_compressionMode == CompressionSheetMode.targetSize) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Target Size Limit:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                '< $_selectedTargetSizeKB KB',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _selectedTargetSizeKB.toDouble().clamp(10, 2000),
            min: 10,
            max: 2000,
            divisions: 199,
            activeColor: AppColors.primary,
            label: '$_selectedTargetSizeKB KB',
            onChanged: (val) {
              setState(() {
                _selectedTargetSizeKB = val.round();
                _showOriginal = false;
              });
            },
            onChangeEnd: (val) {
              _recordHistory();
              _triggerPreviewUpdate(debounce: false);
            },
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [20, 50, 100, 200, 500].map((kb) {
              final isSelected = _selectedTargetSizeKB == kb;
              return ChoiceChip(
                label: Text('< $kb KB', style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTargetSizeKB = kb;
                      _showOriginal = false;
                    });
                    _recordHistory();
                    _triggerPreviewUpdate(debounce: false);
                  }
                },
              );
            }).toList(),
          ),
        ],

        if (_compressionMode == CompressionSheetMode.quality) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compression Quality:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                '${_quality.round()}%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _quality.clamp(10, 100),
            min: 10,
            max: 100,
            divisions: 18,
            activeColor: AppColors.primary,
            label: '${_quality.round()}%',
            onChanged: (val) {
              setState(() {
                _quality = val;
                _showOriginal = false;
              });
            },
            onChangeEnd: (val) {
              _recordHistory();
              _triggerPreviewUpdate(debounce: false);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [40, 60, 80, 90, 100].map((q) {
              final isSelected = _quality.round() == q;
              return ChoiceChip(
                label: Text('$q%', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _quality = q.toDouble();
                      _showOriginal = false;
                    });
                    _recordHistory();
                    _triggerPreviewUpdate(debounce: false);
                  }
                },
              );
            }).toList(),
          ),
        ],

        if (_compressionMode == CompressionSheetMode.none) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Full image fidelity will be preserved without file size compression limits.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTabletResizeInspector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSegmentTab(
                label: 'Original',
                isSelected: _resizeOption == ResizeSheetOption.none,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _resizeOption = ResizeSheetOption.none;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'Exact (W×H)',
                isSelected: _resizeOption == ResizeSheetOption.exactPixels,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _resizeOption = ResizeSheetOption.exactPixels;
                    if (_targetWidth <= 0) _targetWidth = _originalWidth;
                    if (_targetHeight <= 0) _targetHeight = _originalHeight;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'Scale %',
                isSelected: _resizeOption == ResizeSheetOption.percentage,
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _resizeOption = ResizeSheetOption.percentage;
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (_resizeOption == ResizeSheetOption.exactPixels) ...[
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('w_$_targetWidth'),
                  initialValue: _targetWidth > 0 ? _targetWidth.toString() : _originalWidth.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Width (px)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    final w = int.tryParse(val);
                    if (w != null && w > 0) {
                      setState(() {
                        _targetWidth = w;
                        if (_keepAspectRatio && _originalWidth > 0) {
                          _targetHeight = (w * _originalHeight / _originalWidth).round();
                        }
                        _showOriginal = false;
                      });
                      _triggerPreviewUpdate();
                    }
                  },
                ),
              ),
              IconButton(
                icon: Icon(
                  _keepAspectRatio ? Icons.link_rounded : Icons.link_off_rounded,
                  color: _keepAspectRatio ? AppColors.primary : Colors.grey,
                ),
                tooltip: _keepAspectRatio ? 'Aspect Ratio Locked' : 'Aspect Ratio Unlocked',
                onPressed: () {
                  setState(() => _keepAspectRatio = !_keepAspectRatio);
                },
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('h_$_targetHeight'),
                  initialValue: _targetHeight > 0 ? _targetHeight.toString() : _originalHeight.toString(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Height (px)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) {
                    final h = int.tryParse(val);
                    if (h != null && h > 0) {
                      setState(() {
                        _targetHeight = h;
                        if (_keepAspectRatio && _originalHeight > 0) {
                          _targetWidth = (h * _originalWidth / _originalHeight).round();
                        }
                        _showOriginal = false;
                      });
                      _triggerPreviewUpdate();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Quick Dimensions',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildResizePresetChip('Instagram (1080×1080)', 1080, 1080),
              _buildResizePresetChip('Story (1080×1920)', 1080, 1920),
              _buildResizePresetChip('Full HD (1920×1080)', 1920, 1080),
              _buildResizePresetChip('Passport (413×531)', 413, 531),
            ],
          ),
        ],

        if (_resizeOption == ResizeSheetOption.percentage) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Scale Percentage:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
              ),
              Text(
                '$_selectedPercentage%',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: _selectedPercentage.toDouble().clamp(10, 200),
            min: 10,
            max: 200,
            divisions: 19,
            activeColor: AppColors.primary,
            label: '$_selectedPercentage%',
            onChanged: (val) {
              setState(() {
                _selectedPercentage = val.round();
                _showOriginal = false;
              });
            },
            onChangeEnd: (val) {
              _recordHistory();
              _triggerPreviewUpdate(debounce: false);
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [25, 50, 75, 100, 150].map((pct) {
              final isSelected = _selectedPercentage == pct;
              return ChoiceChip(
                label: Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                selected: isSelected,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(color: isSelected ? Colors.white : null),
                onSelected: (val) {
                  if (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedPercentage = pct;
                      _showOriginal = false;
                    });
                    _recordHistory();
                    _triggerPreviewUpdate(debounce: false);
                  }
                },
              );
            }).toList(),
          ),
        ],

        if (_resizeOption == ResizeSheetOption.none) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Preserving original resolution: $_originalWidth × $_originalHeight px',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResizePresetChip(String label, int w, int h) {
    final isSelected = _targetWidth == w && _targetHeight == h;
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: isSelected ? AppColors.primary.withValues(alpha: 0.15) : null,
      side: isSelected ? const BorderSide(color: AppColors.primary) : null,
      onPressed: () {
        HapticFeedback.selectionClick();
        setState(() {
          _resizeOption = ResizeSheetOption.exactPixels;
          _targetWidth = w;
          _targetHeight = h;
          _keepAspectRatio = false;
          _showOriginal = false;
        });
        _recordHistory();
        _triggerPreviewUpdate(debounce: false);
      },
    );
  }

  Widget _buildTabletFormatInspector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Output Format',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildSegmentTab(
                label: 'JPG',
                isSelected: _outputFormat.toLowerCase() == 'jpg',
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _outputFormat = 'jpg';
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'PNG',
                isSelected: _outputFormat.toLowerCase() == 'png',
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _outputFormat = 'png';
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
              _buildSegmentTab(
                label: 'WebP',
                isSelected: _outputFormat.toLowerCase() == 'webp',
                isDark: isDark,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _outputFormat = 'webp';
                    _showOriginal = false;
                  });
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        Text(
          'Target Print DPI',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [null, 150, 300, 600].map((dpi) {
            final isSelected = _targetDpi == dpi;
            final label = dpi == null ? 'Original (${_imageDpi ?? 72} DPI)' : '$dpi DPI';
            return ChoiceChip(
              label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(color: isSelected ? Colors.white : null),
              onSelected: (val) {
                if (val) {
                  HapticFeedback.selectionClick();
                  setState(() => _targetDpi = dpi);
                  _recordHistory();
                  _triggerPreviewUpdate(debounce: false);
                }
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTabletToolsInspector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. AI Background Remover Card (Themed with Electric Blue to Teal subtle gradient)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      AppColors.primary.withValues(alpha: 0.16),
                      AppColors.secondary.withValues(alpha: 0.10),
                    ]
                  : [
                      AppColors.primaryContainerLight.withValues(alpha: 0.50),
                      AppColors.secondaryContainerLight.withValues(alpha: 0.35),
                    ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.primary.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceVariantDark : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: const Icon(Icons.auto_fix_high_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI Background Remover',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (_hasRemovedBg)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.success.withValues(alpha: 0.22) : AppColors.successContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Applied',
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Remove or replace photo background with transparency or solid colors instantly using on-device ML.',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _handleBgRemover,
                icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                label: Text(_hasRemovedBg ? 'Change Background' : 'Remove Background'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Document & Perspective Crop (Themed card action button)
        Material(
          color: isDark ? AppColors.surfaceVariantDark.withValues(alpha: 0.45) : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _handleCrop,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.crop_rounded, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Perspective & Document Crop',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Document Scanner Filter (Themed card action button)
        Material(
          color: isDark ? AppColors.surfaceVariantDark.withValues(alpha: 0.45) : AppColors.surfaceVariantLight,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _handleDocumentFilter,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.22 : 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Document Scanner Filter',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (_hasAppliedFilter)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.success.withValues(alpha: 0.22) : AppColors.successContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Applied',
                        style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Quick Transform Controls (Rotate, Flip H, Flip V with theme-matching active states)
        Row(
          children: [
            _buildTabletTransformAction(
              icon: Icons.rotate_right_rounded,
              label: _quarterTurns > 0 ? '${_quarterTurns * 90}°' : 'Rotate',
              isActive: _quarterTurns > 0,
              isDark: isDark,
              onTap: _handleRotate,
            ),
            const SizedBox(width: 8),
            _buildTabletTransformAction(
              icon: Icons.swap_horiz_rounded,
              label: 'Flip H',
              isActive: _flipHorizontal,
              isDark: isDark,
              onTap: () {
                setState(() => _flipHorizontal = !_flipHorizontal);
                _recordHistory();
                _triggerPreviewUpdate(debounce: false);
              },
            ),
            const SizedBox(width: 8),
            _buildTabletTransformAction(
              icon: Icons.swap_vert_rounded,
              label: 'Flip V',
              isActive: _flipVertical,
              isDark: isDark,
              onTap: () {
                setState(() => _flipVertical = !_flipVertical);
                _recordHistory();
                _triggerPreviewUpdate(debounce: false);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabletTransformAction({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.24)
        : AppColors.primaryContainerLight;
    final inactiveBg = isDark
        ? AppColors.surfaceVariantDark.withValues(alpha: 0.45)
        : AppColors.surfaceVariantLight;
    final activeBorder = AppColors.primary;
    final inactiveBorder = isDark ? AppColors.borderDark : AppColors.borderLight;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Expanded(
      child: Material(
        color: isActive ? activeBg : inactiveBg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive ? activeBorder : inactiveBorder,
                width: isActive ? 1.4 : 1.0,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isActive ? activeColor : AppColors.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletInspectorFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : Colors.grey.shade200,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GradientButton(
            text: 'Process & Save Image',
            icon: Icons.bolt_rounded,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _processImage,
          ),
          if (_hasUnsavedChanges) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _resetAllAdjustments,
              icon: const Icon(Icons.refresh_rounded, size: 15, color: AppColors.warning),
              label: const Text(
                'Reset All Adjustments',
                style: TextStyle(fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSegmentTab({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCanvasImage() {
    if (_showOriginal) {
      return Image.file(
        _currentImage,
        key: const ValueKey('canvas_original_image'),
        gaplessPlayback: true,
        fit: BoxFit.contain,
      );
    }

    final File imageToShow;
    final bool applyTransform;

    if (_previewImageFile != null && _previewImageFile!.existsSync()) {
      imageToShow = _previewImageFile!;
      applyTransform = false;
    } else {
      imageToShow = _currentImage;
      applyTransform = true;
    }

    Widget imageWidget = Image.file(
      imageToShow,
      key: const ValueKey('studio_canvas_display_image'),
      gaplessPlayback: true,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (applyTransform && (_quarterTurns != 0 || _flipHorizontal || _flipVertical)) {
      imageWidget = Transform.flip(
        flipX: _flipHorizontal,
        flipY: _flipVertical,
        child: RotatedBox(
          quarterTurns: _quarterTurns,
          child: imageWidget,
        ),
      );
    }

    return imageWidget;
  }

  Widget _buildImagePreviewCanvas(bool isDark, {bool isTablet = false}) {
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
            // On-canvas Quick Actions (Tablet View)
            if (isTablet)
              Positioned(
                bottom: 12,
                left: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.rotate_right_rounded, size: 20, color: Colors.white),
                          tooltip: 'Rotate 90°',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _handleRotate,
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.white),
                          tooltip: 'Flip Horizontal',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() => _flipHorizontal = !_flipHorizontal);
                            _recordHistory();
                            _triggerPreviewUpdate(debounce: false);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.swap_vert_rounded, size: 20, color: Colors.white),
                          tooltip: 'Flip Vertical',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: () {
                            setState(() => _flipVertical = !_flipVertical);
                            _recordHistory();
                            _triggerPreviewUpdate(debounce: false);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.crop_rounded, size: 18, color: Colors.white),
                          tooltip: 'Crop',
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                          onPressed: _handleCrop,
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
}
