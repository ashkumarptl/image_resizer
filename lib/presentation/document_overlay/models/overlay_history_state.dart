import '../../../services/image_service/document_overlay_compositor.dart';
import 'overlay_item_model.dart';

/// Represents an immutable snapshot of the overlay canvas state for Undo / Redo.
class OverlayHistoryState {
  final List<OverlayItemModel> layers;
  final bool isBaseDocumentDeleted;
  final bool baseDocumentAsLayer;
  final String? baseDocumentLayerId;
  final CanvasPageSize pageSize;

  const OverlayHistoryState({
    required this.layers,
    required this.isBaseDocumentDeleted,
    required this.baseDocumentAsLayer,
    required this.baseDocumentLayerId,
    required this.pageSize,
  });
}
