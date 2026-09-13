import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/process_options.dart';
import '../models/batch_item_model.dart';

/// Modal bottom sheet to customize settings for an individual image
class BatchItemSettingsSheet extends StatefulWidget {
  final BatchItemModel item;
  final ProcessOptions defaultOptions;
  final ValueChanged<ProcessOptions?> onSave;

  const BatchItemSettingsSheet({
    super.key,
    required this.item,
    required this.defaultOptions,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required BatchItemModel item,
    required ProcessOptions defaultOptions,
    required ValueChanged<ProcessOptions?> onSave,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BatchItemSettingsSheet(
        item: item,
        defaultOptions: defaultOptions,
        onSave: onSave,
      ),
    );
  }

  @override
  State<BatchItemSettingsSheet> createState() => _BatchItemSettingsSheetState();
}

class _BatchItemSettingsSheetState extends State<BatchItemSettingsSheet> {
  late bool _isCustom;
  late int _targetSizeKB;
  late String _format;
  late int _scalePercentage;
  late TextEditingController _customSizeController;

  @override
  void initState() {
    super.initState();
    final custom = widget.item.customOptions;
    _isCustom = custom != null;

    final initial = custom ?? widget.defaultOptions;
    _targetSizeKB = initial.targetSizeKB ?? 100;
    _format = initial.outputFormat;
    _scalePercentage = initial.resizePercentage ?? 100;
    _customSizeController = TextEditingController(
      text: _targetSizeKB.toString(),
    );
  }

  @override
  void dispose() {
    _customSizeController.dispose();
    super.dispose();
  }

  void _applyCustomSize(String text) {
    final parsed = int.tryParse(text);
    if (parsed != null && parsed >= 5 && parsed <= 50000) {
      setState(() {
        _targetSizeKB = parsed;
      });
    }
  }

  void _handleSave() {
    if (!_isCustom) {
      widget.onSave(null);
    } else {
      final options = ProcessOptions(
        sourcePath: widget.item.path,
        targetSizeKB: _targetSizeKB,
        outputFormat: _format,
        resizeMode: _scalePercentage == 100
            ? ResizeMode.none
            : ResizeMode.percentage,
        resizePercentage: _scalePercentage == 100 ? null : _scalePercentage,
        preventSizeIncrease: true,
      );
      widget.onSave(options);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header info
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    widget.item.file,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    cacheWidth: 100,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 48,
                      height: 48,
                      color: isDark ? Colors.white10 : Colors.black12,
                      child: const Icon(Icons.image, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.item.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.item.readableSize} • ${widget.item.resolutionString}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Custom Switch
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Customize for this image',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        _isCustom
                            ? 'Override batch defaults'
                            : 'Inherits batch settings',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _isCustom,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _isCustom = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_isCustom) ...[
              // Target Size
              Text(
                'Target Size (KB)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppConstants.defaultTargetSizesKB.map((sizeKB) {
                  final isSelected = _targetSizeKB == sizeKB;
                  return ChoiceChip(
                    label: Text('$sizeKB KB'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) {
                        setState(() {
                          _targetSizeKB = sizeKB;
                          _customSizeController.text = sizeKB.toString();
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),

              // Custom KB text field
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _customSizeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Custom KB',
                        hintText: 'e.g. 75',
                        isDense: true,
                        suffixText: 'KB',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onChanged: _applyCustomSize,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Target Format
              Text(
                'Target Format',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['jpg', 'webp', 'png'].map((fmt) {
                  final isSelected = _format == fmt;
                  return ChoiceChip(
                    label: Text(fmt.toUpperCase()),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _format = fmt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Scale %
              Text(
                'Scale / Dimension (% of original)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [100, 75, 50, 25].map((pct) {
                  final isSelected = _scalePercentage == pct;
                  return ChoiceChip(
                    label: Text('$pct%'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight),
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _scalePercentage = pct);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            Row(
              children: [
                if (_isCustom)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        widget.onSave(null);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Reset to Default'),
                    ),
                  ),
                if (_isCustom) const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _handleSave,
                    child: Text(_isCustom ? 'Apply Custom' : 'Keep Default'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
