import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radii.dart';

enum CompressionSheetMode { targetSize, quality, none }

class CompressOptionsSheet extends StatefulWidget {
  final CompressionSheetMode initialMode;
  final int initialTargetSizeKB;
  final double initialQuality;
  final int originalSizeBytes;
  final Function(CompressionSheetMode mode, int targetSizeKB, double quality) onApply;

  const CompressOptionsSheet({
    super.key,
    required this.initialMode,
    required this.initialTargetSizeKB,
    required this.initialQuality,
    required this.originalSizeBytes,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required CompressionSheetMode initialMode,
    required int initialTargetSizeKB,
    required double initialQuality,
    required int originalSizeBytes,
    required Function(CompressionSheetMode mode, int targetSizeKB, double quality) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CompressOptionsSheet(
        initialMode: initialMode,
        initialTargetSizeKB: initialTargetSizeKB,
        initialQuality: initialQuality,
        originalSizeBytes: originalSizeBytes,
        onApply: onApply,
      ),
    );
  }

  @override
  State<CompressOptionsSheet> createState() => _CompressOptionsSheetState();
}

class _CompressOptionsSheetState extends State<CompressOptionsSheet> {
  late CompressionSheetMode _mode;
  late int _targetSizeKB;
  late double _quality;
  late TextEditingController _customSizeController;

  static const List<int> _presetSizes = [20, 50, 100, 200, 500];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _targetSizeKB = widget.initialTargetSizeKB;
    _quality = widget.initialQuality;
    _customSizeController = TextEditingController(text: _targetSizeKB.toString());
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  String _calculateEstimatedReduction() {
    if (_mode == CompressionSheetMode.none) {
      return 'Original quality, no target size applied.';
    }
    if (_mode == CompressionSheetMode.quality) {
      return 'Estimated quality: ${_quality.round()}%. File size depends on content.';
    }

    final originalKB = (widget.originalSizeBytes / 1024).round();
    if (originalKB <= 0) return 'Target: < $_targetSizeKB KB';

    if (_targetSizeKB >= originalKB) {
      return 'Target is larger or equal to original size ($originalKB KB).';
    }

    final savings = (((originalKB - _targetSizeKB) / originalKB) * 100).round();
    return 'Target: < $_targetSizeKB KB (Approx. $savings% smaller than original)';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final navBarInset = mq.viewPadding.bottom;
    final bottomPadding = keyboardInset > 0 ? keyboardInset : navBarInset;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadii.sheetRadius,
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
          // Title & Done
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.compress_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Compression Settings',
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
          const SizedBox(height: 12),
          // Mode segmented control
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<CompressionSheetMode>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 0),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              segments: const [
                ButtonSegment(
                  value: CompressionSheetMode.targetSize,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Target KB'),
                  ),
                  icon: Icon(Icons.tune, size: 16),
                ),
                ButtonSegment(
                  value: CompressionSheetMode.quality,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Quality %'),
                  ),
                  icon: Icon(Icons.high_quality, size: 16),
                ),
                ButtonSegment(
                  value: CompressionSheetMode.none,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Original'),
                  ),
                  icon: Icon(Icons.image_outlined, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => _mode = val.first);
              },
            ),
          ),
          const SizedBox(height: 16),

          if (_mode == CompressionSheetMode.targetSize) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Quick Target Size (KB)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_targetSizeKB KB',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.image_outlined, size: 15),
                      label: const Text('Original', style: TextStyle(fontSize: 12)),
                      selected: _mode == CompressionSheetMode.none,
                      onSelected: (selected) {
                        if (selected) {
                          HapticFeedback.selectionClick();
                          setState(() => _mode = CompressionSheetMode.none);
                        }
                      },
                    ),
                  ),
                  ..._presetSizes.map((size) {
                    final isSelected = _mode == CompressionSheetMode.targetSize && _targetSizeKB == size;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('$size KB', style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            if (size == 20 || size == 50) {
                              HapticFeedback.mediumImpact();
                            } else {
                              HapticFeedback.selectionClick();
                            }
                            setState(() {
                              _mode = CompressionSheetMode.targetSize;
                              _targetSizeKB = size;
                              _customSizeController.text = size.toString();
                            });
                          }
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Slider(
              value: _targetSizeKB.toDouble().clamp(10, 500),
              min: 10,
              max: 500,
              divisions: 98,
              label: '$_targetSizeKB KB',
              onChanged: (val) {
                int target = val.round();
                const snapPoints = [20, 50, 100, 200, 500];
                int? snappedPoint;
                for (final sp in snapPoints) {
                  if ((target - sp).abs() <= 4) {
                    snappedPoint = sp;
                    break;
                  }
                }
                if (snappedPoint != null) {
                  target = snappedPoint;
                }

                if (target != _targetSizeKB) {
                  if (snappedPoint != null) {
                    HapticFeedback.mediumImpact();
                  } else {
                    HapticFeedback.selectionClick();
                  }
                  setState(() {
                    _targetSizeKB = target;
                    _customSizeController.text = target.toString();
                  });
                }
              },
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _customSizeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Exact Target File Size (KB)',
                hintText: 'Enter size e.g. 50',
                suffixText: 'KB',
                prefixIcon: const Icon(Icons.data_usage_rounded),
                border: const OutlineInputBorder(borderRadius: AppRadii.cardSmallRadius),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null && parsed > 0) {
                  setState(() => _targetSizeKB = parsed);
                }
              },
            ),
          ],

          if (_mode == CompressionSheetMode.quality) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Output Quality',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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
              value: _quality,
              min: 10,
              max: 100,
              divisions: 18,
              label: '${_quality.round()}%',
              onChanged: (val) {
                if (val.round() != _quality.round()) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _quality = val);
              },
            ),
          ],

          if (_mode == CompressionSheetMode.none) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                borderRadius: AppRadii.cardSmallRadius,
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Compression is turned off. Original quality will be preserved without strict file size limits.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Savings estimate
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: AppRadii.cardInnerSmallRadius,
            ),
            child: Row(
              children: [
                const Icon(Icons.insights_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _calculateEstimatedReduction(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Apply Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                final customVal = int.tryParse(_customSizeController.text);
                final finalSize = (customVal != null && customVal > 0) ? customVal : _targetSizeKB;
                widget.onApply(_mode, finalSize, _quality);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Apply Compression Settings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
