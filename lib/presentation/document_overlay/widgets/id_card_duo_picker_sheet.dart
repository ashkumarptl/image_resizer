import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../widgets/image_source_picker_sheet.dart';

class IdCardDuoResult {
  final File frontFile;
  final File backFile;
  final bool isVertical;
  final bool hasBorder;

  const IdCardDuoResult({
    required this.frontFile,
    required this.backFile,
    this.isVertical = true,
    this.hasBorder = true,
  });
}

class IdCardDuoPickerSheet extends StatefulWidget {
  const IdCardDuoPickerSheet({super.key});

  static Future<IdCardDuoResult?> show(BuildContext context) {
    return showModalBottomSheet<IdCardDuoResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const IdCardDuoPickerSheet(),
    );
  }

  @override
  State<IdCardDuoPickerSheet> createState() => _IdCardDuoPickerSheetState();
}

class _IdCardDuoPickerSheetState extends State<IdCardDuoPickerSheet> {
  File? _frontFile;
  File? _backFile;
  bool _isVertical = true; // Vertical (Stacked) vs Horizontal (Side-by-Side)
  bool _hasBorder = true; // Cutting guide border

  Future<void> _pickCardSide(bool isFront) async {
    HapticFeedback.selectionClick();
    final picked = await ImageSourcePickerSheet.show(
      context,
      title: isFront ? 'Select ID Front Side' : 'Select ID Back Side',
      subtitle: 'Scan with camera or pick from gallery',
    );
    if (picked != null && mounted) {
      setState(() {
        if (isFront) {
          _frontFile = picked;
        } else {
          _backFile = picked;
        }
      });
    }
  }

  void _apply() {
    if (_frontFile == null || _backFile == null) return;
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(
      IdCardDuoResult(
        frontFile: _frontFile!,
        backFile: _backFile!,
        isVertical: _isVertical,
        hasBorder: _hasBorder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canApply = _frontFile != null && _backFile != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.badge_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Aadhaar / ID Card Duo Setup',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          'Align Front & Back on single A4 Sheet',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card Slots (Front & Back)
            Row(
              children: [
                Expanded(
                  child: _buildCardSlot(
                    label: 'FRONT SIDE',
                    subtitle: 'Photo & Details',
                    file: _frontFile,
                    isFront: true,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCardSlot(
                    label: 'BACK SIDE',
                    subtitle: 'Address & QR Code',
                    file: _backFile,
                    isFront: false,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Layout & Options Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariantLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'A4 Placement Layout:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Stacked (Top/Bottom)'),
                            selected: _isVertical,
                            onSelected: (val) {
                              if (val) setState(() => _isVertical = true);
                            },
                          ),
                          const SizedBox(width: 6),
                          ChoiceChip(
                            label: const Text('Side-by-Side'),
                            selected: !_isVertical,
                            onSelected: (val) {
                              if (val) setState(() => _isVertical = false);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.crop_square_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add Cutting Guide Border',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _hasBorder,
                        onChanged: (val) => setState(() => _hasBorder = val),
                        activeThumbColor: AppColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: canApply ? _apply : null,
                icon: const Icon(Icons.dashboard_customize_rounded),
                label: Text(
                  canApply
                      ? 'Place Cards on A4 Paper'
                      : 'Select Both Front & Back',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSlot({
    required String label,
    required String subtitle,
    required File? file,
    required bool isFront,
    required bool isDark,
  }) {
    final hasFile = file != null;

    return InkWell(
      onTap: () => _pickCardSide(isFront),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: hasFile
              ? (isDark ? Colors.black26 : Colors.white)
              : (isDark ? AppColors.surfaceVariantDark : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasFile
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : Colors.grey.shade300),
            width: hasFile ? 2 : 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: hasFile
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file, fit: BoxFit.cover),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 6),
                        color: Colors.black.withValues(alpha: 0.65),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF4ADE80),
                              size: 14,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_a_photo_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
