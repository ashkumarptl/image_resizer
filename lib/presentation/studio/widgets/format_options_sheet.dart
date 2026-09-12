import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_radii.dart';

class FormatOptionsSheet extends StatefulWidget {
  final String initialFormat;
  final double initialQuality;
  final int? initialDpi;
  final Function(String format, double quality, int? dpi) onApply;

  const FormatOptionsSheet({
    super.key,
    required this.initialFormat,
    required this.initialQuality,
    this.initialDpi,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialFormat,
    required double initialQuality,
    int? initialDpi,
    required Function(String format, double quality, int? dpi) onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FormatOptionsSheet(
        initialFormat: initialFormat,
        initialQuality: initialQuality,
        initialDpi: initialDpi,
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
  int? _dpi;

  @override
  void initState() {
    super.initState();
    _format = widget.initialFormat.toLowerCase();
    _quality = widget.initialQuality;
    _dpi = widget.initialDpi;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final navBarInset = MediaQuery.viewPaddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
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
      child: SingleChildScrollView(
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
                            'Output Format & Resolution',
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

            if (_format == 'png') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: AppRadii.cardSmallRadius,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PNG is a lossless format and can increase photo file size by 3x–10x. Use JPG or WebP if you want smaller file sizes.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
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

            const SizedBox(height: 16),

            // Resolution / DPI Section
            Row(
              children: [
                const Icon(Icons.high_quality_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Resolution / Density (DPI)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const Spacer(),
                if (_dpi != null)
                  Text(
                    '$_dpi DPI',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Govt Exam portals (SSC, UPSC) & Passport forms mandate 200 or 300 DPI.',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDpiChip(label: 'Auto / Original', dpiValue: null, isDark: isDark),
                _buildDpiChip(label: '72 (Web)', dpiValue: 72, isDark: isDark),
                _buildDpiChip(label: '150 (Docs)', dpiValue: 150, isDark: isDark),
                _buildDpiChip(label: '200 (SSC)', dpiValue: 200, isDark: isDark, isRecommended: true),
                _buildDpiChip(label: '300 (Passport/UPSC)', dpiValue: 300, isDark: isDark, isRecommended: true),
                _buildDpiChip(label: '600 (Print)', dpiValue: 600, isDark: isDark),
              ],
            ),

            if (_format == 'webp' && _dpi != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WebP format does not standardize DPI headers. Select JPG or PNG for official exam/visa portals.',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  widget.onApply(_format, _quality, _dpi);
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
                    'Apply Format & Resolution',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDpiChip({
    required String label,
    required int? dpiValue,
    required bool isDark,
    bool isRecommended = false,
  }) {
    final isSelected = _dpi == dpiValue;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _dpi = dpiValue);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (isDark ? Colors.grey.shade900 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isRecommended
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : (isDark ? Colors.grey.shade800 : Colors.grey.shade300)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 5),
            ] else if (isRecommended) ...[
              const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
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
