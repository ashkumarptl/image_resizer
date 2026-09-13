import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

typedef ReorderItemBuilder =
    Widget Function(BuildContext context, int index, bool isDragging);

typedef PlaceholderBuilder =
    Widget Function(BuildContext context, double width, double height);

typedef DragStackBuilder =
    Widget Function(
      BuildContext context,
      List<int> indexes,
      double width,
      double height,
    );

/// A high-performance, smooth drag-to-reorder grid supporting single-item
/// and multi-select group reordering designed for modern scanner and gallery apps.
///
/// Features:
/// - Single-item drag or multi-select group drag (CamScanner-style).
/// - Long-press to lift with smooth scale (1.05x) and elevation.
/// - Stacked drag preview with subtle rotation (-2.3° to +2.3°) and count badge.
/// - Exact slot-based animated placeholder gaps for all dragged items.
/// - Smooth animated repositioning of surrounding items as the gap moves (200ms easeOutCubic).
/// - Settle animation into the drop slot upon release.
/// - Smooth cancel animation back to origin if drag is aborted.
/// - Edge auto-scrolling when hovering near top or bottom edges.
class SmoothReorderableGrid extends StatefulWidget {
  final int itemCount;
  final ReorderItemBuilder itemBuilder;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final void Function(List<int> newOrder)? onGroupReorder;
  final void Function(int index)? onTapItem;
  final void Function(int index)? onLongPressSelect;
  final Set<int> selectedIndexes;
  final bool enableMultiSelection;
  final DragStackBuilder? dragStackBuilder;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsetsGeometry padding;
  final ScrollController? scrollController;
  final PlaceholderBuilder? placeholderBuilder;
  final Duration animationDuration;
  final Curve animationCurve;
  final bool enableReorder;
  final Key Function(int index)? itemKeyBuilder;

  const SmoothReorderableGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onReorder,
    this.onGroupReorder,
    this.onTapItem,
    this.onLongPressSelect,
    this.selectedIndexes = const {},
    this.enableMultiSelection = true,
    this.dragStackBuilder,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 12.0,
    this.mainAxisSpacing = 12.0,
    this.childAspectRatio = 0.68,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 100),
    this.scrollController,
    this.placeholderBuilder,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
    this.enableReorder = true,
    this.itemKeyBuilder,
  });

  @override
  State<SmoothReorderableGrid> createState() => _SmoothReorderableGridState();
}

