import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/repositories/tool_guide_repository.dart';
import '../../services/ai_upscaler_service.dart';
import '../../services/share_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/tool_instruction_sheet.dart';

class AiUpscalerScreen extends StatefulWidget {
  final File? initialImage;

  const AiUpscalerScreen({super.key, this.initialImage});

  @override
  State<AiUpscalerScreen> createState() => _AiUpscalerScreenState();
}

class _AiUpscalerScreenState extends State<AiUpscalerScreen> {
  final _picker = ImagePicker();
  final _upscalerService = AiUpscalerService();

  File? _selectedFile;
  Uint8List? _originalBytes;
  AiUpscaleResult? _result;
  int _selectedScale = 2; // 2x or 4x
  bool _isProcessing = false;
  double _progress = 0.0;
  String _statusMessage = '';
  bool _showComparisonOriginal = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _loadInitialFile(widget.initialImage!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ToolInstructionSheet.show(context, ToolGuideType.aiUpscaler);
    });
  }

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    super.dispose();
  }

  Future<void> _loadInitialFile(File file) async {
    final bytes = await file.readAsBytes();
    setState(() {
      _selectedFile = file;
      _originalBytes = bytes;
      _result = null;
    });
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      _loadInitialFile(File(picked.path));
    }
  }

  Future<void> _startUpscaling() async {
    if (_originalBytes == null) return;

    setState(() {
      _isProcessing = true;
      _progress = 0.02;
      _statusMessage = 'Initializing NCNN engine & GPU...';
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

      setState(() {
        _result = res;
        _isProcessing = false;
        _progress = 1.0;
        _statusMessage =
            'Completed in ${(res.duration.inMilliseconds / 1000).toStringAsFixed(1)}s';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upscaled to ${res.upscaledWidth}x${res.upscaledHeight} (${res.isVulkanAccelerated ? "Vulkan GPU" : "CPU/Fallback"})',
            ),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upscaling failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveResultToGallery() async {
    if (_result == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/upscaled_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(_result!.imageBytes);
      await Gal.putImage(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved upscaled image to Gallery!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareResult() async {
    if (_result == null) return;
    try {
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/upscaled_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await file.writeAsBytes(_result!.imageBytes);
      await ShareService.shareImage(
        file.path,
        text: 'Upscaled with AI Super Resolution',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'AI Super Resolution',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'How to use AI Upscaler',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              ToolInstructionSheet.show(
                context,
                ToolGuideType.aiUpscaler,
                isManualTrigger: true,
              );
            },
          ),
          IconButton(
            tooltip: 'Engine & Model Info',
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => _showEngineInfoDialog(context),
          ),
        ],
      ),
      body: AdaptivePageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageArea(isDark),
              const SizedBox(height: 16),
              if (_selectedFile != null) ...[
                _buildControlsCard(isDark),
                const SizedBox(height: 16),
                _buildActionButton(),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _buildResultActions(isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageArea(bool isDark) {
    if (_selectedFile == null) {
      return InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                      const Color(0xFF6366F1).withValues(alpha: 0.2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 40,
                  color: Color(0xFF8B5CF6),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Select an image to enhance',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '2x & 4x Neural Super-Resolution (Real-ESRGAN / NCNN)',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: 1.2,
                child: _result != null && !_showComparisonOriginal
                    ? Image.memory(
                        _result!.imageBytes,
                        fit: BoxFit.contain,
                        cacheWidth: 1200,
                      )
                    : Image.file(
                        _selectedFile!,
                        fit: BoxFit.contain,
                        cacheWidth: 1200,
                      ),
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black.withValues(alpha: 0.80),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
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
                              width: 44,
                              height: 44,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 22,
                              color: Color(0xFFC084FC),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _statusMessage.isNotEmpty
                            ? _statusMessage
                            : 'Running neural AI tiles...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _progress > 0 ? _progress : null,
                            minHeight: 6,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF8B5CF6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_progress > 0)
                        Text(
                          '${(_progress * 100).clamp(0, 100).toInt()}% Completed',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              if (_result != null && !_isProcessing)
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTapDown: (_) =>
                        setState(() => _showComparisonOriginal = true),
                    onTapUp: (_) =>
                        setState(() => _showComparisonOriginal = false),
                    onTapCancel: () =>
                        setState(() => _showComparisonOriginal = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showComparisonOriginal
                                ? Icons.visibility
                                : Icons.touch_app_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showComparisonOriginal
                                ? 'Showing Original'
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _isProcessing ? null : _pickImage,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Change Image'),
                ),
                if (_result != null)
                  Text(
                    '${_result!.upscaledWidth}x${_result!.upscaledHeight} px',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
              const SizedBox(width: 8),
              Text(
                'Upscale Factor',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
              const SizedBox(width: 12),
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
      ),
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
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
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
                  size: 16,
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
                      fontSize: 13,
                      color: isSelected ? const Color(0xFF8B5CF6) : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return GradientButton(
      text: _isProcessing
          ? (_progress > 0
                ? 'Processing ${(_progress * 100).toInt()}%...'
                : 'Processing AI Tiles...')
          : 'Upscale (${_selectedScale}x)',
      icon: Icons.auto_awesome_rounded,
      isLoading: _isProcessing,
      onPressed: _isProcessing ? null : _startUpscaling,
    );
  }

  Widget _buildResultActions(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _shareResult,
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveResultToGallery,
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Save Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showEngineInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.memory_rounded, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Text(
              'AI Engine Details',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Core Backend', 'Tencent NCNN + Real-ESRGAN'),
            _infoRow(
              'Acceleration',
              _upscalerService.isVulkanSupported
                  ? 'Vulkan GPU (Active)'
                  : 'CPU / OpenMP',
            ),
            _infoRow('Model Footprint', '~1.24 MB (Compact v3)'),
            _infoRow('Memory Protection', 'Sub-tile slicing (128x128)'),
            _infoRow('Privacy', '100% On-Device & Offline'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
