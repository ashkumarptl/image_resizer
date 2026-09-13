import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

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
      constraints: const BoxConstraints(maxWidth: 560),
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
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 10, 18, 16 + navBarInset),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Minimal Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Output Format & Quality',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Compact Segmented Format Tabs
          Row(
            children: [
              Expanded(
                child: _buildFormatTab(
                  value: 'jpg',
                  title: 'JPG / JPEG',
                  subtitle: 'Compact & Universal',
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormatTab(
                  value: 'webp',
                  title: 'WebP',
                  subtitle: 'Modern & Small',
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormatTab(
                  value: 'png',
                  title: 'PNG',
                  subtitle: 'Lossless HD',
                  isDark: isDark,
                  primaryColor: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 4. Quality Slider OR PNG Lossless Note
          if (_format == 'png') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF261E14) : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: Colors.amber.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PNG preserves full lossless transparency (file size will be larger).',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
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
                Text(
                  'Compression Quality',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_quality.round()}%',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: primaryColor,
                inactiveTrackColor: isDark ? AppColors.borderDark : AppColors.borderLight,
                thumbColor: primaryColor,
                trackHeight: 3.0,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: _quality.clamp(20, 100),
                min: 20,
                max: 100,
                divisions: 16,
                onChanged: (val) {
                  if (val.round() != _quality.round()) {
                    HapticFeedback.selectionClick();
                  }
                  setState(() => _quality = val);
                },
              ),
            ),
          ],
          const SizedBox(height: 10),

          // 5. Resolution / Density (DPI)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Resolution / DPI',
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              if (_dpi != null)
                Text(
                  '$_dpi DPI',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal scrollable DPI chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildDpiChip(label: 'Auto', dpiValue: null, isDark: isDark, primaryColor: primaryColor),
                const SizedBox(width: 8),
                _buildDpiChip(label: '72 (Web)', dpiValue: 72, isDark: isDark, primaryColor: primaryColor),
                const SizedBox(width: 8),
                _buildDpiChip(label: '150 (Docs)', dpiValue: 150, isDark: isDark, primaryColor: primaryColor),
                const SizedBox(width: 8),
                _buildDpiChip(label: '200 (SSC) ★', dpiValue: 200, isDark: isDark, primaryColor: primaryColor),
                const SizedBox(width: 8),
                _buildDpiChip(label: '300 (UPSC) ★', dpiValue: 300, isDark: isDark, primaryColor: primaryColor),
                const SizedBox(width: 8),
                _buildDpiChip(label: '600 (Print)', dpiValue: 600, isDark: isDark, primaryColor: primaryColor),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                widget.onApply(_format, _quality, _dpi);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'Apply Format',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatTab({
    required String value,
    required String title,
    required String subtitle,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _format == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _format = value);
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primaryContainerDark.withValues(alpha: 0.6)
                    : AppColors.primaryContainerLight)
                : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDpiChip({
    required String label,
    required int? dpiValue,
    required bool isDark,
    required Color primaryColor,
  }) {
    final isSelected = _dpi == dpiValue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _dpi = dpiValue);
        },
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: 0.14)
                : (isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariantLight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? primaryColor
                  : (isDark ? AppColors.borderDark : AppColors.borderLight),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? primaryColor
                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            ),
          ),
        ),
      ),
    );
  }
}

