import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../services/image_service/background_remover_service.dart';
import '../../widgets/gradient_button.dart';

class BgRemoverResult {
  final File file;
  final bool isTransparent;
  final Color? backgroundColor;

  BgRemoverResult({
    required this.file,
    required this.isTransparent,
    this.backgroundColor,
  });
}

class BgRemoverSheet extends StatefulWidget {
  final File imageFile;

  const BgRemoverSheet({
    super.key,
    required this.imageFile,
  });

  static Future<BgRemoverResult?> show(
    BuildContext context, {
    required File imageFile,
  }) {
    return showModalBottomSheet<BgRemoverResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => BgRemoverSheet(imageFile: imageFile),
    );
  }

  @override
  State<BgRemoverSheet> createState() => _BgRemoverSheetState();
}

class _BgRemoverSheetState extends State<BgRemoverSheet> {
  bool _isExtracting = true;
  bool _isSaving = false;
  String? _errorMessage;
  Uint8List? _foregroundBytes;

  // Selected background color (null = transparent)
  Color? _selectedBgColor;

  // Preset options for quick passport / exam / transparent cutouts
  static const List<_BgColorOption> _colorOptions = [
    _BgColorOption(name: 'Transparent', color: null, isTransparent: true),
    _BgColorOption(name: 'White', color: Color(0xFFFFFFFF)),
    _BgColorOption(name: 'Passport Blue', color: Color(0xFF0070BA)),
    _BgColorOption(name: 'Sky Blue', color: Color(0xFF4A90E2)),
    _BgColorOption(name: 'Red', color: Color(0xFFD32F2F)),
    _BgColorOption(name: 'Light Grey', color: Color(0xFFE5E7EB)),
    _BgColorOption(name: 'Black', color: Color(0xFF1F2937)),
  ];

  @override
  void initState() {
    super.initState();
    _startExtraction();
  }

  Future<void> _startExtraction() async {
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
    });

    try {
      final bytes = await BackgroundRemoverService.extractForeground(widget.imageFile);
      if (!mounted) return;

      if (bytes != null && bytes.isNotEmpty) {
        HapticFeedback.mediumImpact();
        setState(() {
          _foregroundBytes = bytes;
          _isExtracting = false;
        });
      } else {
        setState(() {
          _isExtracting = false;
          _errorMessage =
              'Could not detect any subject in this image. Please try an image with a clearer subject.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Background removal failed: $e';
      });
    }
  }

  Future<void> _handleApply() async {
    if (_foregroundBytes == null || _isSaving) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final isTransparent = _selectedBgColor == null;
      final resultFile = await BackgroundRemoverService.createResultFile(
        foregroundPngBytes: _foregroundBytes!,
        backgroundColor: _selectedBgColor,
        preferredFormat: isTransparent ? 'png' : 'jpg',
      );

      if (!mounted) return;
      Navigator.of(context).pop(
        BgRemoverResult(
          file: resultFile,
          isTransparent: isTransparent,
          backgroundColor: _selectedBgColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply background: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle & Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.auto_fix_high_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Background Remover',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'On-device AI • 100% Offline & Private',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: _buildBody(isDark),
              ),
            ),

            // Bottom Action Buttons
            if (!_isExtracting && _errorMessage == null)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.black12,
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        text: _isSaving ? 'Applying...' : 'Apply Cutout',
                        icon: _isSaving ? null : Icons.check_circle_rounded,
                        isLoading: _isSaving,
                        onPressed: _handleApply,
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

  Widget _buildBody(bool isDark) {
    if (_isExtracting) {
      return Container(
        height: 260,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 44,
              height: 44,
              child: CircularProgressIndicator(
                strokeWidth: 3.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Separating subject from background...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Processing locally on your device',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 52,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _startExtraction,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preview Canvas
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.black12,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Layer (Checkerboard for transparent, solid color otherwise)
              if (_selectedBgColor == null)
                CustomPaint(
                  painter: _CheckerboardPainter(
                    isDark: isDark,
                  ),
                )
              else
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  color: _selectedBgColor,
                ),

              // Foreground Cutout Image
              if (_foregroundBytes != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Image.memory(
                    _foregroundBytes!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),

              // Format Badge in Top Corner
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _selectedBgColor == null ? 'PNG (Transparent)' : 'Solid Color',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Color selector title & recommendation
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Background Style',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _selectedBgColor == null
                  ? 'Transparent Cutout'
                  : (_colorOptions
                          .firstWhere(
                            (o) => o.color == _selectedBgColor,
                            orElse: () => const _BgColorOption(name: 'Custom', color: null),
                          )
                          .name),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Color Options Horizontal List
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _colorOptions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final option = _colorOptions[index];
              final isSelected = (_selectedBgColor == null && option.isTransparent) ||
                  (_selectedBgColor != null && _selectedBgColor == option.color);

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedBgColor = option.color;
                  });
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.white24 : Colors.black12),
                          width: isSelected ? 3 : 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(
                        child: option.isTransparent
                            ? CustomPaint(
                                painter: _CheckerboardPainter(isDark: isDark, squareSize: 6),
                                child: isSelected
                                    ? const Icon(Icons.check, size: 20, color: AppColors.primary)
                                    : null,
                              )
                            : Container(
                                color: option.color,
                                child: isSelected
                                    ? Icon(
                                        Icons.check,
                                        size: 20,
                                        color: option.color == const Color(0xFFFFFFFF) ||
                                                option.color == const Color(0xFFE5E7EB)
                                            ? Colors.black87
                                            : Colors.white,
                                      )
                                    : null,
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 12),

        // Contextual Hint Banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedBgColor == null
                      ? 'Tip: Transparent photos are exported as PNG to preserve transparent pixels.'
                      : 'Tip: White and Blue backgrounds are widely used for Passport and Govt Exam forms.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BgColorOption {
  final String name;
  final Color? color;
  final bool isTransparent;

  const _BgColorOption({
    required this.name,
    required this.color,
    this.isTransparent = false,
  });
}

class _CheckerboardPainter extends CustomPainter {
  final bool isDark;
  final double squareSize;

  _CheckerboardPainter({
    required this.isDark,
    this.squareSize = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final color1 = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final color2 = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

    final paint1 = Paint()..color = color1;
    final paint2 = Paint()..color = color2;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint2);

    final numX = (size.width / squareSize).ceil();
    final numY = (size.height / squareSize).ceil();

    for (int i = 0; i < numX; i++) {
      for (int j = 0; j < numY; j++) {
        if ((i + j) % 2 == 1) {
          canvas.drawRect(
            Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
            paint1,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CheckerboardPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.squareSize != squareSize;
}