class _SmoothReorderableGridState extends State<SmoothReorderableGrid>
    with TickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _ownsScrollController = false;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _viewportKey = GlobalKey();

  // Drag state
  List<int> _draggedIndexes = [];
  int? _primaryDraggedIndex;
  int? _targetInsertionIndex;
  Offset?
  _dragPosition; // top-left position of the floating front card in Stack coordinates
  Offset _touchOffset =
      Offset.zero; // offset from card top-left to initial touch
  Offset? _lastGlobalPos;

  // Geometry cache for current build frame
  double _itemWidth = 0.0;
  double _itemHeight = 0.0;
  EdgeInsets _insets = EdgeInsets.zero;

  // Animation controllers
  late final AnimationController _liftController;
  late final Animation<double> _liftAnimation;

  late final AnimationController _settleController;
  late final Animation<double> _settleAnimation;
  Offset? _settleStartPos;
  Offset? _settleTargetPos;
  bool _isSettling = false;

  // Auto-scroll
  Timer? _autoScrollTimer;
  double _autoScrollVelocity = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
    } else {
      _scrollController = ScrollController();
      _ownsScrollController = true;
    }

    _liftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _liftAnimation = CurvedAnimation(
      parent: _liftController,
      curve: Curves.easeOutCubic,
    );

    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _settleAnimation = CurvedAnimation(
      parent: _settleController,
      curve: Curves.easeOutCubic,
    );
    _settleController.addListener(() {
      if (_isSettling) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant SmoothReorderableGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsScrollController) {
        _scrollController.dispose();
        _ownsScrollController = false;
      }
      if (widget.scrollController != null) {
        _scrollController = widget.scrollController!;
      } else {
        _scrollController = ScrollController();
        _ownsScrollController = true;
      }
    }

    if (_draggedIndexes.any((idx) => idx >= widget.itemCount)) {
      _cleanupDrag();
    }
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _liftController.dispose();
    _settleController.dispose();
    if (_ownsScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  /// Calculates top-left coordinate of a slot in Stack coordinates.
  Offset _getSlotPosition(
    int slotIndex,
    double itemWidth,
    double itemHeight,
    EdgeInsets insets,
  ) {
    final col = slotIndex % widget.crossAxisCount;
    final row = slotIndex ~/ widget.crossAxisCount;
    final x = insets.left + col * (itemWidth + widget.crossAxisSpacing);
    final y = insets.top + row * (itemHeight + widget.mainAxisSpacing);
    return Offset(x, y);
  }

  /// Returns indices of items currently remaining in the grid (not being dragged).
  List<int> _buildRemainingIndexes() {
    final draggedSet = _draggedIndexes.toSet();
    final remaining = <int>[];
    for (int i = 0; i < widget.itemCount; i++) {
      if (!draggedSet.contains(i)) {
        remaining.add(i);
      }
    }
    return remaining;
  }

  /// Derives the resulting full order if the dragged group is inserted at [insertionIndex].
  List<int> _buildVisualOrder(int insertionIndex) {
    final remaining = _buildRemainingIndexes();
    final clampedInsertion = insertionIndex.clamp(0, remaining.length);
    final order = List<int>.from(remaining);
    order.insertAll(clampedInsertion, _draggedIndexes);
    return order;
  }

  /// Calculates the visual grid slot for every item index in [0 .. widget.itemCount - 1].
  ///
  /// - Remaining items before [insertionIndex] keep their compact slot index.
  /// - Remaining items at or after [insertionIndex] are shifted right by the group size.
  /// - Dragged items are mapped to the placeholder slots `[insertionIndex .. insertionIndex + groupSize - 1]`.
  Map<int, int> _calculateVisualSlots({
    required List<int> draggedIndexes,
    required int insertionIndex,
  }) {
    final slotMap = <int, int>{};
    if (draggedIndexes.isEmpty) {
      for (int i = 0; i < widget.itemCount; i++) {
        slotMap[i] = i;
      }
      return slotMap;
    }

    final draggedSet = draggedIndexes.toSet();
    final remaining = <int>[];
    for (int i = 0; i < widget.itemCount; i++) {
      if (!draggedSet.contains(i)) {
        remaining.add(i);
      }
    }

    final clampedInsertion = insertionIndex.clamp(0, remaining.length);
    final groupCount = draggedIndexes.length;

    // Remaining items slots
    for (int r = 0; r < remaining.length; r++) {
      final originalIndex = remaining[r];
      if (r < clampedInsertion) {
        slotMap[originalIndex] = r;
      } else {
        slotMap[originalIndex] = r + groupCount;
      }
    }

    // Dragged items slots (matching placeholder gap locations)
    for (int g = 0; g < draggedIndexes.length; g++) {
      slotMap[draggedIndexes[g]] = clampedInsertion + g;
    }

    return slotMap;
  }

  /// Calculates the target insertion index in the remaining items based on pointer position.
  int _calculateInsertionIndex(Offset globalPos) {
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return _targetInsertionIndex ?? 0;

    final stackLocal = stackBox.globalToLocal(globalPos);
    final cardCenterX = (_dragPosition?.dx ?? stackLocal.dx) + _itemWidth / 2;
    final cardCenterY = (_dragPosition?.dy ?? stackLocal.dy) + _itemHeight / 2;

    final col =
        ((cardCenterX - _insets.left) / (_itemWidth + widget.crossAxisSpacing))
            .floor()
            .clamp(0, widget.crossAxisCount - 1);
    final row =
        ((cardCenterY - _insets.top) / (_itemHeight + widget.mainAxisSpacing))
            .floor();

    final hoveredSlot = row * widget.crossAxisCount + col;

    final primaryOffset = _draggedIndexes.indexOf(
      _primaryDraggedIndex ?? _draggedIndexes.first,
    );
    final offsetInGroup = primaryOffset >= 0 ? primaryOffset : 0;

    final targetStartSlot = hoveredSlot - offsetInGroup;
    final remainingCount = widget.itemCount - _draggedIndexes.length;

    return targetStartSlot.clamp(0, remainingCount);
  }

  bool _areListsEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _onLongPressStart(int index, LongPressStartDetails details) {
    if (!widget.enableReorder || _isSettling || widget.itemCount <= 1) return;

    HapticFeedback.selectionClick();

    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final stackLocal = stackBox.globalToLocal(details.globalPosition);
    final slotPos = _getSlotPosition(index, _itemWidth, _itemHeight, _insets);

    _touchOffset = stackLocal - slotPos;
    _primaryDraggedIndex = index;

    // Determine dragged group based on multi-selection state
    if (widget.enableMultiSelection && widget.selectedIndexes.contains(index)) {
      _draggedIndexes = widget.selectedIndexes.toList()..sort();
    } else {
      if (widget.enableMultiSelection && widget.onLongPressSelect != null) {
        widget.onLongPressSelect!(index);
      }
      _draggedIndexes = [index];
    }

    final remaining = _buildRemainingIndexes();
    _targetInsertionIndex = remaining
        .where((r) => r < index)
        .length
        .clamp(0, remaining.length);

    _dragPosition = slotPos;
    _lastGlobalPos = details.globalPosition;
    _isSettling = false;

    _liftController.forward(from: 0.0);
    setState(() {});
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggedIndexes.isEmpty || _isSettling) return;

    _lastGlobalPos = details.globalPosition;
    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final stackLocal = stackBox.globalToLocal(details.globalPosition);
    _dragPosition = stackLocal - _touchOffset;

    _updateHoverSlot(details.globalPosition);
    _checkAutoScroll(details.globalPosition);
    setState(() {});
  }

  void _updateHoverSlot(Offset globalPos) {
    if (_draggedIndexes.isEmpty || _isSettling) return;

    final newInsertionIndex = _calculateInsertionIndex(globalPos);

    if (newInsertionIndex != _targetInsertionIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _targetInsertionIndex = newInsertionIndex;
      });
    }
  }

  void _checkAutoScroll(Offset globalPos) {
    final RenderBox? viewportBox =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewportBox == null || !_scrollController.hasClients) return;

    final viewportLocal = viewportBox.globalToLocal(globalPos);
    final viewportHeight = viewportBox.size.height;
    const edgeThreshold = 80.0;
    const maxStep = 10.0;

    if (viewportLocal.dy < edgeThreshold && viewportLocal.dy >= -20) {
      final proximity = ((edgeThreshold - viewportLocal.dy) / edgeThreshold)
          .clamp(0.1, 1.0);
      _autoScrollVelocity = -maxStep * proximity;
      _startAutoScroll();
    } else if (viewportLocal.dy > viewportHeight - edgeThreshold &&
        viewportLocal.dy <= viewportHeight + 20) {
      final proximity =
          ((viewportLocal.dy - (viewportHeight - edgeThreshold)) /
                  edgeThreshold)
              .clamp(0.1, 1.0);
      _autoScrollVelocity = maxStep * proximity;
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    if (_autoScrollTimer != null) return;
    _autoScrollTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!_scrollController.hasClients || _autoScrollVelocity == 0) return;
      final target = (_scrollController.offset + _autoScrollVelocity).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.jumpTo(target);

      if (_lastGlobalPos != null) {
        final RenderBox? stackBox =
            _stackKey.currentContext?.findRenderObject() as RenderBox?;
        if (stackBox != null) {
          final stackLocal = stackBox.globalToLocal(_lastGlobalPos!);
          _dragPosition = stackLocal - _touchOffset;
        }
        _updateHoverSlot(_lastGlobalPos!);
        setState(() {});
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _autoScrollVelocity = 0.0;
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _stopAutoScroll();
    if (_draggedIndexes.isEmpty || _targetInsertionIndex == null) {
      _cleanupDrag();
      return;
    }

    final oldIndexes = List<int>.from(_draggedIndexes);
    final insertion = _targetInsertionIndex!;
    final primaryIndex = _primaryDraggedIndex ?? oldIndexes.first;
    final primaryOffset = oldIndexes.indexOf(primaryIndex);
    final offsetInGroup = primaryOffset >= 0 ? primaryOffset : 0;

    final targetSlot = insertion + offsetInGroup;
    final targetPos = _getSlotPosition(
      targetSlot,
      _itemWidth,
      _itemHeight,
      _insets,
    );

    _settleStartPos = _dragPosition ?? targetPos;
    _settleTargetPos = targetPos;
    _isSettling = true;

    _settleController.forward(from: 0.0).then((_) {
      if (!mounted) return;

      final newOrder = _buildVisualOrder(insertion);
      final didChange = !_areListsEqual(
        List.generate(widget.itemCount, (i) => i),
        newOrder,
      );

      if (didChange) {
        if (widget.onGroupReorder != null) {
          widget.onGroupReorder!(newOrder);
        } else if (oldIndexes.length == 1) {
          widget.onReorder?.call(oldIndexes.first, insertion);
        }
      }

      _cleanupDrag();
    });
  }

  void _onLongPressCancel() {
    _stopAutoScroll();
    if (_draggedIndexes.isEmpty) {
      _cleanupDrag();
      return;
    }

    final primaryIndex = _primaryDraggedIndex ?? _draggedIndexes.first;
    final origPos = _getSlotPosition(
      primaryIndex,
      _itemWidth,
      _itemHeight,
      _insets,
    );

    _settleStartPos = _dragPosition ?? origPos;
    _settleTargetPos = origPos;
    _isSettling = true;

    _settleController.forward(from: 0.0).then((_) {
      if (!mounted) return;
      _cleanupDrag();
    });
  }

  void _cleanupDrag() {
    _liftController.reset();
    _settleController.reset();
    setState(() {
      _draggedIndexes = [];
      _primaryDraggedIndex = null;
      _targetInsertionIndex = null;
      _dragPosition = null;
      _lastGlobalPos = null;
      _settleStartPos = null;
      _settleTargetPos = null;
      _isSettling = false;
    });
  }

  Widget _buildDefaultPlaceholder(double width, double height, bool isDark) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 1.6,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.move_down_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildDragStack(BuildContext context, double width, double height) {
    if (widget.dragStackBuilder != null) {
      return widget.dragStackBuilder!(context, _draggedIndexes, width, height);
    }

    final count = _draggedIndexes.length;
    if (count == 1) {
      return widget.itemBuilder(context, _draggedIndexes.first, true);
    }

    final frontIndex = _primaryDraggedIndex ?? _draggedIndexes.first;
    final otherIndexes = _draggedIndexes
        .where((idx) => idx != frontIndex)
        .toList();

    final backCards = <Widget>[];

    // Card 3: Deepest background card (if >= 3 items)
    if (otherIndexes.length >= 2) {
      final card3Index = otherIndexes[1];
      backCards.add(
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(-5.0, -5.0, 0.0)
            ..rotateZ(-0.04), // ~ -2.3 degrees
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: widget.itemBuilder(context, card3Index, true),
          ),
        ),
      );
    }

    // Card 2: Middle background card
    if (otherIndexes.isNotEmpty) {
      final card2Index = otherIndexes[0];
      backCards.add(
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.translationValues(5.0, -4.0, 0.0)
            ..rotateZ(0.04), // ~ +2.3 degrees
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: widget.itemBuilder(context, card2Index, true),
          ),
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background rotated cards
          ...backCards,

          // Front card
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: widget.itemBuilder(context, frontIndex, true),
            ),
          ),

          // Count badge (CamScanner style pill)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.collections_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _insets = widget.padding.resolve(Directionality.of(context));

    return LayoutBuilder(
      key: _viewportKey,
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final availableWidth = totalWidth - _insets.left - _insets.right;
        _itemWidth =
            (availableWidth -
                (widget.crossAxisCount - 1) * widget.crossAxisSpacing) /
            widget.crossAxisCount;
        _itemHeight = _itemWidth / widget.childAspectRatio;

        final rowCount =
            (widget.itemCount + widget.crossAxisCount - 1) ~/
            widget.crossAxisCount;
        final totalHeight = rowCount == 0
            ? _insets.vertical
            : _insets.top +
                  _insets.bottom +
                  rowCount * _itemHeight +
                  (rowCount - 1) * widget.mainAxisSpacing;

        // Current floating position and scale
        Offset floatingPos = Offset.zero;
        double floatingScale = 1.0;

        if (_isSettling &&
            _settleStartPos != null &&
            _settleTargetPos != null) {
          floatingPos = Offset.lerp(
            _settleStartPos!,
            _settleTargetPos!,
            _settleAnimation.value,
          )!;
          floatingScale = 1.05 - (0.05 * _settleAnimation.value);
        } else if (_dragPosition != null) {
          floatingPos = _dragPosition!;
          floatingScale = 1.0 + (0.05 * _liftAnimation.value);
        }

        final visualSlots = _calculateVisualSlots(
          draggedIndexes: _draggedIndexes,
          insertionIndex: _targetInsertionIndex ?? 0,
        );

        return SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: SizedBox(
            height: totalHeight,
            width: totalWidth,
            child: Stack(
              key: _stackKey,
              clipBehavior: Clip.none,
              children: [
                // 1. Placeholder Gaps (Rendered under items)
                if (_draggedIndexes.isNotEmpty && _targetInsertionIndex != null)
                  for (int g = 0; g < _draggedIndexes.length; g++)
                    AnimatedPositioned(
                      key: g == 0
                          ? const ValueKey('grid_placeholder_gap')
                          : ValueKey('grid_placeholder_gap_$g'),
                      duration: widget.animationDuration,
                      curve: widget.animationCurve,
                      left: _getSlotPosition(
                        _targetInsertionIndex! + g,
                        _itemWidth,
                        _itemHeight,
                        _insets,
                      ).dx,
                      top: _getSlotPosition(
                        _targetInsertionIndex! + g,
                        _itemWidth,
                        _itemHeight,
                        _insets,
                      ).dy,
                      width: _itemWidth,
                      height: _itemHeight,
                      child: widget.placeholderBuilder != null
                          ? widget.placeholderBuilder!(
                              context,
                              _itemWidth,
                              _itemHeight,
                            )
                          : _buildDefaultPlaceholder(
                              _itemWidth,
                              _itemHeight,
                              isDark,
                            ),
                    ),

                // 2. Normal / Repositioning Grid Items
                for (int i = 0; i < widget.itemCount; i++)
                  Builder(
                    key: widget.itemKeyBuilder != null
                        ? widget.itemKeyBuilder!(i)
                        : ValueKey('grid_item_slot_$i'),
                    builder: (context) {
                      final isDragged = _draggedIndexes.contains(i);
                      final slot = visualSlots[i] ?? i;
                      final pos = _getSlotPosition(
                        slot,
                        _itemWidth,
                        _itemHeight,
                        _insets,
                      );

                      return AnimatedPositioned(
                        duration: widget.animationDuration,
                        curve: widget.animationCurve,
                        left: pos.dx,
                        top: pos.dy,
                        width: _itemWidth,
                        height: _itemHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTapItem?.call(i),
                          onLongPressStart: widget.enableReorder
                              ? (details) => _onLongPressStart(i, details)
                              : null,
                          onLongPressMoveUpdate: widget.enableReorder
                              ? _onLongPressMoveUpdate
                              : null,
                          onLongPressEnd: widget.enableReorder
                              ? _onLongPressEnd
                              : null,
                          onLongPressCancel: widget.enableReorder
                              ? _onLongPressCancel
                              : null,
                          child: IgnorePointer(
                            ignoring: isDragged,
                            child: Opacity(
                              opacity: isDragged ? 0.0 : 1.0,
                              child: widget.itemBuilder(context, i, false),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                // 3. Floating Lifted / Settling Stack (Rendered on top of everything)
                if (_draggedIndexes.isNotEmpty)
                  Positioned(
                    left: floatingPos.dx,
                    top: floatingPos.dy,
                    width: _itemWidth,
                    height: _itemHeight,
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: floatingScale,
                        alignment: Alignment.center,
                        child: _buildDragStack(
                          context,
                          _itemWidth,
                          _itemHeight,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
