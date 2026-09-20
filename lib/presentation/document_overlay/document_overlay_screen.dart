import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/process_result.dart';
import '../../services/image_service/document_overlay_compositor.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../../services/share_service.dart';
import '../result/result_screen.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/image_source_picker_sheet.dart';
import 'models/overlay_item_model.dart';
import 'widgets/id_card_duo_picker_sheet.dart';
import 'widgets/signature_pad_dialog.dart';

class DocumentOverlayScreen extends StatefulWidget {
  final File? initialImage;
  final bool returnCompositedFile;
  final bool startWithIdCardWizard;

  const DocumentOverlayScreen({
    super.key,
    this.initialImage,
    this.returnCompositedFile = false,
    this.startWithIdCardWizard = false,
  });

  @override
  State<DocumentOverlayScreen> createState() => _DocumentOverlayScreenState();
}

class _OverlayHistoryState {
  final List<OverlayItemModel> layers;
  final bool isBaseDocumentDeleted;
  final bool baseDocumentAsLayer;
  final String? baseDocumentLayerId;
  final CanvasPageSize pageSize;

  const _OverlayHistoryState({
    required this.layers,
    required this.isBaseDocumentDeleted,
    required this.baseDocumentAsLayer,
    required this.baseDocumentLayerId,
    required this.pageSize,
  });
}

class _DocumentOverlayScreenState extends State<DocumentOverlayScreen> {
  late CanvasPageSize _pageSize;
  List<OverlayItemModel> _layers = [];
  String? _selectedLayerId;

  // Zoom & Pan Controller for Canvas
  late final TransformationController _transformationController;
  bool _isZoomedIn = false;
  bool _isDraggingLayer = false;
  Size _viewportSize = Size.zero;

  // History for Undo / Redo
  final List<_OverlayHistoryState> _history = [];
  int _historyIndex = -1;

