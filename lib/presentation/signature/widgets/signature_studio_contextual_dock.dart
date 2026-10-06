import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../services/image_service/signature_enhancer.dart';
import 'signature_studio_bottom_toolbar.dart';

/// Contextual Dock displayed directly above the bottom toolbar in Signature Studio.
/// Hosts controls for:
/// - Clean (Shadow Removal Strength slider & preset chips)
/// - Ink (Dark Navy, Pure Black, Royal Blue, Original)
/// - Target KB (Interactive stepper, text field & fast scrubbing slider)
/// - Dimensions (Standard dimensions chips: 400x200, 300x150, 140x60, Original)
class SignatureStudioContextualDock extends StatelessWidget {
  final SignatureStudioTool activeTool;
  final double threshold;
  final ValueChanged<double> onThresholdChanged;
  final SignatureInkColor inkColor;
  final ValueChanged<SignatureInkColor> onInkColorChanged;
  final int targetSizeKB;
  final TextEditingController sizeController;
  final ValueChanged<int> onTargetSizeKBChanged;
  final int? targetWidth;
  final int? targetHeight;
  final void Function(int? width, int? height) onDimensionsChanged;
  final bool isDark;

  const SignatureStudioContextualDock({
    super.key,
    required this.activeTool,
    required this.threshold,
    required this.onThresholdChanged,
    required this.inkColor,
    required this.onInkColorChanged,
    required this.targetSizeKB,
    required this.sizeController,
    required this.onTargetSizeKBChanged,
    required this.targetWidth,
    required this.targetHeight,
    required this.onDimensionsChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: switch (activeTool) {
        SignatureStudioTool.clean => _buildCleanDock(context),
        SignatureStudioTool.ink => _buildInkDock(context),
        SignatureStudioTool.compress => _buildCompressDock(context),
        SignatureStudioTool.dimensions => _buildDimensionsDock(context),
      },
    );
  }

  // --- Tool 1: Clean / Shadow Removal Dock ---
  Widget _buildCleanDock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDockHeader(
          icon: Icons.auto_fix_high_rounded,
          title: 'Shadow Removal Strength',
          valueBadge: '${(threshold * 100).toInt()}%',
        ),
        const SizedBox(height: 8),

