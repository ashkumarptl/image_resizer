import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../services/image_service/perspective_cropper.dart';
import '../perspective_crop/perspective_crop_screen.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class DocumentFilterScreen extends StatefulWidget {
  final File initialImage;
  final bool returnFilteredFile;

  const DocumentFilterScreen({
    super.key,
    required this.initialImage,
    this.returnFilteredFile = false,
  });

  @override
  State<DocumentFilterScreen> createState() => _DocumentFilterScreenState();
}

class _DocumentFilterScreenState extends State<DocumentFilterScreen> {
  late File _currentImage;
  int _quarterTurns = 0;
  PerspectiveFilter _selectedFilter = PerspectiveFilter.documentBw;
  bool _isComparing = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentImage = widget.initialImage;
  }

  void _handleRotate() {
    HapticFeedback.lightImpact();
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
    });
  }

  void _openPerspectiveCrop() async {
    HapticFeedback.mediumImpact();
    final croppedFile = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => PerspectiveCropScreen(
          initialImage: _currentImage,
          returnCroppedFile: true,
        ),
      ),
    );

    if (croppedFile != null && mounted) {
      setState(() {
        _currentImage = croppedFile;
        _quarterTurns = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Document straightened! Now select your preferred filter.'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleApply() async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    try {
      final result = await PerspectiveCropper.processFilter(
        _currentImage,
        _selectedFilter,
        quarterTurns: _quarterTurns,
        quality: 92,
      );

      if (!mounted) return;
      setState(() => _isProcessing = false);

      if (widget.returnFilteredFile) {
        Navigator.of(context).pop(File(result.outputPath));
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ResultScreen(result: result),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply filter: $e'),
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
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(
          color: Colors.white,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document Scanner Filter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Remove shadows & convert to clean scan',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate_rounded, color: Colors.white),
            tooltip: 'Tilted? Straighten Corners',
            onPressed: _openPerspectiveCrop,
          ),
          IconButton(
            icon: const Icon(Icons.rotate_right_rounded, color: Colors.white),
            tooltip: 'Rotate 90°',
            onPressed: _handleRotate,
          ),
        ],
      ),
      body: SafeArea(
        child: isWide
            ? Row(
                children: [
                  Expanded(child: _buildPreviewArea()),
                  Container(
                    width: 360,
                    margin: const EdgeInsets.only(right: 16, top: 8, bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildControls(isDark, isWide: true),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: _buildPreviewArea()),
                  _buildBottomPanel(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    final activeFilter = _isComparing ? PerspectiveFilter.none : _selectedFilter;
    final colorFilter = DocumentFilterHelper.getColorFilter(activeFilter);

    Widget imageWidget = Image.file(
      _currentImage,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (colorFilter != null) {
      imageWidget = ColorFiltered(
        colorFilter: colorFilter,
        child: imageWidget,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Interactive Zoomable Filtered Image
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4.0,
            child: Center(
              child: RotatedBox(
                quarterTurns: _quarterTurns,
                child: imageWidget,
              ),
            ),
          ),

          // 2. Comparing Banner indicator
          if (_isComparing)
            Positioned(
              top: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber, width: 1.2),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Text(
                      'Showing Original (Unfiltered)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Floating "Hold to Compare" Button
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _isComparing = true),
              onTapUp: (_) => setState(() => _isComparing = false),
              onTapCancel: () => setState(() => _isComparing = false),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.compare_rounded, size: 16, color: Colors.white),
                    SizedBox(width: 6),
                    Text(
                      'Hold to Compare',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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

  Widget _buildBottomPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: _buildControls(isDark, isWide: false),
        ),
      ),
    );
  }

  Widget _buildControls(bool isDark, {bool isWide = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Select Filter Mode:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _openPerspectiveCrop,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.crop_rotate_rounded,
                      size: 14,
                      color: isDark ? AppColors.primaryLight : AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Deskew Doc',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Filter Selection Cards
        _buildFilterOption(
          filter: PerspectiveFilter.documentBw,
          title: 'Doc B&W (Clean Scan)',
          subtitle: 'Removes yellowing & shadows. High-contrast photocopy look.',
          icon: Icons.document_scanner_rounded,
          accentColor: Colors.blueAccent,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildFilterOption(
          filter: PerspectiveFilter.grayscale,
          title: 'Grayscale',
          subtitle: 'Clean monochrome tones for text, stamps & diagrams.',
          icon: Icons.filter_b_and_w_rounded,
          accentColor: Colors.teal,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildFilterOption(
          filter: PerspectiveFilter.enhanced,
          title: 'Vibrant / Enhanced',
          subtitle: 'Boosts contrast & colors for ID cards, certificates & marks cards.',
          icon: Icons.auto_awesome_rounded,
          accentColor: Colors.amber,
          isDark: isDark,
        ),
        const SizedBox(height: 8),
        _buildFilterOption(
          filter: PerspectiveFilter.none,
          title: 'Original',
          subtitle: 'Preserves natural camera photo colors without adjustments.',
          icon: Icons.image_outlined,
          accentColor: Colors.grey,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Apply Button
        GradientButton(
          text: 'Apply & Save Scan',
          icon: Icons.check_rounded,
          isLoading: _isProcessing,
          height: 48,
          onPressed: _isProcessing ? null : _handleApply,
        ),
      ],
    );
  }

  Widget _buildFilterOption({
    required PerspectiveFilter filter,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isDark,
  }) {
    final isSelected = _selectedFilter == filter;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = filter);
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? accentColor.withValues(alpha: 0.15)
                  : accentColor.withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF243044) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.2)
                    : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? accentColor : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: accentColor,
              ),
          ],
        ),
      ),
    );
  }
}
