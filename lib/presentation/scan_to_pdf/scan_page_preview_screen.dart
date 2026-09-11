import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/scan_project.dart';
import '../../services/scanner/scan_project_service.dart';
import '../../services/storage_service.dart';
import '../../services/system_integration_service.dart';
import '../studio/image_studio_screen.dart';
import '../widgets/image_source_picker_sheet.dart';
import '../widgets/login_gate_dialog.dart';

/// Fullscreen Image Preview Screen for a scanned document page,
/// matching CamScanner's preview and action flow, fully responsive on mobile & tablets.
class ScanPagePreviewScreen extends ConsumerStatefulWidget {
  final ScanProject project;
  final int initialIndex;
  final ScanProjectService? projectService;

  const ScanPagePreviewScreen({
    super.key,
    required this.project,
    this.initialIndex = 0,
    this.projectService,
  });

  @override
  ConsumerState<ScanPagePreviewScreen> createState() =>
      _ScanPagePreviewScreenState();
}

class _ScanPagePreviewScreenState extends ConsumerState<ScanPagePreviewScreen> {
  late final ScanProjectService _projectService =
      widget.projectService ?? ScanProjectService.instance;

  late ScanProject _project;
  late int _currentIndex;
  late PageController _pageController;
  bool _isLoading = false;
  bool _showChrome = true;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _currentIndex = widget.initialIndex.clamp(
      0,
      (_project.pagePaths.length - 1).clamp(0, 9999),
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  void _toggleChrome() {
    HapticFeedback.selectionClick();
    setState(() => _showChrome = !_showChrome);
  }

  Future<void> _handleStudioEdit() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    if (_currentIndex < 0 || _currentIndex >= _project.pagePaths.length) return;
    final pageFile = File(_project.pagePaths[_currentIndex]);
    if (!pageFile.existsSync()) return;

    final editedResult = await Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => ImageStudioScreen(
          initialImage: pageFile,
          returnResultDirectly: true,
          allowRePick: false,
        ),
      ),
    );

    if (editedResult != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final updated = await _projectService.replacePage(
          _project.id,
          _currentIndex,
          editedResult,
        );
        if (updated != null && mounted) {
          HapticFeedback.lightImpact();
          setState(() => _project = updated);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Page ${_currentIndex + 1} updated from Studio!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleReplace() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    if (_currentIndex < 0 || _currentIndex >= _project.pagePaths.length) return;

    final picked = await ImageSourcePickerSheet.show(
      context,
      title: 'Retake / Replace Page ${_currentIndex + 1}',
    );

    if (picked != null && mounted) {
      await _applyReplacement(picked);
    }
  }

  Future<void> _applyReplacement(File newFile) async {
    setState(() => _isLoading = true);
    try {
      final updated = await _projectService.replacePage(
        _project.id,
        _currentIndex,
        newFile,
      );
      if (updated != null && mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _project = updated);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Page ${_currentIndex + 1} replaced successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanPagePreviewScreen] Error replacing page: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSaveToGallery() async {
    if (_currentIndex < 0 || _currentIndex >= _project.pagePaths.length) return;
    final path = _project.pagePaths[_currentIndex];
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image file not found'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await StorageService.saveToGallery(path);
      if (mounted) {
        if (success) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text('Page saved to Gallery!'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save to Gallery (permission denied)'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ScanPagePreviewScreen] Save to gallery error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleDeleteCurrentPage() async {
    if (_project.pagePaths.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Page ${_currentIndex + 1}?'),
        content: const Text(
          'Are you sure you want to remove this page from the document?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final updated = await _projectService.deletePage(
          _project.id,
          _currentIndex,
        );
        if (updated != null && mounted) {
          if (updated.pagePaths.isEmpty) {
            Navigator.of(context).pop(updated);
            return;
          }
          final newIndex = _currentIndex >= updated.pagePaths.length
              ? updated.pagePaths.length - 1
              : _currentIndex;
          setState(() {
            _project = updated;
            _currentIndex = newIndex;
          });
          _pageController.jumpToPage(newIndex);
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleShareCurrentPage() async {
    if (_currentIndex < 0 || _currentIndex >= _project.pagePaths.length) return;
    final path = _project.pagePaths[_currentIndex];
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: '${_project.name} - Page ${_currentIndex + 1}',
        ),
      );
    } catch (e) {
      debugPrint('[ScanPagePreviewScreen] Share error: $e');
    }
  }

  Future<void> _handlePrintCurrentPage() async {
    if (_currentIndex < 0 || _currentIndex >= _project.pagePaths.length) return;
    final path = _project.pagePaths[_currentIndex];
    final file = File(path);
    if (!file.existsSync()) return;

    HapticFeedback.lightImpact();
    final printed = await SystemIntegrationService.instance.printImage(path);
    if (!printed && mounted) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          text: 'Print ${_project.name} - Page ${_currentIndex + 1}',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = context.isMediumOrWider;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.of(context).pop(_project);
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF1F5F9),
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 1),
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            offset: _showChrome ? Offset.zero : const Offset(0, -1.2),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 250),
              opacity: _showChrome ? 1.0 : 0.0,
              child: AppBar(
                backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                elevation: 0,
                scrolledUnderElevation: 1,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(1),
                  child: Divider(
                    height: 1,
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                leading: IconButton(
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  tooltip: 'Back',
                  onPressed: () => Navigator.of(context).pop(_project),
                ),
                title: Text(
                  _project.name,
                  style: TextStyle(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      Icons.print_rounded,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    tooltip: 'Print Page',
                    onPressed: _handlePrintCurrentPage,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.share_rounded,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    tooltip: 'Share Page',
                    onPressed: _handleShareCurrentPage,
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    tooltip: 'Delete Page',
                    onPressed: _handleDeleteCurrentPage,
                  ),
                ],
              ),
            ),
          ),
        ),
        body: _project.pagePaths.isEmpty
            ? Center(
                child: Text(
                  'No pages remaining',
                  style: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Interactive Page Viewer with Tap to Toggle Chrome
                  GestureDetector(
                    onTap: _toggleChrome,
                    behavior: HitTestBehavior.translucent,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _project.pagePaths.length,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, index) {
                        final file = File(_project.pagePaths[index]);
                        return InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isTablet ? 48.0 : 8.0,
                                vertical: 12.0,
                              ),
                              child: file.existsSync()
                                  ? Image.file(
                                      file,
                                      fit: BoxFit.contain,
                                      cacheWidth: isTablet ? 2000 : 1400,
                                    )
                                  : const Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Top-Left Page Badge (e.g. 1/6)
                  Positioned(
                    top: 16,
                    left: isTablet ? 32 : 16,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 250),
                      opacity: _showChrome ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 0.8),
                        ),
                        child: Text(
                          '${_currentIndex + 1}/${_project.pageCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Tablet Previous Page Floating Chevron
                  if (isTablet && _currentIndex > 0)
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _showChrome ? 1.0 : 0.0,
                          child: Material(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 30),
                              tooltip: 'Previous Page',
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Tablet Next Page Floating Chevron
                  if (isTablet && _currentIndex < _project.pagePaths.length - 1)
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: _showChrome ? 1.0 : 0.0,
                          child: Material(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.75),
                            shape: const CircleBorder(),
                            elevation: 4,
                            child: IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 30),
                              tooltip: 'Next Page',
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeInOutCubic,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                  if (_isLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(minHeight: 3),
                    ),
                ],
              ),
        bottomNavigationBar: AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          offset: _showChrome ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _showChrome ? 1.0 : 0.0,
            child: _buildBottomBar(isDark, isTablet),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark, bool isTablet) {
    final barContent = Row(
      children: [
        Expanded(
          child: _ActionItem(
            icon: Icons.tune_rounded,
            label: 'Studio Edit',
            tooltip: 'Edit in Studio',
            isDark: isDark,
            onTap: _handleStudioEdit,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: Icons.camera_alt_outlined,
            label: 'Replace',
            tooltip: 'Replace Page',
            isDark: isDark,
            onTap: _handleReplace,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: Icons.download_rounded,
            label: 'Save to Gallery',
            tooltip: 'Save to Gallery',
            isDark: isDark,
            onTap: _handleSaveToGallery,
          ),
        ),
        Expanded(
          child: _ActionItem(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            tooltip: 'Delete Page',
            isDark: isDark,
            isDestructive: true,
            onTap: _handleDeleteCurrentPage,
          ),
        ),
      ],
    );

    // Tablet: Floating pill dock centered at bottom
    if (isTablet) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1.0,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: barContent,
            ),
          ),
        ),
      );
    }

    // Mobile: Full-width bottom bar
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      child: barContent,
    );
  }
}

/// Interactive Action Item with micro-scale press animation
class _ActionItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool isDark;
  final bool isDestructive;
  final VoidCallback onTap;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.isDark,
    this.isDestructive = false,
    required this.onTap,
  });

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final defaultColor =
        widget.isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final iconColor = widget.isDestructive ? AppColors.error : defaultColor;
    final textColor = widget.isDestructive ? AppColors.error : defaultColor;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, color: iconColor, size: 22),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