        // Quick Preset Chips (4 unified columns)
        Row(
          children: [
            Expanded(
              child: _buildThresholdChip(label: 'None (0%)', value: 0.0),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildThresholdChip(label: 'Light (50%)', value: 0.50),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildThresholdChip(label: 'Balanced (65%)', value: 0.65),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildThresholdChip(label: 'Deep (80%)', value: 0.80),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Slider for Shadow Strength (Minimal smooth track)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              pressedElevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: threshold.clamp(0.0, 0.90),
            min: 0.0,
            max: 0.90,
            onChanged: (val) {
              final normalizedVal = ((val * 100).round() / 100.0).clamp(
                0.0,
                0.90,
              );
              if ((normalizedVal * 100).round() != (threshold * 100).round()) {
                HapticFeedback.selectionClick();
              }
              onThresholdChanged(normalizedVal);
            },
          ),
        ),
        Text(
          'Adaptive contrast tracks uneven paper lighting to eliminate shadows cleanly.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // --- Tool 2: Ink Color Dock ---
  Widget _buildInkDock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDockHeader(icon: Icons.palette_outlined, title: 'Ink Color Tone'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildInkToneChip(
                label: 'Dark Navy',
                color: SignatureInkColor.darkNavy,
                dotColor: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildInkToneChip(
                label: 'Pure Black',
                color: SignatureInkColor.pureBlack,
                dotColor: Colors.black,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildInkToneChip(
                label: 'Royal Blue',
                color: SignatureInkColor.royalBlue,
                dotColor: const Color(0xFF1D4ED8),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildInkToneChip(
                label: 'Original',
                color: SignatureInkColor.original,
                dotColor: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Enhances pen stroke contrast into crisp, professional ink for official submissions.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // --- Tool 3: Compress / Custom Target KB Dock ---
  Widget _buildCompressDock(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDockHeader(
          icon: Icons.compress_rounded,
          title: 'Custom Target Size Limit',
          valueBadge: '< $targetSizeKB KB',
        ),
        const SizedBox(height: 8),

        // Custom Numeric Input with Integrated Modern Stepper
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Decrement Button (-5 KB)
              IconButton(
                icon: const Icon(Icons.remove_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                tooltip: '-5 KB',
                color: isDark ? Colors.white70 : Colors.black87,
                disabledColor: isDark ? Colors.white24 : Colors.black26,
                onPressed: targetSizeKB > 5
                    ? () {
                        HapticFeedback.selectionClick();
                        final newVal = (targetSizeKB - 5).clamp(5, 500);
                        sizeController.text = '$newVal';
                        onTargetSizeKBChanged(newVal);
                      }
                    : null,
              ),
              Container(
                width: 1,
                height: 22,
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Number Input Field
              Expanded(
                child: TextField(
                  controller: sizeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 9),
                    suffixText: 'KB ',
                    suffixStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed >= 5 && parsed <= 500) {
                      onTargetSizeKBChanged(parsed);
                    }
                  },
                ),
              ),
              Container(
                width: 1,
                height: 22,
                color: isDark ? Colors.white12 : Colors.black12,
              ),

              // Increment Button (+5 KB)
              IconButton(
                icon: const Icon(Icons.add_rounded, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                tooltip: '+5 KB',
                color: isDark ? Colors.white70 : Colors.black87,
                disabledColor: isDark ? Colors.white24 : Colors.black26,
                onPressed: targetSizeKB < 500
                    ? () {
                        HapticFeedback.selectionClick();
                        final newVal = (targetSizeKB + 5).clamp(5, 500);
                        sizeController.text = '$newVal';
                        onTargetSizeKBChanged(newVal);
                      }
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Slider for Fast Scrubbing (5 KB to 100 KB)
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3.0,
            thumbShape: const RoundSliderThumbShape(
              enabledThumbRadius: 7,
              pressedElevation: 3,
            ),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
            thumbColor: AppColors.primary,
          ),
          child: Slider(
            value: targetSizeKB.clamp(5, 100).toDouble(),
            min: 5,
            max: 100,
            onChanged: (val) {
              final newKB = val.round();
              if (newKB != targetSizeKB) {
                HapticFeedback.selectionClick();
                sizeController.text = '$newKB';
                onTargetSizeKBChanged(newKB);
              }
            },
          ),
        ),

        Text(
          'Signature will be compressed strictly under this custom limit (e.g. 20 KB for UPSC/SSC).',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // --- Tool 4: Dimensions / Aspect Ratio Dock ---
  Widget _buildDimensionsDock(BuildContext context) {
    final dimensions = [
      (400, 200, '400 × 200', '2:1 Standard'),
      (300, 150, '300 × 150', '2:1 Compact'),
      (140, 60, '140 × 60', 'SSC 7:3'),
      (null, null, 'Original', 'Keep Aspect'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDockHeader(
          icon: Icons.aspect_ratio_rounded,
          title: 'Standard Dimensions',
          valueBadge: targetWidth != null
              ? '$targetWidth × $targetHeight'
              : 'Auto',
        ),
        const SizedBox(height: 8),
        Row(
          children: dimensions.map((d) {
            final isSelected = targetWidth == d.$1 && targetHeight == d.$2;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _buildDimensionsChip(
                  title: d.$3,
                  subtitle: d.$4,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDimensionsChanged(d.$1, d.$2);
                  },
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        Text(
          'Standardizes signature dimensions to match government exam portal upload boxes.',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  // --- Sub-widgets & Chips ---

  Widget _buildDockHeader({
    required IconData icon,
    required String title,
    String? valueBadge,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (valueBadge != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              valueBadge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStudioChip({
    required Widget child,
    required bool isSelected,
    required VoidCallback onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(
      horizontal: 4,
      vertical: 8,
    ),
  }) {
    final activeBg = AppColors.primary;
    final inactiveBg = isDark
        ? const Color(0xFF1E2638)
        : const Color(0xFFF1F5F9);
    final borderColor = isSelected
        ? AppColors.primary
        : (isDark ? const Color(0xFF2D3748) : const Color(0xFFE2E8F0));

    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildThresholdChip({required String label, required double value}) {
    final isSelected = (threshold - value).abs() < 0.04;
    return _buildStudioChip(
      isSelected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        onThresholdChanged(value);
      },
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected
                  ? Colors.white
                  : (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInkToneChip({
    required String label,
    required SignatureInkColor color,
    required Color dotColor,
  }) {
    final isSelected = inkColor == color;
    return _buildStudioChip(
      isSelected: isSelected,
      onTap: () {
        HapticFeedback.selectionClick();
        onInkColorChanged(color);
      },
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white38 : Colors.grey.shade400),
                    width: 1,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDimensionsChip({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return _buildStudioChip(
      isSelected: isSelected,
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      onTap: onTap,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.8)
                      : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
