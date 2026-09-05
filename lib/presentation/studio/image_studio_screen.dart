import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../core/extensions/file_size_extension.dart';
import '../../data/models/process_options.dart';
import '../../services/analytics_service.dart';
import '../../services/crashlytics_service.dart';
import '../../services/image_service/image_processor.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class ImageStudioScreen extends StatefulWidget {
  final File initialImage;

  const ImageStudioScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<ImageStudioScreen> createState() => _ImageStudioScreenState();
}

enum _ResizeOption { none, exactPixels, percentage }
enum _CompressionMode { targetSize, quality, none }

class _ImageStudioScreenState extends State<ImageStudioScreen> {
  late File _currentImage;
  int _originalWidth = 0;
  int _originalHeight = 0;
  int _fileSizeBytes = 0;
  bool _isLoadingInfo = true;
  bool _isProcessing = false;

  // 1. Crop State
  bool _hasCropped = false;

  // 2. Resize State
  _ResizeOption _resizeOption = _ResizeOption.none;
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  bool _keepAspectRatio = true;
  int _selectedPercentage = 50;

  // 3. Compress & Quality State
  _CompressionMode _compressionMode = _CompressionMode.targetSize;
  late TextEditingController _targetSizeController;
  int _selectedTargetSizeKB = 50;

  // 4. Format & Quality State
  String _outputFormat = 'jpg';
  double _quality = 85;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
    _fileSizeBytes = _currentImage.lengthSync();

    _widthController = TextEditingController();
    _heightController = TextEditingController();
    _targetSizeController = TextEditingController(text: _selectedTargetSizeKB.toString());

    // Auto-detect format from file extension
    final ext = p.extension(_currentImage.path).replaceAll('.', '').toLowerCase();
    if (ext == 'png' || ext == 'webp') {
      _outputFormat = ext;
    } else {
      _outputFormat = 'jpg';
    }

