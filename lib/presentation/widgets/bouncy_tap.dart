import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A lightweight widget that adds an interactive springy/bounce micro-interaction
/// on press (scale down on touch down, spring back on release), with optional haptic feedback.
class BouncyTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;
  final Duration duration;
  final bool enableHaptic;

  const BouncyTap({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.duration = const Duration(milliseconds: 120),
    this.enableHaptic = true,
  });

  @override
  State<BouncyTap> createState() => _BouncyTapState();
}

class _BouncyTapState extends State<BouncyTap> {
  bool _isPressed = false;

  void _onPointerDown(PointerDownEvent event) {
    setState(() => _isPressed = true);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? widget.pressedScale : 1.0,
        duration: widget.duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );

    if (widget.onTap != null) {
      content = GestureDetector(
        onTap: () {
          if (widget.enableHaptic) {
            HapticFeedback.lightImpact();
          }
          widget.onTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: content,
    );
  }
}
