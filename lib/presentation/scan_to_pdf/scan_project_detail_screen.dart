import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/layout/adaptive_layout.dart';
import '../../data/models/scan_project.dart';
import '../../services/scanner/document_scanner_service.dart';
import '../../services/scanner/scan_project_service.dart';
import '../../services/storage_service.dart';
import '../../services/system_integration_service.dart';
import '../widgets/login_gate_dialog.dart';
import '../widgets/smooth_reorderable_grid.dart';
import 'scan_page_preview_screen.dart';

class ScanProjectDetailScreen extends ConsumerStatefulWidget {
  final ScanProject initialProject;
  final ScanProjectService? projectService;
  final DocumentScannerService? scannerService;

  const ScanProjectDetailScreen({
    super.key,
    required this.initialProject,
    this.projectService,
    this.scannerService,
  });

  @override
  ConsumerState<ScanProjectDetailScreen> createState() =>
      _ScanProjectDetailScreenState();
}

class _ScanProjectDetailScreenState
    extends ConsumerState<ScanProjectDetailScreen> {
  late final ScanProjectService _projectService =
      widget.projectService ?? ScanProjectService.instance;
  late final DocumentScannerService _scannerService =
      widget.scannerService ?? DocumentScannerService();
  late ScanProject _project;
  bool _isLoading = false;
  bool _isPdfSaved = false;
  bool _isGridView = false;
  final Set<int> _selectedPageIndices = {};
  bool get _isSelectionMode => _selectedPageIndices.isNotEmpty;

  void _clearSelection() {
    setState(() => _selectedPageIndices.clear());
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPageIndices.length == _project.pagePaths.length) {
        _selectedPageIndices.clear();
      } else {
        _selectedPageIndices.addAll(List.generate(_project.pagePaths.length, (i) => i));
      }
    });
  }

  void _togglePageSelection(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedPageIndices.contains(index)) {
        _selectedPageIndices.remove(index);
      } else {
        _selectedPageIndices.add(index);
      }
    });
  }

  void _selectSinglePage(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPageIndices
        ..clear()
        ..add(index);
    });
  }

  @override
  void initState() {
    super.initState();
    _project = widget.initialProject;
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Future<void> _handleRename() async {
    final controller = TextEditingController(text: _project.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Document Name',
            hintText: 'e.g. Aadhaar Card, Bill, Invoice',
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _project.name) {
      final updated = await _projectService.renameProject(_project.id, newName);
      if (updated != null && mounted) {
        setState(() => _project = updated);
      }
    }
  }

  Future<void> _handleAddPages() async {
    final canAccess = await checkFeatureAccess(context, ref);
    if (!canAccess || !mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),
                  Text(
                    'Add More Pages',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.document_scanner_rounded, color: AppColors.primary),
                    ),
                    title: Text(
                      'Scan with Camera',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Live edge detection & perspective auto-align',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop('camera'),
                  ),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                      child: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
                    ),
                    title: Text(
                      'Pick from Gallery',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Choose one or more existing photos',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop('gallery'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (choice == null || !mounted) return;

    setState(() => _isLoading = true);

    try {
      List<File> newFiles = [];
      if (choice == 'camera') {
        newFiles = await _scannerService.scanMultipleDocuments(pageLimit: 25);
      } else {
        final picker = ImagePicker();
        final picked = await picker.pickMultiImage();
        newFiles = picked.map((x) => File(x.path)).toList();
      }

      if (newFiles.isNotEmpty) {
        final updated = await _projectService.addPages(_project.id, newFiles);
        if (updated != null && mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _project = updated;
            _isPdfSaved = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ${newFiles.length} pages to ${_project.name}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[ScanProjectDetailScreen] Error adding pages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _handleGroupReorder(List<int> newOrder) async {
    if (newOrder.length != _project.pagePaths.length) return;

    bool hasChanged = false;
    for (int i = 0; i < newOrder.length; i++) {
      if (newOrder[i] != i) {
        hasChanged = true;
        break;
      }
    }
    if (!hasChanged) return;

    HapticFeedback.selectionClick();

    // 1. Optimistic in-memory update
    final updatedPaths = [for (final i in newOrder) _project.pagePaths[i]];
    final updatedOrigPaths = <String>[];
    for (final i in newOrder) {
      if (i < _project.originalPagePaths.length) {
        updatedOrigPaths.add(_project.originalPagePaths[i]);
      } else if (i < _project.pagePaths.length) {
        updatedOrigPaths.add(_project.pagePaths[i]);
      }
    }

    final updatedFilters = <String, String>{};
    for (int newIdx = 0; newIdx < newOrder.length; newIdx++) {
      final oldIdx = newOrder[newIdx];
      final filter = _project.pageFilters[oldIdx.toString()];
      if (filter != null) {
        updatedFilters[newIdx.toString()] = filter;
      }
    }

    // Remap selected indices to their new positions in the list
    final newSelected = <int>{};
    for (int newIdx = 0; newIdx < newOrder.length; newIdx++) {
      final oldIdx = newOrder[newIdx];
      if (_selectedPageIndices.contains(oldIdx)) {
        newSelected.add(newIdx);
      }
    }

    setState(() {
      _project = _project.copyWith(
        pagePaths: updatedPaths,
        originalPagePaths: updatedOrigPaths,
        pageFilters: updatedFilters,
      );
      _selectedPageIndices
        ..clear()
        ..addAll(newSelected);
      _isPdfSaved = false;
    });

    // 2. Persist to storage and regenerate PDF in the background
    try {
      final updated = await _projectService.reorderPagesOrder(_project.id, newOrder);
      if (updated != null && mounted) {
        setState(() {
          _project = updated;
          _isPdfSaved = false;
        });
      }
    } catch (e) {
      final all = await _projectService.loadProjects();
      final restored = all.where((p) => p.id == _project.id).firstOrNull;
      if (restored != null && mounted) {
        setState(() {
          _project = restored;
          _isPdfSaved = false;
        });
      }
    }
  }

  Future<void> _handleDeleteSelectedPages() async {
    if (_selectedPageIndices.isEmpty) return;

    final count = _selectedPageIndices.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(count == 1 ? 'Delete Page?' : 'Delete $count Pages?'),
        content: Text(
          count == 1
              ? 'Are you sure you want to delete this page?'
              : 'Are you sure you want to delete these $count pages? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    final toDelete = Set<int>.from(_selectedPageIndices);
    _clearSelection();

    final updated = await _projectService.deletePages(_project.id, toDelete);
    if (updated != null && mounted) {
      setState(() {
        _project = updated;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleShareSelectedPages() async {
    if (_selectedPageIndices.isEmpty) return;
    final sortedIndices = _selectedPageIndices.toList()..sort();
    final selectedFiles = <File>[];
    for (final idx in sortedIndices) {
      if (idx >= 0 && idx < _project.pagePaths.length) {
        final f = File(_project.pagePaths[idx]);
        if (f.existsSync()) selectedFiles.add(f);
      }
    }
    if (selectedFiles.isEmpty) return;

    final shareFormat = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  'Share ${selectedFiles.length} Selected ${selectedFiles.length == 1 ? 'Page' : 'Pages'}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose format to share with apps or contacts',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6366F1)),
                  ),
                  title: const Text('Share as PDF Document', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Compile ${selectedFiles.length} pages into a single PDF',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  onTap: () => Navigator.of(ctx).pop('pdf'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Share as Image Files', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Share ${selectedFiles.length} individual JPG/PNG images',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  onTap: () => Navigator.of(ctx).pop('images'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (shareFormat == null || !mounted) return;

    if (shareFormat == 'images') {
      try {
        await SharePlus.instance.share(
          ShareParams(
            files: selectedFiles.map((f) => XFile(f.path)).toList(),
            text: '${_project.name} (${selectedFiles.length} pages)',
          ),
        );
      } catch (e) {
        debugPrint('[ScanProjectDetailScreen] Share images error: $e');
      }
    } else if (shareFormat == 'pdf') {
      setState(() => _isLoading = true);
      try {
        final quality = PdfQualityPreset.fromString(_project.pdfQuality);
        final tempPdf = await DocumentScannerService.createPdfFromImages(
          selectedFiles,
          outputFileName: '${_project.name}_selected_${DateTime.now().millisecondsSinceEpoch}.pdf',
          qualityPreset: quality,
        );
        if (mounted) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(tempPdf.path)],
              text: '${_project.name} (${selectedFiles.length} pages)',
            ),
          );
        }
      } catch (e) {
        debugPrint('[ScanProjectDetailScreen] Share PDF error: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _handleSaveSelectedPagesToDevice() async {
    if (_selectedPageIndices.isEmpty) return;
    final sortedIndices = _selectedPageIndices.toList()..sort();
    final selectedFiles = <File>[];
    for (final idx in sortedIndices) {
      if (idx >= 0 && idx < _project.pagePaths.length) {
        final f = File(_project.pagePaths[idx]);
        if (f.existsSync()) selectedFiles.add(f);
      }
    }
    if (selectedFiles.isEmpty) return;

    final saveChoice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Material(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 16),
                Text(
                  'Save ${selectedFiles.length} Selected ${selectedFiles.length == 1 ? 'Page' : 'Pages'} to Device',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose destination format',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Save to Photos / Gallery', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Save ${selectedFiles.length} pages as photos in device Gallery',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  onTap: () => Navigator.of(ctx).pop('gallery'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF6366F1)),
                  ),
                  title: const Text('Save as PDF to Downloads', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    'Export selected ${selectedFiles.length} pages as a PDF document',
                    style: TextStyle(fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                  ),
                  onTap: () => Navigator.of(ctx).pop('pdf'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (saveChoice == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      if (saveChoice == 'gallery') {
        int savedCount = 0;
        for (final file in selectedFiles) {
          final success = await StorageService.saveToGallery(file.path);
          if (success) savedCount++;
        }
        if (mounted) {
          HapticFeedback.mediumImpact();
          if (savedCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      savedCount == 1
                          ? 'Saved 1 page to Gallery!'
                          : 'Saved $savedCount pages to Gallery!',
                    ),
                  ],
                ),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
            _clearSelection();
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
      } else if (saveChoice == 'pdf') {
        final quality = PdfQualityPreset.fromString(_project.pdfQuality);
        final tempPdf = await DocumentScannerService.createPdfFromImages(
          selectedFiles,
          outputFileName: '${_project.name}_selected_${DateTime.now().millisecondsSinceEpoch}.pdf',
          qualityPreset: quality,
        );

        final customName = '${_project.name.replaceAll(' ', '_')}_${selectedFiles.length}pages.pdf';
        final savedFile = await StorageService.savePdfToDevice(
          tempPdf.path,
          customFileName: customName,
        );

        if (savedFile != null && mounted) {
          HapticFeedback.mediumImpact();
          final fileName = savedFile.path.split('/').last;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to Downloads: $fileName'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(savedFile.path)],
                      text: fileName,
                    ),
                  );
                },
              ),
            ),
          );
          _clearSelection();
        }
      }
    } catch (e) {
      debugPrint('[ScanProjectDetailScreen] Error saving selected pages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePrintSelectedPages() async {
    if (_selectedPageIndices.isEmpty) return;
    final sortedIndices = _selectedPageIndices.toList()..sort();
    final selectedFiles = <File>[];
    for (final idx in sortedIndices) {
      if (idx >= 0 && idx < _project.pagePaths.length) {
        final f = File(_project.pagePaths[idx]);
        if (f.existsSync()) selectedFiles.add(f);
      }
    }
    if (selectedFiles.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      final quality = PdfQualityPreset.fromString(_project.pdfQuality);
      final tempPdf = await DocumentScannerService.createPdfFromImages(
        selectedFiles,
        outputFileName:
            '${_project.name}_print_${DateTime.now().millisecondsSinceEpoch}.pdf',
        qualityPreset: quality,
      );

      final printed =
          await SystemIntegrationService.instance.printPdf(tempPdf.path);
      if (!printed && mounted) {
        // Fallback: Share to system print dialog or printer app
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(tempPdf.path)],
            text: 'Print ${_project.name} (${selectedFiles.length} pages)',
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanProjectDetailScreen] Print selected pages error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handlePrintProject() async {
    if (_project.pagePaths.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      File? pdfToPrint;
      if (_project.pdfPath != null) {
        final existing = File(_project.pdfPath!);
        if (existing.existsSync()) {
          pdfToPrint = existing;
        }
      }
      if (pdfToPrint == null) {
        final quality = PdfQualityPreset.fromString(_project.pdfQuality);
        final files = _project.pagePaths
            .map((p) => File(p))
            .where((f) => f.existsSync())
            .toList();
        if (files.isEmpty) return;
        pdfToPrint = await DocumentScannerService.createPdfFromImages(
          files,
          outputFileName:
              '${_project.name}_print_${DateTime.now().millisecondsSinceEpoch}.pdf',
          qualityPreset: quality,
        );
      }

      final printed =
          await SystemIntegrationService.instance.printPdf(pdfToPrint.path);
      if (!printed && mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(pdfToPrint.path)],
            text: 'Print ${_project.name}',
          ),
        );
      }
    } catch (e) {
      debugPrint('[ScanProjectDetailScreen] Error printing project PDF: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSelectPdfQuality() async {
    final currentPreset = PdfQualityPreset.fromString(_project.pdfQuality);
    final chosen = await showModalBottomSheet<PdfQualityPreset>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 16),
                  Text(
                    'Target PDF Size',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set target size to match exam, job application, or email upload limits',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...PdfQualityPreset.values.map((preset) {
                    final isSelected = preset == currentPreset;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.1)
                            : (isDark
                                ? AppColors.surfaceVariantDark.withValues(alpha: 0.5)
                                : AppColors.surfaceVariantLight.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Row(
                            children: [
                              Text(
                                preset.label,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                ),
                              ),
                              if (preset == PdfQualityPreset.medium) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'EXAMS',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            preset.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                              : null,
                          onTap: () => Navigator.of(ctx).pop(preset),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (chosen != null && chosen != currentPreset && mounted) {
      setState(() => _isLoading = true);
      try {
        final updated = await _projectService.updatePdfQualityPreset(_project.id, chosen);
        if (updated != null && mounted) {
          HapticFeedback.mediumImpact();
          setState(() {
            _project = updated;
            _isPdfSaved = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Target size set to ${chosen.label} (${_formatBytes(_project.pdfSizeBytes)})'),
              backgroundColor: AppColors.primary,
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

  Future<void> _handleOpenPreview(int index) async {
    final updated = await Navigator.of(context).push<ScanProject>(
      MaterialPageRoute(
        builder: (_) => ScanPagePreviewScreen(
          project: _project,
          initialIndex: index,
          projectService: _projectService,
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _project = updated;
        _isPdfSaved = false;
      });
    }
  }

  Future<void> _handleSavePdf() async {
    if (_project.pdfPath == null) return;

    setState(() => _isLoading = true);
    try {
      final savedFile = await StorageService.savePdfToDevice(
        _project.pdfPath!,
        customFileName: '${_project.name.replaceAll(' ', '_')}.pdf',
      );

      if (savedFile != null && mounted) {
        HapticFeedback.mediumImpact();
        setState(() => _isPdfSaved = true);
        final fileName = savedFile.path.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads: $fileName'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Share',
              textColor: Colors.white,
              onPressed: _handleSharePdf,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSharePdf() async {
    if (_project.pdfPath == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_project.pdfPath!)],
          text: '${_project.name} (${_project.pageCount} pages)',
        ),
      );
    } catch (e) {
      debugPrint('[ScanProjectDetailScreen] Share error: $e');
    }
  }

  Future<void> _handleDeleteProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${_project.name}"?'),
        content: const Text(
          'This will permanently delete this document and all its scanned pages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Delete Project'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _projectService.deleteProject(_project.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeStr = _formatBytes(_project.pdfSizeBytes);
    final currentQuality = PdfQualityPreset.fromString(_project.pdfQuality);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel Selection',
                onPressed: _clearSelection,
              ),
              title: Text(
                '${_selectedPageIndices.length} Selected',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedPageIndices.length == _project.pagePaths.length
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                  ),
                  tooltip: _selectedPageIndices.length == _project.pagePaths.length
                      ? 'Deselect All'
                      : 'Select All',
                  onPressed: _toggleSelectAll,
                ),
              ],
            )
          : AppBar(
              title: InkWell(
                onTap: _handleRename,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _project.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_isGridView ? Icons.view_agenda_rounded : Icons.grid_view_rounded),
                  tooltip: _isGridView ? 'List View' : 'Grid View',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _isGridView = !_isGridView);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded),
                  tooltip: 'Share PDF',
                  onPressed: _handleSharePdf,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (val) {
                    if (val == 'rename') _handleRename();
                    if (val == 'quality') _handleSelectPdfQuality();
                    if (val == 'print') _handlePrintProject();
                    if (val == 'delete') _handleDeleteProject();
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Rename Document'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'quality',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Target PDF Size'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'print',
                      child: Row(
                        children: [
                          Icon(Icons.print_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Print Document'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Delete Document', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Metadata banner with Target Size selector chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark
                  ? AppColors.surfaceDark.withValues(alpha: 0.6)
                  : Colors.grey.shade100,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final showFullHint = constraints.maxWidth >= 380;
                  final showHintText = constraints.maxWidth >= 310;
                  final hasReorderHint = _project.pageCount > 1;

                  return Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            // Page count badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_project.pageCount} ${_project.pageCount == 1 ? 'PAGE' : 'PAGES'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Target PDF Size Chip (Clickable to change preset)
                            Flexible(
                              child: InkWell(
                                key: const ValueKey('target_pdf_size_chip'),
                                onTap: _handleSelectPdfQuality,
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.tune_rounded, size: 11, color: Color(0xFF10B981)),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          currentQuality.label,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF059669),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            Text(
                              sizeStr,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Reorder guidance hint
                      if (hasReorderHint) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_outlined,
                              size: 13,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                            if (showHintText) ...[
                              const SizedBox(width: 3),
                              Text(
                                showFullHint ? 'Hold & drag to reorder' : 'Drag to reorder',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),

            if (_isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const Divider(height: 1),

            // Pages List or Grid
            Expanded(
              child: _project.pagePaths.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 54, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('No pages left in document'),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _handleAddPages,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Add Pages'),
                          ),
                        ],
                      ),
                    )
                  : _isGridView
                      ? _buildGridView(context, isDark)
                      : _buildListView(context, isDark),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _isSelectionMode
          ? _buildSelectionBottomBar(context, isDark)
          : _buildBottomBar(context, isDark),
    );
  }

  Widget _buildListView(BuildContext context, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 32;
            final targetHeight = constraints.maxWidth > 600 ? 520.0 : 420.0;
            final childAspectRatio = availableWidth / targetHeight;

            return SmoothReorderableGrid(
              key: const ValueKey('list_view_smooth_grid'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _project.pagePaths.length,
              crossAxisCount: 1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 0,
              childAspectRatio: childAspectRatio,
              itemKeyBuilder: (index) => ValueKey('list_page_${_project.pagePaths[index]}'),
              selectedIndexes: _selectedPageIndices,
              enableMultiSelection: true,
              onTapItem: (index) {
                if (_isSelectionMode) {
                  _togglePageSelection(index);
                } else {
                  _handleOpenPreview(index);
                }
              },
              onLongPressSelect: (index) {
                _selectSinglePage(index);
              },
              onGroupReorder: (newOrder) {
                _handleGroupReorder(newOrder);
              },
              itemBuilder: (context, index, isDragging) {
                final isSelected = _selectedPageIndices.contains(index);
                return _buildPageCard(
                  context,
                  index,
                  isDark,
                  isSelected: isSelected,
                  isFeedback: isDragging,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildGridView(BuildContext context, bool isDark) {
    return SmoothReorderableGrid(
      key: const ValueKey('grid_view_smooth_grid'),
      padding: EdgeInsets.fromLTRB(context.adaptiveMargin, 16, context.adaptiveMargin, 100),
      itemCount: _project.pagePaths.length,
      crossAxisCount: context.responsiveValue(compact: 2, medium: 3, expanded: 4, large: 5),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.68,
      itemKeyBuilder: (index) => ValueKey('grid_page_${_project.pagePaths[index]}'),
      selectedIndexes: _selectedPageIndices,
      enableMultiSelection: true,
      onTapItem: (index) {
        if (_isSelectionMode) {
          _togglePageSelection(index);
        } else {
          _handleOpenPreview(index);
        }
      },
      onLongPressSelect: (index) {
        _selectSinglePage(index);
      },
      onGroupReorder: (newOrder) {
        _handleGroupReorder(newOrder);
      },
      itemBuilder: (context, index, isDragging) {
        final isSelected = _selectedPageIndices.contains(index);
        return _buildGridItem(
          context,
          index,
          isDark,
          isSelected: isSelected,
          isFeedback: isDragging,
        );
      },
    );
  }

  Widget _buildGridItem(
    BuildContext context,
    int index,
    bool isDark, {
    bool isSelected = false,
    bool isFeedback = false,
  }) {
    final pagePath = _project.pagePaths[index];
    final pageFile = File(pagePath);
    final highlight = isSelected || isFeedback;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlight
                    ? AppColors.primary
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: highlight ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isFeedback ? 0.35 : (isDark ? 0.3 : 0.06)),
                  blurRadius: isFeedback ? 20 : 6,
                  offset: Offset(0, isFeedback ? 8 : 2),
                  spreadRadius: isFeedback ? 2 : 0,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                pageFile.existsSync()
                    ? Image.file(
                        pageFile,
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                      )
                    : const Center(child: Icon(Icons.broken_image, size: 28, color: Colors.grey)),
                if (isSelected || _isSelectionMode || isFeedback)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: (isSelected || isFeedback)
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: (isSelected || isFeedback) ? 1.5 : 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: (isSelected || isFeedback)
                          ? const Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: Colors.white,
                            )
                          : const SizedBox(width: 14, height: 14),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (index + 1).toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: highlight
                ? AppColors.primary
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildPageCard(
    BuildContext context,
    int index,
    bool isDark, {
    bool isSelected = false,
    bool isFeedback = false,
  }) {
    final pagePath = _project.pagePaths[index];
    final pageFile = File(pagePath);
    final highlight = isSelected || isFeedback;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? AppColors.primary
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: highlight ? 2.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFeedback ? 0.35 : (isDark ? 0.3 : 0.08)),
            blurRadius: isFeedback ? 20 : 10,
            offset: Offset(0, isFeedback ? 8 : 3),
            spreadRadius: isFeedback ? 2 : 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full Image Display
          Container(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: pageFile.existsSync()
                ? Image.file(
                    pageFile,
                    fit: BoxFit.contain,
                    cacheWidth: 1000,
                  )
                : const Center(child: Icon(Icons.broken_image, size: 36, color: Colors.grey)),
          ),

          // 2. Top-Left: Page Badge (e.g. "1/6" matching CamScanner)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Text(
                '${index + 1}/${_project.pageCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          // 3. Top-Right: Selection Badge in selection mode
          if (isSelected || _isSelectionMode || isFeedback)
            Positioned(
              top: 12,
              right: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: (isSelected || isFeedback)
                      ? AppColors.primary
                      : Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: (isSelected || isFeedback) ? 1.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: (isSelected || isFeedback)
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : const SizedBox(width: 16, height: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                // Add Page Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleAddPages,
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: const Text(
                      'Add Pages',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Save PDF Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : (_isPdfSaved ? null : _handleSavePdf),
                    icon: Icon(
                      _isPdfSaved ? Icons.check_circle_rounded : Icons.download_rounded,
                      size: 18,
                      color: _isPdfSaved ? AppColors.success : Colors.white,
                    ),
                    label: Text(
                      _isPdfSaved ? 'Saved ✓' : 'Save PDF',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _isPdfSaved ? AppColors.success : Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPdfSaved
                          ? AppColors.success.withValues(alpha: 0.15)
                          : const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
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

  Widget _buildSelectionBottomBar(BuildContext context, bool isDark) {
    final count = _selectedPageIndices.length;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.center,
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              children: [
                // Share Selected Button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _handleShareSelectedPages,
                  icon: const Icon(Icons.share_rounded, size: 17),
                  label: Text(
                    'Share ($count)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Save to Device Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSaveSelectedPagesToDevice,
                  icon: const Icon(Icons.download_rounded, size: 17),
                  label: const Text(
                    'Save to Device',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Print Selected Icon Button
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.print_rounded, color: Color(0xFF6366F1), size: 20),
                  tooltip: 'Print Selected',
                  onPressed: _isLoading ? null : _handlePrintSelectedPages,
                ),
              ),
              const SizedBox(width: 6),

              // Delete Selected Icon Button
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  tooltip: 'Delete Selected',
                  onPressed: _isLoading ? null : _handleDeleteSelectedPages,
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
