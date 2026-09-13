import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../services/ai_upscaler_service.dart';
import '../../widgets/gradient_button.dart';

class AiUpscaleSheetResult {
  final File file;
  final int scale;
  final int upscaledWidth;
  final int upscaledHeight;
  final Duration duration;

  AiUpscaleSheetResult({
    required this.file,
    required this.scale,
    required this.upscaledWidth,
    required this.upscaledHeight,
    required this.duration,
  });
}

class AiUpscaleSheet extends StatefulWidget {
  final File imageFile;

  const AiUpscaleSheet({super.key, required this.imageFile});

  static Future<AiUpscaleSheetResult?> show(
    BuildContext context, {
    required File imageFile,
  }) {
    return showModalBottomSheet<AiUpscaleSheetResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (ctx) => AiUpscaleSheet(imageFile: imageFile),
    );
  }

  @override
  State<AiUpscaleSheet> createState() => _AiUpscaleSheetState();
}

class _AiUpscaleSheetState extends State<AiUpscaleSheet> {
  final _upscalerService = AiUpscalerService();
  int _selectedScale = 2; // 2x or 4x
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';

  Uint8List? _originalBytes;
  AiUpscaleResult? _upscaleResult;
  bool _showComparisonOriginal = false;

  @override
  void initState() {
    super.initState();
    _loadOriginalBytes();
  }

  Future<void> _loadOriginalBytes() async {
    final bytes = await widget.imageFile.readAsBytes();
    if (mounted) {
      setState(() => _originalBytes = bytes);
    }
  }

  Future<void> _startUpscaling() async {
    if (_originalBytes == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.02;
      _statusMessage = 'Initializing neural engine (${_selectedScale}x)...';
    });

    try {
      final res = await _upscalerService.upscale(
        inputBytes: _originalBytes!,
        scale: _selectedScale,
        tileSize: 128,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusMessage = status;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _upscaleResult = res;
        _isProcessing = false;
        _progress = 1.0;
        _statusMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _progress = 0.0;
        _statusMessage = 'Failed: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upscaling error: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _applyResult() async {
    if (_upscaleResult == null) return;

    try {
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/studio_upscaled_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await outputFile.writeAsBytes(_upscaleResult!.imageBytes);

      if (!mounted) return;
      Navigator.of(context).pop(
        AiUpscaleSheetResult(
          file: outputFile,
          scale: _selectedScale,
          upscaledWidth: _upscaleResult!.upscaledWidth,
          upscaledHeight: _upscaleResult!.upscaledHeight,
          duration: _upscaleResult!.duration,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving result: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131823) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'AI Super Resolution',
                                style: GoogleFonts.outfit(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.textPrimaryLight,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF8B5CF6),
                                    Color(0xFF6366F1),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'BETA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Enhance clarity & double pixel dimensions',
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
                  IconButton(
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPreviewBox(isDark),
                    const SizedBox(height: 14),
                    _buildScaleSelector(isDark),
                  ],
                ),
              ),
            ),

            // Bottom action
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: _upscaleResult == null
                  ? GradientButton(
                      text: _isProcessing
                          ? (_progress > 0
                                ? 'Processing ${(_progress * 100).toInt()}%...'
                                : 'Processing AI...')
                          : 'Upscale (${_selectedScale}x)',
                      icon: Icons.auto_awesome_rounded,
                      isLoading: _isProcessing,
                      onPressed: _isProcessing ? null : _startUpscaling,
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _upscaleResult = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('Discard'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: _applyResult,
                            icon: const Icon(Icons.check_rounded, size: 18),
                            label: const Text('Apply to Studio'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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

  Widget _buildPreviewBox(bool isDark) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_originalBytes != null)
            _upscaleResult != null && !_showComparisonOriginal
                ? Image.memory(_upscaleResult!.imageBytes, fit: BoxFit.contain)
                : Image.memory(_originalBytes!, fit: BoxFit.contain),

          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.80),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: Color(0xFFC084FC),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _statusMessage.isNotEmpty
                        ? _statusMessage
                        : 'Neural Upscaling in progress...',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 180,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _progress > 0 ? _progress : null,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF8B5CF6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (_progress > 0)
                    Text(
                      '${(_progress * 100).clamp(0, 100).toInt()}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),

          if (_upscaleResult != null && !_isProcessing)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTapDown: (_) =>
                    setState(() => _showComparisonOriginal = true),
                onTapUp: (_) => setState(() => _showComparisonOriginal = false),
                onTapCancel: () =>
                    setState(() => _showComparisonOriginal = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showComparisonOriginal
                            ? Icons.visibility
                            : Icons.touch_app_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _showComparisonOriginal
                            ? 'Original'
                            : 'Hold to Compare',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScaleSelector(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 6),
            Text(
              'Upscale Multiplier',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildScaleOption(
                scale: 2,
                title: '2x Enhanced',
                subtitle: 'Fast & Balanced',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildScaleOption(
                scale: 4,
                title: '4x Ultra Clear',
                subtitle: 'Maximum Detail',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScaleOption({
    required int scale,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    final isSelected = _selectedScale == scale;
    return InkWell(
      onTap: _isProcessing
          ? null
          : () => setState(() => _selectedScale = scale),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF8B5CF6)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 15,
                  color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                      color: isSelected ? const Color(0xFF8B5CF6) : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 21),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
