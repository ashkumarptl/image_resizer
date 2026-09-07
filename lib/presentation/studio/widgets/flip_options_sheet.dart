import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class FlipOptionsSheet extends StatefulWidget {
  final bool initialFlipHorizontal;
  final bool initialFlipVertical;
  final Function(bool flipH, bool flipV) onApply;

  const FlipOptionsSheet({
    super.key,
    required this.initialFlipHorizontal,
    required this.initialFlipVertical,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required bool initialFlipHorizontal,
    required bool initialFlipVertical,
    required Function(bool flipH, bool flipV) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlipOptionsSheet(
        initialFlipHorizontal: initialFlipHorizontal,
        initialFlipVertical: initialFlipVertical,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FlipOptionsSheet> createState() => _FlipOptionsSheetState();
}

class _FlipOptionsSheetState extends State<FlipOptionsSheet> {
  late bool _flipH;
  late bool _flipV;

  @override
  void initState() {
    super.initState();
    _flipH = widget.initialFlipHorizontal;
    _flipV = widget.initialFlipVertical;
  }

  void _update(bool h, bool v) {
    setState(() {
      _flipH = h;
      _flipV = v;
    });
    widget.onApply(_flipH, _flipV);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mq = MediaQuery.of(context);
    final navBarInset = mq.viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + navBarInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.flip_outlined, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Flip Image Orientation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildFlipTile(
                  icon: Icons.swap_horiz_rounded,
                  title: 'Horizontal',
                  subtitle: 'Mirror Left / Right',
                  isSelected: _flipH,
                  isDark: isDark,
                  onTap: () => _update(!_flipH, _flipV),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFlipTile(
                  icon: Icons.swap_vert_rounded,
                  title: 'Vertical',
                  subtitle: 'Mirror Upside Down',
                  isSelected: _flipV,
                  isDark: isDark,
                  onTap: () => _update(_flipH, !_flipV),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_flipH || _flipV)
            Center(
              child: TextButton.icon(
                onPressed: () => _update(false, false),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Reset Orientation'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primary : (isDark ? Colors.white : Colors.black),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
