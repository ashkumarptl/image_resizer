import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radii.dart';

class FormatOptionsSheet extends StatefulWidget {
  final String initialFormat;
  final double initialQuality;
  final Function(String format, double quality) onApply;

  const FormatOptionsSheet({
    super.key,
    required this.initialFormat,
    required this.initialQuality,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialFormat,
    required double initialQuality,
    required Function(String format, double quality) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FormatOptionsSheet(
        initialFormat: initialFormat,
        initialQuality: initialQuality,
        onApply: onApply,
      ),
    );
  }

  @override
  State<FormatOptionsSheet> createState() => _FormatOptionsSheetState();
}

class _FormatOptionsSheetState extends State<FormatOptionsSheet> {
  late String _format;
  late double _quality;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat.toLowerCase();
    _quality = widget.initialQuality;
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
          // Title & Close
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Output Format & Quality',
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
          const SizedBox(height: 14),

          // Format Cards
          _buildFormatOption(
            title: 'JPG / JPEG',
            subtitle: 'Best for photographs, compact file size, universal support',
            value: 'jpg',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildFormatOption(
            title: 'WEBP',
            subtitle: 'Modern web format, superior compression and smaller files',
            value: 'webp',
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          _buildFormatOption(
            title: 'PNG',
            subtitle: 'Lossless quality, preserves transparency, larger file size',
            value: 'png',
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          if (_format != 'png') ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quality Level',
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
              min: 20,
              max: 100,
              divisions: 16,
              label: '${_quality.round()}%',
              onChanged: (val) {
                if (val.round() != _quality.round()) {
                  HapticFeedback.selectionClick();
                }
                setState(() => _quality = val);
              },
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onApply(_format, _quality);
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
                  'Apply Format',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption({
    required String title,
    required String subtitle,
    required String value,
    required bool isDark,
  }) {
    final isSelected = _format == value;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _format = value);
      },
      borderRadius: AppRadii.cardSmallRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
          borderRadius: AppRadii.cardSmallRadius,
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
