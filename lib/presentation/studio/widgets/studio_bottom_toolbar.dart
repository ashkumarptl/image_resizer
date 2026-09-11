import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

enum StudioActiveTool {
  none,
  rotate,
  flip,
  crop,
  compress,
  resize,
  format,
  bgRemover,
}

class StudioBottomToolbar extends StatefulWidget {
  final StudioActiveTool activeTool;
  final VoidCallback onRotate;
  final VoidCallback onFlip;
  final VoidCallback onCrop;
  final VoidCallback onCompress;
  final VoidCallback onResize;
  final VoidCallback onFormat;
  final VoidCallback onBgRemover;
  final VoidCallback? onCompressLongPress;
  final bool hasFlipped;
  final bool hasRotated;
  final bool hasCropped;
  final bool hasRemovedBg;
  final bool enableSwipeAnimation;

  const StudioBottomToolbar({
    super.key,
    required this.activeTool,
    required this.onRotate,
    required this.onFlip,
    required this.onCrop,
    required this.onCompress,
    required this.onResize,
    required this.onFormat,
    required this.onBgRemover,
    this.onCompressLongPress,
    this.hasFlipped = false,
    this.hasRotated = false,
    this.hasCropped = false,
    this.hasRemovedBg = false,
    this.enableSwipeAnimation = true,
  });

  @override
  State<StudioBottomToolbar> createState() => _StudioBottomToolbarState();
}

