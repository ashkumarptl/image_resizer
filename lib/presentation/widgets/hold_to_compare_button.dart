import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating glassmorphic comparison button.
/// Detects press & hold pointer events to allow instant "before & after" comparison.
class HoldToCompareButton extends StatelessWidget {
  final bool isComparing;
  final ValueChanged<bool> onComparisonChanged;
  final String idleText;
  final String activeText;
  final IconData idleIcon;
  final IconData activeIcon;

  const HoldToCompareButton({
    super.key,
    required this.isComparing,
    required this.onComparisonChanged,
    this.idleText = 'Hold to Compare',
    this.activeText = 'Showing Original',
    this.idleIcon = Icons.compare_rounded,
    this.activeIcon = Icons.visibility_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        HapticFeedback.selectionClick();
        onComparisonChanged(true);
      },
      onPointerUp: (_) => onComparisonChanged(false),
      onPointerCancel: (_) => onComparisonChanged(false),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isComparing
                  ? Colors.black.withValues(alpha: 0.88)
                  : Colors.black.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isComparing ? Colors.amber : Colors.white24,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isComparing ? activeIcon : idleIcon,
                  size: 15,
                  color: isComparing ? Colors.amber : Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  isComparing ? activeText : idleText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
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