    _loadImageMetadata();
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _targetSizeController.dispose();
    super.dispose();
  }

  Future<void> _loadImageMetadata() async {
    try {
      final bytes = await _currentImage.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded != null) {
        setState(() {
          _originalWidth = decoded.width;
          _originalHeight = decoded.height;
          _widthController.text = (_originalWidth * 0.5).round().toString();
          _heightController.text = (_originalHeight * 0.5).round().toString();
          _isLoadingInfo = false;
        });
      }
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(
        e,
        stack,
        reason: 'Failed to read image metadata in ImageStudioScreen',
      );
      setState(() => _isLoadingInfo = false);
    }
  }

  Future<void> _handleRePickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked != null && mounted) {
      setState(() {
        _currentImage = File(picked.path);
        _fileSizeBytes = _currentImage.lengthSync();
        _hasCropped = false;
        _isLoadingInfo = true;
      });
      await _loadImageMetadata();
    }
  }

  Future<void> _handleCrop() async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _currentImage.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Studio Crop & Rotate',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
          IOSUiSettings(
            title: 'Studio Crop & Rotate',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
            ],
          ),
        ],
      );

      if (cropped != null && mounted) {
        setState(() {
          _currentImage = File(cropped.path);
          _fileSizeBytes = _currentImage.lengthSync();
          _hasCropped = true;
          _isLoadingInfo = true;
        });
        await _loadImageMetadata();
      }
    } catch (e) {
      debugPrint('Crop tool not supported on this platform: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cropping is currently supported on mobile (Android/iOS).'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    }
  }

  void _onWidthChanged(String value) {
    if (!_keepAspectRatio || _originalWidth == 0) return;
    final w = int.tryParse(value);
    if (w != null && w > 0) {
      final h = (_originalHeight * (w / _originalWidth)).round();
      _heightController.text = h.toString();
    }
  }

  void _onHeightChanged(String value) {
    if (!_keepAspectRatio || _originalHeight == 0) return;
    final h = int.tryParse(value);
    if (h != null && h > 0) {
      final w = (_originalWidth * (h / _originalHeight)).round();
      _widthController.text = w.toString();
    }
  }

  Future<void> _handleProcessAndSave() async {
    int? targetKB;
    int quality = 85;

    if (_compressionMode == _CompressionMode.targetSize) {
      targetKB = int.tryParse(_targetSizeController.text.trim());
      if (targetKB == null || targetKB <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid target size (KB)')),
        );
        return;
      }
    } else if (_compressionMode == _CompressionMode.quality) {
      quality = _quality.round();
    } else {
      // Both compression options off: encode at standard high quality
      quality = 90;
    }

    setState(() => _isProcessing = true);

    await CrashlyticsService.setProcessingContext(
      operation: 'studio_process',
      inputWidth: _originalWidth,
      inputHeight: _originalHeight,
      inputSizeKb: (_fileSizeBytes / 1024).round(),
      outputFormat: _outputFormat,
    );

    try {
      ResizeMode resizeMode = ResizeMode.none;
      int? targetW;
      int? targetH;
      int? percentage;

      if (_resizeOption == _ResizeOption.exactPixels) {
        resizeMode = ResizeMode.exactPixels;
        targetW = int.tryParse(_widthController.text.trim());
        targetH = int.tryParse(_heightController.text.trim());
      } else if (_resizeOption == _ResizeOption.percentage) {
        resizeMode = ResizeMode.percentage;
        percentage = _selectedPercentage;
      }

      final options = ProcessOptions(
        sourcePath: _currentImage.path,
        targetSizeKB: targetKB,
        quality: quality,
        outputFormat: _outputFormat,
        resizeMode: resizeMode,
        targetWidth: targetW,
        targetHeight: targetH,
        resizePercentage: percentage,
        keepAspectRatio: _keepAspectRatio,
      );

      final result = await ImageProcessor.processImage(options);

      AnalyticsService.logCompressionUsed(
        targetQuality: result.finalQuality,
        originalSizeKb: (_fileSizeBytes / 1024).round(),
        compressedSizeKb: (result.outputSizeBytes / 1024).round(),
      );

      await CrashlyticsService.clearProcessingContext();

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e, stack) {
      CrashlyticsService.recordNonFatalError(e, stack, reason: 'ImageStudio processing error');

      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = context.isMediumOrWider;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Image Studio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            tooltip: 'Change Image',
            onPressed: _isProcessing ? null : _handleRePickImage,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoadingInfo
            ? const Center(child: CircularProgressIndicator())
            : AdaptiveSupportingPane(
                primaryPane: _buildPreviewCard(isDark, isWide: isWide),
                supportingPane: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Studio Step 1: Dimensions & Resize
                    _buildResizeSection(isDark),
                    const SizedBox(height: 16),

                    // 2. Studio Step 2: Target File Size (Compress)
                    _buildCompressSection(isDark),
                    const SizedBox(height: 16),

                    // 3. Studio Step 3: Output Format & Quality
                    _buildFormatSection(isDark),
                    const SizedBox(height: 24),
                  ],
                ),
                bottomAction: _buildStickyBottomBar(isDark, isWide: isWide),
              ),
      ),
    );
  }

  // --- UI Component Builders ---

  Widget _buildPreviewCard(bool isDark, {bool isWide = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide
          ? Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      width: double.infinity,
                      color: isDark ? Colors.black26 : Colors.grey.shade100,
                      padding: const EdgeInsets.all(16),
                      child: Image.file(
                        _currentImage,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_originalWidth × $_originalHeight px',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fileSizeBytes.toReadableFileSize(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _handleCrop,
                        icon: const Icon(Icons.crop, size: 16),
                        label: Text(
                          _hasCropped ? 'Re-Crop' : 'Crop / Rotate',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: isDark ? Colors.black26 : Colors.grey.shade100,
                    child: Image.file(
                      _currentImage,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_originalWidth × $_originalHeight px',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _fileSizeBytes.toReadableFileSize(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      OutlinedButton.icon(
                        onPressed: _isProcessing ? null : _handleCrop,
                        icon: const Icon(Icons.crop, size: 15),
                        label: Text(
                          _hasCropped ? 'Re-Crop' : 'Crop / Rotate',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResizeSection(bool isDark) {
    return _buildStudioCard(
      isDark: isDark,
      icon: Icons.aspect_ratio_rounded,
      iconColor: AppColors.secondary,
      title: '1. Resize Dimensions',
      subtitle: _getResizeSubtitle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_ResizeOption>(
            segments: const [
              ButtonSegment(
                value: _ResizeOption.none,
                label: Text('Original'),
                icon: Icon(Icons.check_circle_outline, size: 16),
              ),
              ButtonSegment(
                value: _ResizeOption.exactPixels,
                label: Text('Pixels'),
                icon: Icon(Icons.numbers, size: 16),
              ),
              ButtonSegment(
                value: _ResizeOption.percentage,
                label: Text('Scale'),
                icon: Icon(Icons.percent, size: 16),
              ),
            ],
            selected: {_resizeOption},
            onSelectionChanged: (set) {
              setState(() => _resizeOption = set.first);
            },
          ),
          if (_resizeOption == _ResizeOption.exactPixels) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Width (px)',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: _onWidthChanged,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _keepAspectRatio ? Icons.link : Icons.link_off,
                    color: _keepAspectRatio ? AppColors.primary : Colors.grey,
                  ),
                  tooltip: _keepAspectRatio ? 'Aspect Ratio Locked' : 'Aspect Ratio Unlocked',
                  onPressed: () {
                    setState(() => _keepAspectRatio = !_keepAspectRatio);
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Height (px)',
                      filled: true,
                      fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: _onHeightChanged,
                  ),
                ),
              ],
            ),
          ],
          if (_resizeOption == _ResizeOption.percentage) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              children: [25, 50, 75].map((pct) {
                final isSelected = _selectedPercentage == pct;
                return ChoiceChip(
                  label: Text('$pct%'),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedPercentage = pct);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompressSection(bool isDark) {
    return _buildStudioCard(
      isDark: isDark,
      icon: Icons.compress_rounded,
      iconColor: AppColors.primary,
      title: '2. Compression & Quality',
      subtitle: _getCompressionSubtitle(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<_CompressionMode>(
            segments: const [
              ButtonSegment(
                value: _CompressionMode.targetSize,
                label: Text('Target KB'),
                icon: Icon(Icons.compress, size: 16),
              ),
              ButtonSegment(
                value: _CompressionMode.quality,
                label: Text('Quality %'),
                icon: Icon(Icons.tune, size: 16),
              ),
              ButtonSegment(
                value: _CompressionMode.none,
                label: Text('Off'),
                icon: Icon(Icons.block, size: 16),
              ),
            ],
            selected: {_compressionMode},
            onSelectionChanged: (set) {
              setState(() => _compressionMode = set.first);
            },
          ),
          const SizedBox(height: 14),

          // Option A: Target Size Mode
          if (_compressionMode == _CompressionMode.targetSize) ...[
            TextField(
              controller: _targetSizeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                hintText: 'e.g. 50',
                suffixText: 'KB',
                suffixStyle: const TextStyle(fontWeight: FontWeight.bold),
                filled: true,
                fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null) {
                  setState(() => _selectedTargetSizeKB = parsed);
                }
              },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [20, 50, 100, 200, 500, 1024].map((sizeKb) {
                final isSelected = _targetSizeController.text == sizeKb.toString();
                final label = sizeKb >= 1024 ? '1 MB' : '$sizeKb KB';
                return ChoiceChip(
                  label: Text(label, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _selectedTargetSizeKB = sizeKb;
                        _targetSizeController.text = sizeKb.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
          ],

          // Option B: Quality % Mode
          if (_compressionMode == _CompressionMode.quality) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Encoding Quality:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_quality.round()}%',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
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
              activeColor: AppColors.primary,
              onChanged: (val) => setState(() => _quality = val),
            ),
            Wrap(
              spacing: 6,
              children: [40, 60, 80, 90, 100].map((q) {
                final isSelected = _quality.round() == q;
                return ChoiceChip(
                  label: Text('$q%', style: const TextStyle(fontSize: 11)),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _quality = q.toDouble());
                  },
                );
              }).toList(),
            ),
          ],

          // Option C: Both Off Mode
          if (_compressionMode == _CompressionMode.none) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compression controls are turned off. Standard output quality will be used with no size limit.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFormatSection(bool isDark) {
    return _buildStudioCard(
      isDark: isDark,
      icon: Icons.transform_rounded,
      iconColor: Colors.purple,
      title: '3. Output Format',
      subtitle: _outputFormat.toUpperCase(),
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'jpg', label: Text('JPG')),
          ButtonSegment(value: 'png', label: Text('PNG')),
          ButtonSegment(value: 'webp', label: Text('WebP')),
        ],
        selected: {_outputFormat},
        onSelectionChanged: (set) {
          setState(() => _outputFormat = set.first);
        },
      ),
    );
  }

  Widget _buildStickyBottomBar(bool isDark, {bool isWide = false}) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 16 : 20,
        12,
        isWide ? 16 : 20,
        isWide ? 16 : 12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: isWide ? BorderRadius.circular(16) : null,
        border: isWide
            ? Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              )
            : Border(
                top: BorderSide(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Summary:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              Text(
                _getPipelineSummary(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GradientButton(
            text: 'Process & Save Image',
            icon: Icons.bolt_rounded,
            isLoading: _isProcessing,
            onPressed: _isProcessing ? null : _handleProcessAndSave,
          ),
        ],
      ),
    );
  }

  Widget _buildStudioCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  String _getResizeSubtitle() {
    switch (_resizeOption) {
      case _ResizeOption.none:
        return 'Original: $_originalWidth × $_originalHeight px';
      case _ResizeOption.exactPixels:
        return 'Custom: ${_widthController.text} × ${_heightController.text} px';
      case _ResizeOption.percentage:
        return 'Scale: $_selectedPercentage%';
    }
  }

  String _getCompressionSubtitle() {
    switch (_compressionMode) {
      case _CompressionMode.targetSize:
        return 'Target: under ${_targetSizeController.text} KB';
      case _CompressionMode.quality:
        return 'Quality: ${_quality.round()}%';
      case _CompressionMode.none:
        return 'Compression off (standard)';
    }
  }

  String _getPipelineSummary() {
    final formatStr = _outputFormat.toUpperCase();
    String compressStr;
    switch (_compressionMode) {
      case _CompressionMode.targetSize:
        compressStr = '< ${_targetSizeController.text} KB';
        break;
      case _CompressionMode.quality:
        compressStr = '${_quality.round()}% Quality';
        break;
      case _CompressionMode.none:
        compressStr = 'No Limit';
        break;
    }
    final resizeStr = _resizeOption == _ResizeOption.none
        ? 'Original'
        : (_resizeOption == _ResizeOption.percentage ? '$_selectedPercentage%' : '${_widthController.text}w');
    return '$resizeStr • $compressStr • $formatStr';
  }
}