class _StudioBottomToolbarState extends State<StudioBottomToolbar>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  bool _canScrollRight = false;
  bool _canScrollLeft = false;
  bool _showSwipeHint = false;
  Timer? _peekTimer;
  Timer? _peekHoldTimer;

  late AnimationController _hintAnimController;
  late Animation<Offset> _hintSlideAnim;
  late Animation<double> _hintFadeAnim;

  @override
  void initState() {
    super.initState();
    _hintAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _hintSlideAnim = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0.25, 0), end: const Offset(-0.25, 0))
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(-0.25, 0), end: const Offset(0.1, 0))
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_hintAnimController);

    _hintFadeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_hintAnimController);

    _hintAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _showSwipeHint = false);
      }
    });

    _scrollController.addListener(_updateScrollIndicators);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePeekAnimation();
    });
  }

  @override
  void didUpdateWidget(StudioBottomToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeTool != widget.activeTool) {
      _scrollToActiveTool();
    }
  }

  void _scrollToActiveTool() {
    if (!mounted || !_scrollController.hasClients) return;
    if (widget.activeTool == StudioActiveTool.flip || widget.activeTool == StudioActiveTool.rotate) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } else if (widget.activeTool == StudioActiveTool.compress || widget.activeTool == StudioActiveTool.resize) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _schedulePeekAnimation() {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest || !widget.enableSwipeAnimation) {
      _updateScrollIndicators();
      return;
    }

    _peekTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted || !_scrollController.hasClients) return;
      _updateScrollIndicators();

      if (_scrollController.position.maxScrollExtent > 15) {
        setState(() => _showSwipeHint = true);
        _hintAnimController.forward(from: 0.0);

        _scrollController.animateTo(
          55.0,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
        ).then((_) {
          if (!mounted || !_scrollController.hasClients) return;
          _peekHoldTimer = Timer(const Duration(milliseconds: 300), () {
            if (!mounted || !_scrollController.hasClients) return;
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOutCubic,
            );
          });
        });
      }
    });
  }

  void _updateScrollIndicators() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = _scrollController.offset;
    final canRight = maxScroll > 10 && offset < maxScroll - 5;
    final canLeft = offset > 5;
    if (canRight != _canScrollRight || canLeft != _canScrollLeft) {
      setState(() {
        _canScrollRight = canRight;
        _canScrollLeft = canLeft;
      });
    }
  }

  void _dismissHint() {
    if (_showSwipeHint) {
      _peekTimer?.cancel();
      _peekHoldTimer?.cancel();
      _hintAnimController.stop();
      setState(() => _showSwipeHint = false);
    }
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    _peekHoldTimer?.cancel();
    _hintAnimController.dispose();
    _scrollController.removeListener(_updateScrollIndicators);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Stack(
              alignment: Alignment.center,
              children: [
            // Scrollable Tools Row
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification) {
                  _dismissHint();
                }
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildToolButton(
                        context,
                        icon: Icons.compress_rounded,
                        label: 'COMPRESS',
                        isActive: widget.activeTool == StudioActiveTool.compress,
                        onTap: () {
                          _dismissHint();
                          widget.onCompress();
                        },
                        onLongPress: widget.onCompressLongPress,
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.open_in_full_rounded,
                        label: 'RESIZE',
                        isActive: widget.activeTool == StudioActiveTool.resize,
                        onTap: () {
                          _dismissHint();
                          widget.onResize();
                        },
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.tune_rounded,
                        label: 'FORMAT',
                        isActive: widget.activeTool == StudioActiveTool.format,
                        onTap: () {
                          _dismissHint();
                          widget.onFormat();
                        },
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.auto_fix_high_rounded,
                        label: 'BG REMOVE',
                        isActive: widget.activeTool == StudioActiveTool.bgRemover || widget.hasRemovedBg,
                        badgeText: widget.hasRemovedBg ? 'DONE' : null,
                        onTap: () {
                          _dismissHint();
                          widget.onBgRemover();
                        },
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.crop_outlined,
                        label: 'CROP',
                        isActive: widget.activeTool == StudioActiveTool.crop || widget.hasCropped,
                        badgeText: widget.hasCropped ? 'DONE' : null,
                        onTap: () {
                          _dismissHint();
                          widget.onCrop();
                        },
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.rotate_90_degrees_cw_outlined,
                        label: 'ROTATE',
                        isActive: widget.activeTool == StudioActiveTool.rotate || widget.hasRotated,
                        badgeText: widget.hasRotated ? 'ACTIVE' : null,
                        onTap: () {
                          _dismissHint();
                          widget.onRotate();
                        },
                      ),
                      _buildToolButton(
                        context,
                        icon: Icons.flip_outlined,
                        label: 'FLIP',
                        isActive: widget.activeTool == StudioActiveTool.flip || widget.hasFlipped,
                        badgeText: widget.hasFlipped ? 'FLIPPED' : null,
                        onTap: () {
                          _dismissHint();
                          widget.onFlip();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Left Edge Scroll Indicator & Tappable Chevron
            _buildScrollEdgeIndicator(isRight: false, isDark: isDark),

            // Right Edge Scroll Indicator & Tappable Chevron
            _buildScrollEdgeIndicator(isRight: true, isDark: isDark),

            // Animated Swipe Cue Banner
            if (_showSwipeHint)
              Positioned(
                top: 4,
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _hintFadeAnim,
                    child: SlideTransition(
                      position: _hintSlideAnim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24, width: 0.8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe_left_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Swipe for more tools',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            SizedBox(width: 3),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 8,
                              color: Colors.white70,
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildScrollEdgeIndicator({required bool isRight, required bool isDark}) {
    final canScroll = isRight ? _canScrollRight : _canScrollLeft;
    final bgColor = isDark ? AppColors.surfaceDark : AppColors.primary;

    return Positioned(
      left: isRight ? null : 0,
      right: isRight ? 0 : null,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !canScroll,
        child: AnimatedOpacity(
          opacity: canScroll ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: () {
              if (!_scrollController.hasClients) return;
              _dismissHint();
              final target = isRight
                  ? (_scrollController.offset + 120).clamp(0.0, _scrollController.position.maxScrollExtent)
                  : (_scrollController.offset - 120).clamp(0.0, _scrollController.position.maxScrollExtent);
              _scrollController.animateTo(
                target,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            },
            child: Container(
              width: 30,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isRight ? Alignment.centerLeft : Alignment.centerRight,
                  end: isRight ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    bgColor.withValues(alpha: 0.0),
                    bgColor.withValues(alpha: 0.95),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  isRight ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    String? badgeText,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final activeBg = Colors.white.withValues(alpha: 0.22);
    const unselectedColor = Colors.white70;
    const selectedColor = Colors.white;

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
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.selectionClick();
                  onLongPress();
                }
              : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 64),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 24,
                      color: isActive ? selectedColor : unselectedColor,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0.5,
                        color: isActive ? selectedColor : unselectedColor,
                      ),
                    ),
                  ],
                ),
                if (badgeText != null)
                  Positioned(
                    top: -6,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
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
}
