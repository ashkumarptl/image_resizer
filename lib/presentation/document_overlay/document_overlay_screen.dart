import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../core/constants/app_colors.dart';
import '../../services/image_service/document_overlay_compositor.dart';
import '../widgets/discard_changes_sheet.dart';
import '../widgets/image_source_picker_sheet.dart';
import 'models/overlay_history_state.dart';
import 'models/overlay_item_model.dart';
import 'widgets/canvas_grid_painter.dart';
import 'widgets/floating_zoom_dock.dart';
import 'widgets/id_card_duo_picker_sheet.dart';
import 'widgets/overlay_canvas_layer_widget.dart';
import 'widgets/overlay_export_modal.dart';
import 'widgets/overlay_layer_inspector_dock.dart';
import 'widgets/overlay_page_format_dock.dart';
import 'widgets/overlay_signature_source_modal.dart';
import 'widgets/overlay_studio_bottom_toolbar.dart';
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
  final List<OverlayHistoryState> _history = [];
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
    final snapshot = OverlayHistoryState(
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
    if (_layers.isEmpty && !_baseDocumentAsLayer && !_isBaseDocumentDeleted) {
      return;
    }
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
    final isZoomed =
        (scale - 1.0).abs() > 0.05 ||
        !_transformationController.value.isIdentity();
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

      // On A4 paper formats, automatically ensure base document is active layer
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
          _selectedLayerId =
              _baseDocumentLayerId ??
              (_layers.isNotEmpty ? _layers.first.id : null);
        }
      }

      // Preserve aspect ratio and safe positioning for all layers on new canvas
      if (_layers.isNotEmpty && oldCanvasRatio > 0 && newCanvasRatio > 0) {
        _layers = _layers.map((layer) {
          final layerRatio = layer.aspectRatio > 0 ? layer.aspectRatio : 1.0;

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
          final clampedX = layer.normalizedX.clamp(
            halfW + 0.02,
            1.0 - halfW - 0.02,
          );
          final clampedY = layer.normalizedY.clamp(
            halfH + 0.02,
            1.0 - halfH - 0.02,
          );

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
        // Center layer on canvas and re-select
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
      _layers[idx] = _layers[idx].copyWith(normalizedX: 0.5, normalizedY: 0.5);
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
    final source = await OverlaySignatureSourceModal.show(context);
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

    double ratio = 2.0;
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
      normalizedY: 0.85,
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

    final targetSize = duoResult.isVertical
        ? CanvasPageSize.a4Portrait
        : CanvasPageSize.a4Landscape;
    if (_pageSize != targetSize) {
      _changePageSize(targetSize);
    }

    const idRatio = 85.6 / 54.0;
    final canvasRatio = _currentCanvasRatio;

    List<OverlayItemModel> newLayers = [];

    if (duoResult.isVertical) {
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
      final isBaseDoc =
          _selectedLayerId == _baseDocumentLayerId ||
          (_layers.any(
            (l) =>
                l.id == _selectedLayerId &&
                widget.initialImage != null &&
                l.file.path == widget.initialImage!.path,
          ));

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
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    HapticFeedback.lightImpact();
    final cur = _layers[idx];
    final copy = cur.copyWith(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      normalizedX: (cur.normalizedX + 0.05).clamp(0.1, 0.9),
      normalizedY: (cur.normalizedY + 0.05).clamp(0.1, 0.9),
    );
    setState(() {
      _layers.add(copy);
      _selectedLayerId = copy.id;
    });
    _recordHistory();
  }

  void _rotateSelectedLayer90() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _layers[idx] = _layers[idx].copyWith(
        rotation: _layers[idx].rotation + (3.141592653589793 / 2),
      );
    });
    _recordHistory();
  }

  void _toggleBorderSelectedLayer() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0) return;
    HapticFeedback.selectionClick();
    setState(() {
      _layers[idx] = _layers[idx].copyWith(hasBorder: !_layers[idx].hasBorder);
    });
    _recordHistory();
  }

  void _bringSelectedToFront() {
    if (_selectedLayerId == null) return;
    final idx = _layers.indexWhere((l) => l.id == _selectedLayerId);
    if (idx < 0 || idx == _layers.length - 1) return;
    HapticFeedback.selectionClick();
    setState(() {
      final layer = _layers.removeAt(idx);
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
        OverlayExportModal.show(context, result);
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

  Future<void> _handlePopScope(bool didPop) async {
    if (didPop) return;
    if (_layers.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final discard = await DiscardChangesSheet.show(
      context,
      title: 'Discard Document Layout?',
      message:
          'You have placed items on the canvas. Are you sure you want to leave without saving?',
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
    final scaffoldBg = isDark
        ? AppColors.backgroundDark
        : const Color(0xFFF6F8FB);
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
              widget.initialImage != null
                  ? 'Add Photo Studio'
                  : 'A4 Print Studio',
              style:
                  (Theme.of(context).appBarTheme.titleTextStyle ??
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
              onPressed: (_isProcessing || !hasChanges)
                  ? null
                  : _resetAllLayers,
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
                          horizontal: 14,
                          vertical: 0,
                        ),
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
                          _viewportSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );

                          final canvasRatio = _currentCanvasRatio;
                          final availableW = (constraints.maxWidth - 32).clamp(
                            100.0,
                            constraints.maxWidth,
                          );
                          final availableH = (constraints.maxHeight - 32).clamp(
                            100.0,
                            constraints.maxHeight,
                          );

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
                      FloatingZoomDock(
                        transformationController: _transformationController,
                        onResetZoom: _resetZoom,
                        onZoomIn: _zoomIn,
                        onZoomOut: _zoomOut,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Middle Dock: Selected Layer Inspector (if selected) OR Page Format Dock (if none)
              if (selectedLayer != null)
                OverlayLayerInspectorDock(
                  layer: selectedLayer,
                  isDark: isDark,
                  onDeselect: () => setState(() => _selectedLayerId = null),
                  onRotate90: _rotateSelectedLayer90,
                  onToggleBorder: _toggleBorderSelectedLayer,
                  onCenter: _centerSelectedLayer,
                  onFitSize: _fitWidthSelectedLayer,
                  onBringToFront: _bringSelectedToFront,
                  onDuplicate: _duplicateSelectedLayer,
                  onDelete: _deleteSelectedLayer,
                )
              else
                OverlayPageFormatDock(
                  pageSize: _pageSize,
                  hasInitialImage: widget.initialImage != null,
                  isBaseDocumentDeleted: _isBaseDocumentDeleted,
                  baseDocumentAsLayer: _baseDocumentAsLayer,
                  isDark: isDark,
                  onPageSizeChanged: _changePageSize,
                  onToggleBaseDocumentAsLayer: _toggleBaseDocumentAsLayer,
                ),

              // Studio Bottom Toolbar
              OverlayStudioBottomToolbar(
                isDark: isDark,
                isLayerSelected: _selectedLayerId != null,
                layerCount: _layers.length,
                onAddPhoto: _addPhotoLayer,
                onAddSignature: _addSignatureLayer,
                onIdCardDuo: _handleIdCardDuo,
                onFormatTap: () {
                  if (_selectedLayerId != null) {
                    setState(() => _selectedLayerId = null);
                  }
                },
                onLayersTap: () {
                  if (_selectedLayerId != null) {
                    setState(() => _selectedLayerId = null);
                  } else if (_layers.isNotEmpty) {
                    setState(() => _selectedLayerId = _layers.first.id);
                  }
                },
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
                    cacheWidth: 1400,
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
                    painter: const CanvasGridPainter(),
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
                        cacheWidth: 1400,
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
                  painter: const CanvasGridPainter(),
                  size: Size(canvasWidth, canvasHeight),
                ),
              ),
            ],

            // Render Layers
            for (final layer in _layers)
              OverlayCanvasLayerWidget(
                layer: layer,
                isSelected: layer.id == _selectedLayerId,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                currentCanvasRatio: _currentCanvasRatio,
                isDark: isDark,
                onTap: () => setState(() => _selectedLayerId = layer.id),
                onMove: (dx, dy) {
                  final idx = _layers.indexWhere((l) => l.id == layer.id);
                  if (idx < 0) return;
                  setState(() {
                    _layers[idx] = layer.copyWith(
                      normalizedX: (layer.normalizedX + dx).clamp(0.05, 0.95),
                      normalizedY: (layer.normalizedY + dy).clamp(0.05, 0.95),
                    );
                  });
                },
                onMoveEnd: _recordHistory,
                onResize: (newW, newH, newX, newY) {
                  final idx = _layers.indexWhere((l) => l.id == layer.id);
                  if (idx < 0) return;
                  setState(() {
                    _layers[idx] = layer.copyWith(
                      normalizedWidth: newW,
                      normalizedHeight: newH,
                      normalizedX: newX,
                      normalizedY: newY,
                    );
                  });
                },
                onResizeEnd: _recordHistory,
                onRotate: (newRot) {
                  final idx = _layers.indexWhere((l) => l.id == layer.id);
                  if (idx < 0) return;
                  setState(() {
                    _layers[idx] = layer.copyWith(rotation: newRot);
                  });
                },
                onRotateEnd: _recordHistory,
                onDelete: _deleteSelectedLayer,
                onDuplicate: _duplicateSelectedLayer,
                onDragStateChanged: (isDragging) {
                  if (_isDraggingLayer != isDragging) {
                    setState(() => _isDraggingLayer = isDragging);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