  double _baseAspectRatio = 1.0 / 1.4142; // Default A4 Portrait
  bool _isProcessing = false;
  bool _baseDocumentAsLayer = false;
  String? _baseDocumentLayerId;
  bool _isBaseDocumentDeleted = false;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_onTransformationChanged);

    if (widget.initialImage != null) {
      _pageSize = CanvasPageSize.matchDocument;
      _loadBaseImageAspectRatio();
    } else {
      _pageSize = CanvasPageSize.a4Portrait;
    }

    _recordHistory();

    if (widget.startWithIdCardWizard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleIdCardDuo();
      });
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_onTransformationChanged);
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadBaseImageAspectRatio() async {
    if (widget.initialImage == null) return;
    try {
      final bytes = await widget.initialImage!.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null && mounted) {
        setState(() {
          _baseAspectRatio = decoded.width / decoded.height;
        });
      }
    } catch (_) {}
  }

  void _recordHistory() {
    final snapshot = _OverlayHistoryState(
      layers: _layers.map((l) => l.copyWith()).toList(),
      isBaseDocumentDeleted: _isBaseDocumentDeleted,
      baseDocumentAsLayer: _baseDocumentAsLayer,
      baseDocumentLayerId: _baseDocumentLayerId,
      pageSize: _pageSize,
    );
    if (_historyIndex >= 0 && _historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(snapshot);
    if (_history.length > 25) {
      _history.removeAt(0);
    }
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex <= 0) return;
    HapticFeedback.lightImpact();
    setState(() {
      _historyIndex--;
      final state = _history[_historyIndex];
      _layers = state.layers.map((l) => l.copyWith()).toList();
      _isBaseDocumentDeleted = state.isBaseDocumentDeleted;
      _baseDocumentAsLayer = state.baseDocumentAsLayer;
      _baseDocumentLayerId = state.baseDocumentLayerId;
      _pageSize = state.pageSize;
      if (_selectedLayerId != null &&
          !_layers.any((l) => l.id == _selectedLayerId)) {
        _selectedLayerId = null;
      }
    });
  }

  void _redo() {
    if (_historyIndex >= _history.length - 1) return;
    HapticFeedback.lightImpact();
    setState(() {
      _historyIndex++;
      final state = _history[_historyIndex];
      _layers = state.layers.map((l) => l.copyWith()).toList();
      _isBaseDocumentDeleted = state.isBaseDocumentDeleted;
      _baseDocumentAsLayer = state.baseDocumentAsLayer;
      _baseDocumentLayerId = state.baseDocumentLayerId;
      _pageSize = state.pageSize;
      if (_selectedLayerId != null &&
          !_layers.any((l) => l.id == _selectedLayerId)) {
        _selectedLayerId = null;
      }
    });
  }

  void _resetAllLayers() {
    if (_layers.isEmpty && !_baseDocumentAsLayer && !_isBaseDocumentDeleted) return;
    HapticFeedback.lightImpact();
    setState(() {
      _layers.clear();
      _selectedLayerId = null;
      _baseDocumentAsLayer = false;
      _baseDocumentLayerId = null;
      _isBaseDocumentDeleted = false;
      if (widget.initialImage != null) {
        _pageSize = CanvasPageSize.matchDocument;
      } else {
        _pageSize = CanvasPageSize.a4Portrait;
      }
      _resetZoom();
      _recordHistory();
    });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final isZoomed = (scale - 1.0).abs() > 0.05 || !_transformationController.value.isIdentity();
    if (isZoomed != _isZoomedIn) {
      setState(() => _isZoomedIn = isZoomed);
    }
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    if (_isZoomedIn) {
      _resetZoom();
    } else {
      _applyZoomScale(2.0);
    }
  }

  void _resetZoom() {
    HapticFeedback.lightImpact();
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    HapticFeedback.lightImpact();
    final current = _transformationController.value.getMaxScaleOnAxis();
    final next = (current + 0.4).clamp(0.5, 4.0);
    _applyZoomScale(next);
  }

  void _zoomOut() {
    HapticFeedback.lightImpact();
    final current = _transformationController.value.getMaxScaleOnAxis();
    final next = (current - 0.4).clamp(0.5, 4.0);
    _applyZoomScale(next);
  }

  void _applyZoomScale(double targetScale) {
    if ((targetScale - 1.0).abs() < 0.05) {
      _resetZoom();
      return;
    }
    final cx = _viewportSize.width > 0 ? _viewportSize.width / 2 : 200.0;
    final cy = _viewportSize.height > 0 ? _viewportSize.height / 2 : 300.0;

    final matrix = Matrix4.translationValues(
      cx * (1.0 - targetScale),
      cy * (1.0 - targetScale),
      0.0,
    )..multiply(Matrix4.diagonal3Values(targetScale, targetScale, 1.0));

    setState(() {
      _transformationController.value = matrix;
    });
  }

  double get _currentCanvasRatio {
    switch (_pageSize) {
      case CanvasPageSize.a4Portrait:
        return 1.0 / 1.4142;
      case CanvasPageSize.a4Landscape:
        return 1.4142 / 1.0;
      case CanvasPageSize.matchDocument:
        return _baseAspectRatio;
    }
  }

  void _changePageSize(CanvasPageSize newSize) {
    if (_pageSize == newSize) return;

    // Reset canvas zoom and center when page format is changed
    _transformationController.value = Matrix4.identity();
    _isZoomedIn = false;

    final oldCanvasRatio = _currentCanvasRatio;
    setState(() {
      _pageSize = newSize;
      final newCanvasRatio = _currentCanvasRatio;

      // On A4 paper formats, automatically ensure the base document is an active, selectable,
      // resizable layer so resize handles, rotate handles, and options bar immediately appear!
      if (widget.initialImage != null &&
          !_isBaseDocumentDeleted &&
          (newSize == CanvasPageSize.a4Portrait ||
              newSize == CanvasPageSize.a4Landscape)) {
        if (!_baseDocumentAsLayer) {
          _baseDocumentAsLayer = true;
          final id = 'base_doc_${DateTime.now().millisecondsSinceEpoch}';
          _baseDocumentLayerId = id;

          final docRatio = _baseAspectRatio > 0 ? _baseAspectRatio : 1.0;
          double normW = 0.75;
          double normH = normW * (newCanvasRatio / docRatio);
          if (normH > 0.75) {
            normW *= (0.75 / normH);
            normH = 0.75;
          }

          final docLayer = OverlayItemModel(
            id: id,
            file: widget.initialImage!,
            type: OverlayItemType.photo,
            label: 'Photo',
            normalizedX: 0.5,
            normalizedY: 0.5,
            normalizedWidth: normW.clamp(0.1, 0.95),
            normalizedHeight: normH.clamp(0.05, 0.95),
            aspectRatio: docRatio,
          );

          _layers.insert(0, docLayer);
          _selectedLayerId = id;
        } else {
          _selectedLayerId = _baseDocumentLayerId ?? (_layers.isNotEmpty ? _layers.first.id : null);
        }
      }

      // Preserve aspect ratio and safe positioning for all layers on the new canvas
      if (_layers.isNotEmpty && oldCanvasRatio > 0 && newCanvasRatio > 0) {
        _layers = _layers.map((layer) {
          final layerRatio = layer.aspectRatio > 0 ? layer.aspectRatio : 1.0;

          // Preserve layer's true aspect ratio on new canvas:
          // (newNormW / newNormH) * newCanvasRatio == layerRatio
          // => newNormH = newNormW * (newCanvasRatio / layerRatio)
          double newNormW = layer.normalizedWidth;
          double newNormH = newNormW * (newCanvasRatio / layerRatio);

          if (newNormH > 0.85) {
            final scale = 0.85 / newNormH;
            newNormW *= scale;
            newNormH = 0.85;
          }
          if (newNormW > 0.85) {
            final scale = 0.85 / newNormW;
            newNormW = 0.85;
            newNormH *= scale;
          }

          final halfW = newNormW / 2;
          final halfH = newNormH / 2;
          final clampedX =
              layer.normalizedX.clamp(halfW + 0.02, 1.0 - halfW - 0.02);
          final clampedY =
              layer.normalizedY.clamp(halfH + 0.02, 1.0 - halfH - 0.02);

          return layer.copyWith(
            normalizedWidth: newNormW.clamp(0.08, 0.95),
            normalizedHeight: newNormH.clamp(0.05, 0.95),
            normalizedX: clampedX.clamp(0.05, 0.95),
            normalizedY: clampedY.clamp(0.05, 0.95),
          );
        }).toList();
      }
    });
    _recordHistory();
  }

  void _toggleBaseDocumentAsLayer() {
    if (widget.initialImage == null || _isBaseDocumentDeleted) return;
    HapticFeedback.selectionClick();

    setState(() {
      if (_baseDocumentAsLayer) {
        // If already a layer, center it on canvas and re-select it
        final idx = _layers.indexWhere((l) => l.id == _baseDocumentLayerId);
        if (idx >= 0) {
          _layers[idx] = _layers[idx].copyWith(
            normalizedX: 0.5,
            normalizedY: 0.5,
          );
        }
        _selectedLayerId = _baseDocumentLayerId;
      } else {
        // Convert base image into a freely movable & resizable layer on sheet
        _baseDocumentAsLayer = true;
        final id = 'base_doc_${DateTime.now().millisecondsSinceEpoch}';
        _baseDocumentLayerId = id;

        final canvasRatio = _currentCanvasRatio;
        final docRatio = _baseAspectRatio > 0 ? _baseAspectRatio : 1.0;

        final isMatchDoc = _pageSize == CanvasPageSize.matchDocument;
        double normW = isMatchDoc ? 0.95 : 0.75;
        double normH = normW * (canvasRatio / docRatio);
        final maxH = isMatchDoc ? 0.95 : 0.75;
        if (normH > maxH) {
          normW *= (maxH / normH);
          normH = maxH;
        }

        final docLayer = OverlayItemModel(
          id: id,
          file: widget.initialImage!,
          type: OverlayItemType.photo,
          label: 'Photo',
          normalizedX: 0.5,
          normalizedY: 0.5,
          normalizedWidth: normW.clamp(0.1, 0.98),
          normalizedHeight: normH.clamp(0.05, 0.98),
          aspectRatio: docRatio,
        );

        _layers.insert(0, docLayer);
        _selectedLayerId = id;
      }
    });
    _recordHistory();
  }

  void _centerSelectedLayer() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _layers[idx] = _layers[idx].copyWith(
        normalizedX: 0.5,
        normalizedY: 0.5,
      );
    });
    _recordHistory();
  }

  void _fitWidthSelectedLayer() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    final cur = _layers[idx];
    final canvasRatio = _currentCanvasRatio;
    final layerRatio = cur.aspectRatio > 0 ? cur.aspectRatio : 1.0;

    double normW = 0.85;
    double normH = normW * (canvasRatio / layerRatio);
    if (normH > 0.85) {
      normW *= (0.85 / normH);
      normH = 0.85;
    }

    setState(() {
      _layers[idx] = cur.copyWith(
        normalizedWidth: normW.clamp(0.1, 0.95),
        normalizedHeight: normH.clamp(0.05, 0.95),
        normalizedX: 0.5,
        normalizedY: 0.5,
      );
    });
    _recordHistory();
  }

  Future<void> _addPhotoLayer() async {
    HapticFeedback.selectionClick();
    final file = await ImageSourcePickerSheet.show(
      context,
      title: 'Add Photo / Document',
      subtitle: 'Select an image or scan with camera',
    );
    if (file == null || !mounted) return;

    double ratio = 1.0;
    try {
      final bytes = await file.readAsBytes();
      final dec = img.decodeImage(bytes);
      if (dec != null && dec.height > 0) {
        ratio = dec.width / dec.height;
      }
    } catch (_) {}

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final canvasRatio = _currentCanvasRatio;
    double normW = 0.45;
    double normH = normW * (canvasRatio / ratio);
    if (normH > 0.8) {
      normW *= (0.8 / normH);
      normH = 0.8;
    }
    if (normW > 0.8) {
      normH *= (0.8 / normW);
      normW = 0.8;
    }

    final newLayer = OverlayItemModel(
      id: id,
      file: file,
      type: OverlayItemType.photo,
      label: 'Photo',
      normalizedX: 0.5,
      normalizedY: 0.5,
      normalizedWidth: normW.clamp(0.08, 0.95),
      normalizedHeight: normH.clamp(0.05, 0.95),
      aspectRatio: ratio,
    );

    setState(() {
      _layers.add(newLayer);
      _selectedLayerId = id;
    });
    _recordHistory();
  }

  Future<void> _addSignatureLayer() async {
    HapticFeedback.selectionClick();
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Add Digital Signature',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.draw_rounded,
                          color: AppColors.primary),
                    ),
                    title: const Text('Draw Signature Now',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Sign smoothly with your finger'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () => Navigator.of(ctx).pop('draw'),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.image_outlined,
                          color: AppColors.secondary),
                    ),
                    title: const Text('Import Signature Image',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Pick transparent PNG or photo from gallery'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () => Navigator.of(ctx).pop('gallery'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    File? sigFile;
    if (source == 'draw') {
      sigFile = await SignaturePadDialog.show(context);
    } else {
      sigFile = await ImageSourcePickerSheet.show(
        context,
        title: 'Select Signature Image',
        subtitle: 'Choose image from gallery',
      );
    }

    if (sigFile == null || !mounted) return;

    double ratio = 2.0; // typical signature aspect ratio
    try {
      final bytes = await sigFile.readAsBytes();
      final dec = img.decodeImage(bytes);
      if (dec != null && dec.height > 0) {
        ratio = dec.width / dec.height;
      }
    } catch (_) {}

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final canvasRatio = _currentCanvasRatio;
    double normW = 0.35;
    double normH = normW * (canvasRatio / ratio);
    if (normH > 0.35) {
      normW *= (0.35 / normH);
      normH = 0.35;
    }

    final newLayer = OverlayItemModel(
      id: id,
      file: sigFile,
      type: OverlayItemType.signature,
      label: 'Signature',
      normalizedX: 0.72,
      normalizedY: 0.85, // naturally placed at bottom right of document
      normalizedWidth: normW.clamp(0.08, 0.95),
      normalizedHeight: normH.clamp(0.04, 0.45),
      aspectRatio: ratio,
    );

    setState(() {
      _layers.add(newLayer);
      _selectedLayerId = id;
    });
    _recordHistory();
  }

  Future<void> _handleIdCardDuo() async {
    HapticFeedback.selectionClick();
    final duoResult = await IdCardDuoPickerSheet.show(context);
    if (duoResult == null || !mounted) return;

    // Switch page size to A4 if not already
    final targetSize = duoResult.isVertical
        ? CanvasPageSize.a4Portrait
        : CanvasPageSize.a4Landscape;
    if (_pageSize != targetSize) {
      _changePageSize(targetSize);
    }

    const idRatio = 85.6 / 54.0; // Standard ID Card aspect ratio ~1.585
    final canvasRatio = _currentCanvasRatio;

    List<OverlayItemModel> newLayers = [];

    if (duoResult.isVertical) {
      // Stacked Top and Bottom for Portrait A4
      final normW = 0.65;
      final normH = normW * (canvasRatio / idRatio);

      newLayers.add(
        OverlayItemModel(
          id: 'id_front_${DateTime.now().millisecondsSinceEpoch}',
          file: duoResult.frontFile,
          type: OverlayItemType.idFront,
          label: 'Aadhaar Front',
          normalizedX: 0.5,
          normalizedY: 0.32,
          normalizedWidth: normW,
          normalizedHeight: normH,
          hasBorder: duoResult.hasBorder,
          aspectRatio: idRatio,
        ),
      );

      newLayers.add(
        OverlayItemModel(
          id: 'id_back_${DateTime.now().millisecondsSinceEpoch + 1}',
          file: duoResult.backFile,
          type: OverlayItemType.idBack,
          label: 'Aadhaar Back',
          normalizedX: 0.5,
          normalizedY: 0.68,
          normalizedWidth: normW,
          normalizedHeight: normH,
          hasBorder: duoResult.hasBorder,
          aspectRatio: idRatio,
        ),
      );
    } else {
      // Side by Side
      final normW = 0.42;
      final normH = normW * (canvasRatio / idRatio);

      newLayers.add(
        OverlayItemModel(
          id: 'id_front_${DateTime.now().millisecondsSinceEpoch}',
          file: duoResult.frontFile,
          type: OverlayItemType.idFront,
          label: 'Aadhaar Front',
          normalizedX: 0.28,
          normalizedY: 0.5,
          normalizedWidth: normW,
          normalizedHeight: normH,
          hasBorder: duoResult.hasBorder,
          aspectRatio: idRatio,
        ),
      );

      newLayers.add(
        OverlayItemModel(
          id: 'id_back_${DateTime.now().millisecondsSinceEpoch + 1}',
          file: duoResult.backFile,
          type: OverlayItemType.idBack,
          label: 'Aadhaar Back',
          normalizedX: 0.72,
          normalizedY: 0.5,
          normalizedWidth: normW,
          normalizedHeight: normH,
          hasBorder: duoResult.hasBorder,
          aspectRatio: idRatio,
        ),
      );
    }

    setState(() {
      _layers.addAll(newLayers);
      _selectedLayerId = newLayers.first.id;
    });
    _recordHistory();
  }

  void _deleteSelectedLayer() {
    if (_selectedLayerId == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      final isBaseDoc = _selectedLayerId == _baseDocumentLayerId ||
          (_layers.any((l) =>
              l.id == _selectedLayerId &&
              widget.initialImage != null &&
              l.file.path == widget.initialImage!.path));

      if (isBaseDoc) {
        _isBaseDocumentDeleted = true;
        _baseDocumentAsLayer = false;
        _baseDocumentLayerId = null;
      }
      _layers.removeWhere((l) => l.id == _selectedLayerId);
      _selectedLayerId = null;
    });
    _recordHistory();
  }

  void _duplicateSelectedLayer() {
    if (_selectedLayerId == null) return;
    final layer = _layers.firstWhere((l) => l.id == _selectedLayerId);
    final dup = layer.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      normalizedX: (layer.normalizedX + 0.05).clamp(0.1, 0.9),
      normalizedY: (layer.normalizedY + 0.05).clamp(0.1, 0.9),
    );
    HapticFeedback.lightImpact();
    setState(() {
      _layers.add(dup);
      _selectedLayerId = dup.id;
    });
    _recordHistory();
  }

  void _rotateSelectedLayer90() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    final layer = _layers[idx];
    final nextRotation = (layer.rotation + (math.pi / 2)) % (math.pi * 2);
    HapticFeedback.selectionClick();
    setState(() {
      _layers[idx] = layer.copyWith(rotation: nextRotation);
    });
    _recordHistory();
  }

  void _toggleBorderSelectedLayer() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    final layer = _layers[idx];
    HapticFeedback.selectionClick();
    setState(() {
      _layers[idx] = layer.copyWith(hasBorder: !layer.hasBorder);
    });
    _recordHistory();
  }

  void _bringSelectedToFront() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0 || idx == _layers.length - 1) return;
    final layer = _layers.removeAt(idx);
    setState(() {
      _layers.add(layer);
    });
    _recordHistory();
  }

  Future<void> _handleSave() async {
    if (_layers.isEmpty &&
        (widget.initialImage == null || _isBaseDocumentDeleted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one photo or card.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final layerConfigs = _layers.map((l) {
        return OverlayLayerConfig(
          imagePath: l.file.path,
          normalizedX: l.normalizedX,
          normalizedY: l.normalizedY,
          normalizedWidth: l.normalizedWidth,
          normalizedHeight: l.normalizedHeight,
          rotation: l.rotation,
          opacity: l.opacity,
          hasBorder: l.hasBorder,
          borderColorValue: l.borderColorValue,
          borderWidth: l.borderWidth,
        );
      }).toList();

      final params = DocumentOverlayParams(
        baseImagePath: (_baseDocumentAsLayer || _isBaseDocumentDeleted)
            ? null
            : widget.initialImage?.path,
        pageSize: _pageSize,
        layers: layerConfigs,
        outputFormat: 'jpg',
        outputQuality: 95,
      );

      final result = await DocumentOverlayCompositor.composite(params);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (widget.returnCompositedFile) {
        Navigator.of(context).pop(File(result.outputPath));
      } else {
        _showSuccessExportSheet(result);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating document: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showSuccessExportSheet(ProcessResult result) async {
    final file = File(result.outputPath);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.success,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Document Ready!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    '300 DPI High-Quality Print Ready (${result.outputWidth} × ${result.outputHeight})',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.primary),
                    title: const Text('Export & Print as A4 PDF',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Direct printable PDF file'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () async {
                      Navigator.of(ctx).pop();
                      final pdfFile =
                          await DocumentScannerService.createPdfFromImages([file]);
                      if (mounted) {
                        await ShareService.shareImage(
                          pdfFile.path,
                          text: 'Printable Document A4',
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.photo_library_rounded, color: Colors.amber),
                    title: const Text('View & Save to Gallery',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Open in Result Screen to save image'),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => ResultScreen(result: result)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.share_rounded,
                        color: AppColors.secondary),
                    title: const Text('Share Image',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      ShareService.shareImage(file.path);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePopScope(bool didPop) async {
    if (didPop) return;
    if (_layers.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await DiscardChangesSheet.show(
      context,
      title: 'Discard Document Layout?',
      message: 'You have placed items on the canvas. Are you sure you want to leave without saving?',
    );

    if (discard && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? AppColors.surfaceDark : Colors.white;
    final appBarFg = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final scaffoldBg =
        isDark ? AppColors.backgroundDark : const Color(0xFFF6F8FB);
    final selectedLayer = (_selectedLayerId != null && _layers.isNotEmpty)
        ? _layers.where((l) => l.id == _selectedLayerId).firstOrNull
        : null;
    final hasChanges =
        _layers.isNotEmpty || _baseDocumentAsLayer || _isBaseDocumentDeleted;

    return PopScope(
      canPop: !hasChanges,
      onPopInvokedWithResult: (didPop, result) => _handlePopScope(didPop),
      child: Scaffold(
        backgroundColor: scaffoldBg,
        appBar: AppBar(
          backgroundColor: appBarBg,
          foregroundColor: appBarFg,
          iconTheme: IconThemeData(color: appBarFg),
          actionsIconTheme: IconThemeData(color: appBarFg),
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
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
            onPressed: () => _handlePopScope(false),
          ),
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              widget.initialImage != null ? 'Add Photo Studio' : 'A4 Print Studio',
              style: (Theme.of(context).appBarTheme.titleTextStyle ??
                      const TextStyle())
                  .copyWith(
                    color: appBarFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Undo',
              onPressed: (_isProcessing || _historyIndex <= 0) ? null : _undo,
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Redo',
              onPressed: (_isProcessing || _historyIndex >= _history.length - 1)
                  ? null
                  : _redo,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 22),
              color: appBarFg,
              disabledColor: appBarFg.withValues(alpha: 0.25),
              tooltip: 'Reset Document',
              onPressed: (_isProcessing || !hasChanges) ? null : _resetAllLayers,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 0),
                        minimumSize: const Size(0, 36),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 2,
                        shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      ),
                      icon: Icon(
                        widget.returnCompositedFile
                            ? Icons.check_rounded
                            : Icons.save_alt_rounded,
                        size: 18,
                      ),
                      label: Text(
                        widget.returnCompositedFile ? 'Apply' : 'Save',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: _handleSave,
                    ),
            ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Canvas Workspace Area (Zoomable & Pannable with InteractiveViewer)
              Expanded(
                child: ClipRect(
                  child: Stack(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          _viewportSize =
                              Size(constraints.maxWidth, constraints.maxHeight);

                          final canvasRatio = _currentCanvasRatio;
                          final availableW = (constraints.maxWidth - 32)
                              .clamp(100.0, constraints.maxWidth);
                          final availableH = (constraints.maxHeight - 32)
                              .clamp(100.0, constraints.maxHeight);

                          double w = availableW;
                          double h = w / canvasRatio;

                          if (h > availableH) {
                            h = availableH;
                            w = h * canvasRatio;
                          }

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () {
                              if (_selectedLayerId != null) {
                                setState(() => _selectedLayerId = null);
                              }
                            },
                            onDoubleTap: _handleDoubleTap,
                            child: Center(
                              child: InteractiveViewer(
                                transformationController:
                                    _transformationController,
                                minScale: 0.5,
                                maxScale: 4.0,
                                panEnabled: !_isDraggingLayer,
                                scaleEnabled: true,
                                boundaryMargin: const EdgeInsets.all(160),
                                clipBehavior: Clip.none,
                                child: _buildCanvas(w, h, isDark),
                              ),
                            ),
                          );
                        },
                      ),

                      // Floating Zoom Controls
                      _buildFloatingZoomControls(isDark),
                    ],
                  ),
                ),
              ),

              // Middle Dock: Selected Layer Inspector (if selected) OR Page Format Dock (if none)
              if (selectedLayer != null)
                _buildSelectedLayerInspector(selectedLayer, isDark)
              else
                _buildPageFormatDock(isDark),

              // Studio Bottom Toolbar
              _buildStudioBottomToolbar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingZoomControls(bool isDark) {
    return Stack(
      children: [
        // Top-Left: Zoom percentage pill or Reset button
        Positioned(
          top: 12,
          left: 12,
          child: ValueListenableBuilder<Matrix4>(
            valueListenable: _transformationController,
            builder: (context, matrix, _) {
              final scale = matrix.getMaxScaleOnAxis();
              final isZoomed = (scale - 1.0).abs() > 0.05;
              final percentText = '${(scale * 100).round()}%';

              if (isZoomed) {
                return Material(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    onTap: _resetZoom,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_out_map_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '$percentText • Reset',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$percentText • Pinch or double-tap',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Top-Right: Quick Zoom In / Out / Reset buttons
        Positioned(
          top: 12,
          right: 12,
          child: ValueListenableBuilder<Matrix4>(
            valueListenable: _transformationController,
            builder: (context, matrix, _) {
              final scale = matrix.getMaxScaleOnAxis();
              final isZoomed = (scale - 1.0).abs() > 0.05;

              return Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildZoomIconButton(
                      icon: Icons.add_rounded,
                      tooltip: 'Zoom in',
                      onPressed: _zoomIn,
                      isDark: isDark,
                    ),
                    Container(
                      width: 20,
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                    _buildZoomIconButton(
                      icon: Icons.remove_rounded,
                      tooltip: 'Zoom out',
                      onPressed: _zoomOut,
                      isDark: isDark,
                    ),
                    if (isZoomed) ...[
                      Container(
                        width: 20,
                        height: 1,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      _buildZoomIconButton(
                        icon: Icons.restart_alt_rounded,
                        tooltip: 'Reset zoom (100%)',
                        onPressed: _resetZoom,
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoomIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildPageFormatDock(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.aspect_ratio_rounded,
                  size: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 5),
                Text(
                  'PAGE:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            if (widget.initialImage != null && !_isBaseDocumentDeleted) ...[
              _buildStudioPresetChip(
                label: 'Original Doc',
                icon: Icons.image_outlined,
                isSelected: _pageSize == CanvasPageSize.matchDocument,
                onTap: () => _changePageSize(CanvasPageSize.matchDocument),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
            ],
            _buildStudioPresetChip(
              label: 'A4 Portrait',
              icon: Icons.portrait_rounded,
              isSelected: _pageSize == CanvasPageSize.a4Portrait,
              onTap: () => _changePageSize(CanvasPageSize.a4Portrait),
              isDark: isDark,
            ),
            const SizedBox(width: 8),
            _buildStudioPresetChip(
              label: 'A4 Landscape',
              icon: Icons.landscape_rounded,
              isSelected: _pageSize == CanvasPageSize.a4Landscape,
              onTap: () => _changePageSize(CanvasPageSize.a4Landscape),
              isDark: isDark,
            ),
            if (widget.initialImage != null &&
                !_isBaseDocumentDeleted &&
                _pageSize != CanvasPageSize.matchDocument) ...[
              const SizedBox(width: 8),
              _buildStudioPresetChip(
                label: _baseDocumentAsLayer ? 'Center on A4' : 'Move on A4',
                icon: _baseDocumentAsLayer
                    ? Icons.center_focus_strong_rounded
                    : Icons.open_with_rounded,
                isSelected: _baseDocumentAsLayer,
                isAccent: true,
                onTap: _toggleBaseDocumentAsLayer,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudioPresetChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    bool isAccent = false,
  }) {
    final activeBg = AppColors.primary;
    final inactiveBg = isDark ? AppColors.surfaceDark : Colors.white;

    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(16),
      elevation: isSelected ? 2 : 0,
      shadowColor: AppColors.primary.withValues(alpha: 0.3),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isAccent
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : (isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isAccent
                          ? AppColors.primary
                          : (isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight)),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isAccent
                            ? AppColors.primary
                            : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCanvas(double canvasWidth, double canvasHeight, bool isDark) {
    return Container(
      width: canvasWidth,
      height: canvasHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : Colors.grey.shade300,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black54
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base Image or Blank Canvas
            if (widget.initialImage != null &&
                !_isBaseDocumentDeleted &&
                !_baseDocumentAsLayer) ...[
              if (_pageSize == CanvasPageSize.matchDocument)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_selectedLayerId != null) {
                      setState(() => _selectedLayerId = null);
                    } else {
                      _toggleBaseDocumentAsLayer();
                    }
                  },
                  child: Image.file(
                    widget.initialImage!,
                    fit: BoxFit.contain,
                  ),
                )
              else ...[
                // Blank A4 sheet background
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (_selectedLayerId != null) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedLayerId = null);
                    }
                  },
                  child: CustomPaint(
                    painter: _A4SheetGridPainter(),
                    size: Size(canvasWidth, canvasHeight),
                  ),
                ),
                // Base document placed cleanly in printable center of A4 paper
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (_selectedLayerId != null) {
                      setState(() => _selectedLayerId = null);
                    } else {
                      _toggleBaseDocumentAsLayer();
                    }
                  },
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.9,
                      heightFactor: 0.9,
                      child: Image.file(
                        widget.initialImage!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ],
            ] else ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_selectedLayerId != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLayerId = null);
                  }
                },
                child: CustomPaint(
                  painter: _A4SheetGridPainter(),
                  size: Size(canvasWidth, canvasHeight),
                ),
              ),
            ],

            // Render Layers
            for (final layer in _layers)
              _buildLayerWidget(layer, canvasWidth, canvasHeight, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLayerWidget(
    OverlayItemModel layer,
    double canvasWidth,
    double canvasHeight,
    bool isDark,
  ) {
    final isSelected = layer.id == _selectedLayerId;
    final layerW = layer.normalizedWidth * canvasWidth;
    final layerH = layer.normalizedHeight * canvasHeight;

    const handleMargin = 32.0;
    final activeMargin = isSelected ? handleMargin : 0.0;

    final posX = (layer.normalizedX * canvasWidth) - (layerW / 2) - activeMargin;
    final posY = (layer.normalizedY * canvasHeight) - (layerH / 2) - activeMargin;
    final totalW = layerW + (activeMargin * 2);
    final totalH = layerH + (activeMargin * 2);

    return Positioned(
      left: posX,
      top: posY,
      width: totalW,
      height: totalH,
      child: Transform.rotate(
        angle: layer.rotation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Central Image Content & Move Pan Detector
            Positioned(
              left: activeMargin,
              top: activeMargin,
              width: layerW,
              height: layerH,
              child: Listener(
                onPointerDown: (_) {
                  if (!_isDraggingLayer) {
                    setState(() => _isDraggingLayer = true);
                  }
                },
                onPointerUp: (_) {
                  if (_isDraggingLayer) {
                    setState(() => _isDraggingLayer = false);
                  }
                },
                onPointerCancel: (_) {
                  if (_isDraggingLayer) {
                    setState(() => _isDraggingLayer = false);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLayerId = layer.id);
                  },
                  onPanStart: (_) {
                    if (!_isDraggingLayer) {
                      setState(() => _isDraggingLayer = true);
                    }
                  },
                  onPanUpdate: (details) {
                    final idx = _layers.indexWhere((l) => l.id == layer.id);
                    if (idx < 0) return;
                    final dx = details.delta.dx / canvasWidth;
                    final dy = details.delta.dy / canvasHeight;
                    setState(() {
                      _layers[idx] = layer.copyWith(
                        normalizedX: (layer.normalizedX + dx).clamp(0.05, 0.95),
                        normalizedY: (layer.normalizedY + dy).clamp(0.05, 0.95),
                      );
                    });
                  },
                  onPanEnd: (_) {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                    _recordHistory();
                  },
                  onPanCancel: () {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                  },
                  child: Opacity(
                    opacity: layer.opacity,
                    child: Container(
                      decoration: BoxDecoration(
                        border: isSelected
                            ? Border.all(
                                color: AppColors.primary,
                                width: 2,
                              )
                            : (layer.hasBorder
                                ? Border.all(
                                    color: layer.borderColor,
                                    width: layer.borderWidth,
                                  )
                                : null),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Image.file(
                        layer.file,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Selection Handles (Only when layer is selected)
            if (isSelected) ...[
              // Bottom-Right: Corner Scale Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + layerW - 22,
                top: activeMargin + layerH - 22,
                width: 44,
                height: 44,
                child: Listener(
                  onPointerDown: (_) {
                    if (!_isDraggingLayer) {
                      setState(() => _isDraggingLayer = true);
                    }
                  },
                  onPointerUp: (_) {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                  },
                  onPointerCancel: (_) {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {
                      if (!_isDraggingLayer) {
                        setState(() => _isDraggingLayer = true);
                      }
                    },
                    onPanUpdate: (details) {
                      final idx = _layers.indexWhere((l) => l.id == layer.id);
                      if (idx < 0) return;
                      final cur = _layers[idx];

                      // Project delta into layer's rotated coordinate space
                      double dx = details.delta.dx;
                      double dy = details.delta.dy;
                      if (cur.rotation.abs() > 0.01) {
                        final cosA = math.cos(-cur.rotation);
                        final sinA = math.sin(-cur.rotation);
                        final rotX = (dx * cosA) - (dy * sinA);
                        final rotY = (dx * sinA) + (dy * cosA);
                        dx = rotX;
                        dy = rotY;
                      }

                      final deltaPx = (dx.abs() > dy.abs()) ? dx : dy;
                      final deltaNorm = deltaPx / canvasWidth;

                      final newW =
                          (cur.normalizedWidth + deltaNorm).clamp(0.08, 0.95);
                      final canvasRatio = _currentCanvasRatio;
                      final newH =
                          (newW * (canvasRatio / cur.aspectRatio)).clamp(0.03, 0.95);

                      // Anchor top-left corner
                      final dW = newW - cur.normalizedWidth;
                      final dH = newH - cur.normalizedHeight;
                      final newX =
                          (cur.normalizedX + (dW / 2)).clamp(0.05, 0.95);
                      final newY =
                          (cur.normalizedY + (dH / 2)).clamp(0.05, 0.95);

                      setState(() {
                        _layers[idx] = cur.copyWith(
                          normalizedWidth: newW,
                          normalizedHeight: newH,
                          normalizedX: newX,
                          normalizedY: newY,
                        );
                      });
                    },
                    onPanEnd: (_) {
                      if (_isDraggingLayer) {
                        setState(() => _isDraggingLayer = false);
                      }
                      _recordHistory();
                    },
                    onPanCancel: () {
                      if (_isDraggingLayer) {
                        setState(() => _isDraggingLayer = false);
                      }
                    },
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.open_in_full_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Right: Delete Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + layerW - 22,
                top: activeMargin - 22,
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _deleteSelectedLayer,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Left: Duplicate Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin - 22,
                top: activeMargin - 22,
                width: 44,
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _duplicateSelectedLayer,
                  child: Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.copy_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ),
              ),

              // Top-Center: Rotate Handle (Large 44x44 touch area)
              Positioned(
                left: activeMargin + (layerW / 2) - 22,
                top: activeMargin - 30,
                width: 44,
                height: 44,
                child: Listener(
                  onPointerDown: (_) {
                    if (!_isDraggingLayer) {
                      setState(() => _isDraggingLayer = true);
                    }
                  },
                  onPointerUp: (_) {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                  },
                  onPointerCancel: (_) {
                    if (_isDraggingLayer) {
                      setState(() => _isDraggingLayer = false);
                    }
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (_) {
                      if (!_isDraggingLayer) {
                        setState(() => _isDraggingLayer = true);
                      }
                    },
                    onPanUpdate: (details) {
                      final idx = _layers.indexWhere((l) => l.id == layer.id);
                      if (idx < 0) return;
                      final nextRot =
                          layer.rotation + (details.delta.dx * 0.03);
                      setState(() {
                        _layers[idx] = layer.copyWith(rotation: nextRot);
                      });
                    },
                    onPanEnd: (_) {
                      if (_isDraggingLayer) {
                        setState(() => _isDraggingLayer = false);
                      }
                      _recordHistory();
                    },
                    onPanCancel: () {
                      if (_isDraggingLayer) {
                        setState(() => _isDraggingLayer = false);
                      }
                    },
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.rotate_right_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedLayerInspector(
      OverlayItemModel layer, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black45
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Inspector Header: Layer Title & Deselect button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      layer.type == OverlayItemType.signature
                          ? Icons.draw_rounded
                          : Icons.photo_library_outlined,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EDITING: ${layer.label.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedLayerId = null);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.close_rounded,
                          size: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Action Buttons Row
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildMiniActionButton(
                      icon: Icons.rotate_90_degrees_cw_rounded,
                      label: 'Rotate 90°',
                      onTap: _rotateSelectedLayer90,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: layer.hasBorder
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded,
                      label: 'Cut Border',
                      isActive: layer.hasBorder,
                      onTap: _toggleBorderSelectedLayer,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.filter_center_focus_rounded,
                      label: 'Center',
                      onTap: _centerSelectedLayer,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.fit_screen_rounded,
                      label: 'Fit Size',
                      onTap: _fitWidthSelectedLayer,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.vertical_align_top_rounded,
                      label: 'Bring Front',
                      onTap: _bringSelectedToFront,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.copy_rounded,
                      label: 'Duplicate',
                      onTap: _duplicateSelectedLayer,
                      isDark: isDark,
                    ),
                    _buildMiniActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete',
                      color: AppColors.error,
                      onTap: _deleteSelectedLayer,
                      isDark: isDark,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    Color? color,
    bool isActive = false,
  }) {
    final defaultColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final c = color ?? (isActive ? AppColors.primary : defaultColor);
    final activeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: isActive ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 19, color: c),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: c,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudioBottomToolbar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.0,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: _buildStudioToolButton(
                  context,
                  icon: Icons.add_photo_alternate_rounded,
                  label: 'ADD PHOTO',
                  isActive: false,
                  onTap: _addPhotoLayer,
                ),
              ),
              Expanded(
                child: _buildStudioToolButton(
                  context,
                  icon: Icons.draw_rounded,
                  label: 'SIGNATURE',
                  isActive: false,
                  onTap: _addSignatureLayer,
                ),
              ),
              Expanded(
                child: _buildStudioToolButton(
                  context,
                  icon: Icons.badge_rounded,
                  label: 'ID CARDS',
                  badgeText: 'A4',
                  isActive: false,
                  onTap: _handleIdCardDuo,
                ),
              ),
              Expanded(
                child: _buildStudioToolButton(
                  context,
                  icon: Icons.description_outlined,
                  label: 'FORMAT',
                  isActive: _selectedLayerId == null,
                  onTap: () {
                    if (_selectedLayerId != null) {
                      setState(() => _selectedLayerId = null);
                    }
                  },
                ),
              ),
              Expanded(
                child: _buildStudioToolButton(
                  context,
                  icon: Icons.layers_rounded,
                  label: _layers.isNotEmpty ? 'LAYERS (${_layers.length})' : 'LAYERS',
                  isActive: _selectedLayerId != null,
                  onTap: () {
                    if (_selectedLayerId != null) {
                      setState(() => _selectedLayerId = null);
                    } else if (_layers.isNotEmpty) {
                      setState(() => _selectedLayerId = _layers.first.id);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudioToolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark
        ? AppColors.primary.withValues(alpha: 0.22)
        : AppColors.primary.withValues(alpha: 0.12);
    final unselectedColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    const selectedColor = AppColors.primary;

    final iconSize =
        context.adaptiveIconSize(22, tabletSize: 26, largeTabletSize: 28);
    final labelFontSize =
        context.adaptiveFontSize(9.5, tabletSize: 11.5, largeTabletSize: 12.5);

    return Material(
      color: isActive ? activeBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: context.isMediumOrWider ? 8 : 6,
            horizontal: context.isMediumOrWider ? 6 : 2,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: iconSize,
                    color: isActive ? selectedColor : unselectedColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: labelFontSize,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                      color: isActive ? selectedColor : unselectedColor,
                    ),
                  ),
                ],
              ),
              if (badgeText != null)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _A4SheetGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle dotted margin guide line
    final marginPaint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final margin = size.width * 0.05;
    canvas.drawRect(
      Rect.fromLTWH(
        margin,
        margin,
        size.width - (margin * 2),
        size.height - (margin * 2),
      ),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
