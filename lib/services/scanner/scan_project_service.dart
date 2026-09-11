import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../data/models/scan_project.dart';
import '../image_service/perspective_cropper.dart';
import 'document_scanner_service.dart';

class ScanProjectService {
  static const String _metadataFileName = 'scan_projects_metadata.json';
  static ScanProjectService? _instance;
  final Directory? overrideBaseDirectory;

  ScanProjectService({this.overrideBaseDirectory});

  static ScanProjectService get instance => _instance ??= ScanProjectService();

  Future<Directory> _getBaseDirectory() async {
    if (overrideBaseDirectory != null) {
      if (!await overrideBaseDirectory!.exists()) {
        await overrideBaseDirectory!.create(recursive: true);
      }
      return overrideBaseDirectory!;
    }
    try {
      final appDocs = await getApplicationDocumentsDirectory();
      final dir = Directory('${appDocs.path}/scan_projects');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      final dir = Directory('${Directory.systemTemp.path}/scan_projects_test');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      return dir;
    }
  }

  Future<File> _getMetadataFile() async {
    final baseDir = await _getBaseDirectory();
    return File('${baseDir.path}/$_metadataFileName');
  }

  Future<List<ScanProject>> loadProjects() async {
    try {
      final file = await _getMetadataFile();
      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
      final projects = jsonList
          .map((item) => ScanProject.fromJson(item as Map<String, dynamic>))
          .where((p) {
            // Filter out projects whose folders no longer exist
            return p.pagePaths.any((path) => File(path).existsSync());
          })
          .toList();

      projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return projects;
    } catch (e) {
      debugPrint('[ScanProjectService] Error loading projects: $e');
      return [];
    }
  }

  Future<void> _saveAllProjects(List<ScanProject> projects) async {
    try {
      final file = await _getMetadataFile();
      final jsonList = projects.map((p) => p.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList), flush: true);
    } catch (e) {
      debugPrint('[ScanProjectService] Error saving projects metadata: $e');
    }
  }

  Future<ScanProject> createProject({
    required String name,
    required List<File> imageFiles,
    File? existingPdf,
  }) async {
    final baseDir = await _getBaseDirectory();
    final id = 'proj_${DateTime.now().millisecondsSinceEpoch}';
    final projectDir = Directory('${baseDir.path}/$id');
    await projectDir.create(recursive: true);

    final savedPagePaths = <String>[];
    final savedOriginalPagePaths = <String>[];
    for (int i = 0; i < imageFiles.length; i++) {
      final source = imageFiles[i];
      final targetPath = '${projectDir.path}/page_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final origPath = '${projectDir.path}/orig_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await source.copy(targetPath);
      final savedOrig = await source.copy(origPath);
      savedPagePaths.add(saved.path);
      savedOriginalPagePaths.add(savedOrig.path);
    }

    String? pdfPath;
    if (existingPdf != null && await existingPdf.exists()) {
      final targetPdfPath = '${projectDir.path}/document.pdf';
      final copiedPdf = await existingPdf.copy(targetPdfPath);
      pdfPath = copiedPdf.path;
    } else if (savedPagePaths.isNotEmpty) {
      final pages = savedPagePaths.map((p) => File(p)).toList();
      final generatedPdf = await DocumentScannerService.createPdfFromImages(
        pages,
        qualityPreset: PdfQualityPreset.medium,
      );
      final targetPdfPath = '${projectDir.path}/document.pdf';
      final savedPdf = await generatedPdf.copy(targetPdfPath);
      pdfPath = savedPdf.path;
    }

    final project = ScanProject(
      id: id,
      name: name.trim().isNotEmpty ? name.trim() : 'Document ${DateTime.now().day}/${DateTime.now().month}',
      pagePaths: savedPagePaths,
      originalPagePaths: savedOriginalPagePaths,
      pageFilters: const {},
      pdfQuality: 'medium',
      pdfPath: pdfPath,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final all = await loadProjects();
    all.insert(0, project);
    await _saveAllProjects(all);
    return project;
  }

  Future<ScanProject?> addPages(String projectId, List<File> newFiles) async {
    if (newFiles.isEmpty) return null;

    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }

    final updatedPaths = List<String>.from(project.pagePaths);
    final updatedOrigPaths = List<String>.from(project.originalPagePaths.isNotEmpty
        ? project.originalPagePaths
        : project.pagePaths);

    for (int i = 0; i < newFiles.length; i++) {
      final source = newFiles[i];
      final targetPath = '${projectDir.path}/page_${updatedPaths.length + i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final origPath = '${projectDir.path}/orig_${updatedPaths.length + i}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final saved = await source.copy(targetPath);
      final savedOrig = await source.copy(origPath);
      updatedPaths.add(saved.path);
      updatedOrigPaths.add(savedOrig.path);
    }

    // Re-compile PDF
    String? newPdfPath;
    if (updatedPaths.isNotEmpty) {
      final pages = updatedPaths.map((p) => File(p)).toList();
      final preset = PdfQualityPreset.fromString(project.pdfQuality);
      final generatedPdf = await DocumentScannerService.createPdfFromImages(
        pages,
        qualityPreset: preset,
      );
      final targetPdfPath = '${projectDir.path}/document.pdf';
      final savedPdf = await generatedPdf.copy(targetPdfPath);
      newPdfPath = savedPdf.path;
    }

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pdfPath: newPdfPath,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> replacePage(String projectId, int pageIndex, File newImageFile) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (pageIndex < 0 || pageIndex >= project.pagePaths.length) return null;

    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');
    final targetPath = '${projectDir.path}/page_replace_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final origPath = '${projectDir.path}/orig_replace_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final saved = await newImageFile.copy(targetPath);
    final savedOrig = await newImageFile.copy(origPath);

    // Delete old file if exists
    final oldFile = File(project.pagePaths[pageIndex]);
    if (await oldFile.exists()) {
      try {
        await oldFile.delete();
      } catch (_) {}
    }

    final updatedPaths = List<String>.from(project.pagePaths);
    final updatedOrigPaths = List<String>.from(project.originalPagePaths.isNotEmpty
        ? project.originalPagePaths
        : project.pagePaths);

    updatedPaths[pageIndex] = saved.path;
    if (pageIndex < updatedOrigPaths.length) {
      updatedOrigPaths[pageIndex] = savedOrig.path;
    } else {
      updatedOrigPaths.add(savedOrig.path);
    }

    final updatedFilters = Map<String, String>.from(project.pageFilters);
    updatedFilters.remove(pageIndex.toString());

    // Re-compile PDF
    final pages = updatedPaths.map((p) => File(p)).toList();
    final preset = PdfQualityPreset.fromString(project.pdfQuality);
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pageFilters: updatedFilters,
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> rotatePage(String projectId, int pageIndex, {int degrees = 90}) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (pageIndex < 0 || pageIndex >= project.pagePaths.length) return null;

    final pageFile = File(project.pagePaths[pageIndex]);
    if (!await pageFile.exists()) return null;

    final bytes = await pageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final rotated = img.copyRotate(decoded, angle: degrees);
    final rotatedBytes = img.encodeJpg(rotated, quality: 90);
    await pageFile.writeAsBytes(rotatedBytes, flush: true);

    // Also rotate the original source copy to keep non-destructive filter in sync
    if (project.originalPagePaths.isNotEmpty && pageIndex < project.originalPagePaths.length) {
      final origFile = File(project.originalPagePaths[pageIndex]);
      if (await origFile.exists()) {
        final origBytes = await origFile.readAsBytes();
        final origDecoded = img.decodeImage(origBytes);
        if (origDecoded != null) {
          final origRotated = img.copyRotate(origDecoded, angle: degrees);
          await origFile.writeAsBytes(img.encodeJpg(origRotated, quality: 92), flush: true);
        }
      }
    }

    // Re-compile PDF
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');
    final pages = project.pagePaths.map((p) => File(p)).toList();
    final preset = PdfQualityPreset.fromString(project.pdfQuality);
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> deletePage(String projectId, int pageIndex) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (pageIndex < 0 || pageIndex >= project.pagePaths.length) return null;

    final pathToDelete = project.pagePaths[pageIndex];
    final file = File(pathToDelete);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }

    final updatedPaths = List<String>.from(project.pagePaths)..removeAt(pageIndex);
    final updatedOrigPaths = List<String>.from(project.originalPagePaths.isNotEmpty
        ? project.originalPagePaths
        : project.pagePaths);
    if (pageIndex < updatedOrigPaths.length) {
      updatedOrigPaths.removeAt(pageIndex);
    }

    // Re-index filters
    final updatedFilters = <String, String>{};
    for (int i = 0; i < updatedPaths.length; i++) {
      final oldKey = (i >= pageIndex ? i + 1 : i).toString();
      if (project.pageFilters.containsKey(oldKey)) {
        updatedFilters[i.toString()] = project.pageFilters[oldKey]!;
      }
    }

    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');

    String? newPdfPath;
    if (updatedPaths.isNotEmpty) {
      final pages = updatedPaths.map((p) => File(p)).toList();
      final preset = PdfQualityPreset.fromString(project.pdfQuality);
      final generatedPdf = await DocumentScannerService.createPdfFromImages(
        pages,
        qualityPreset: preset,
      );
      final targetPdfPath = '${projectDir.path}/document.pdf';
      final savedPdf = await generatedPdf.copy(targetPdfPath);
      newPdfPath = savedPdf.path;
    }

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pageFilters: updatedFilters,
      pdfPath: newPdfPath,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> deletePages(String projectId, Set<int> pageIndices) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (pageIndices.isEmpty) return project;

    for (final pageIndex in pageIndices) {
      if (pageIndex >= 0 && pageIndex < project.pagePaths.length) {
        final pathToDelete = project.pagePaths[pageIndex];
        final file = File(pathToDelete);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (_) {}
        }
      }
    }

    final updatedPaths = <String>[];
    final updatedOrigPaths = <String>[];
    final updatedFilters = <String, String>{};

    for (int i = 0; i < project.pagePaths.length; i++) {
      if (!pageIndices.contains(i)) {
        final newIdx = updatedPaths.length;
        updatedPaths.add(project.pagePaths[i]);
        if (i < project.originalPagePaths.length) {
          updatedOrigPaths.add(project.originalPagePaths[i]);
        } else {
          updatedOrigPaths.add(project.pagePaths[i]);
        }
        final filter = project.pageFilters[i.toString()];
        if (filter != null) {
          updatedFilters[newIdx.toString()] = filter;
        }
      }
    }

    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');

    String? newPdfPath;
    if (updatedPaths.isNotEmpty) {
      final pages = updatedPaths.map((p) => File(p)).toList();
      final preset = PdfQualityPreset.fromString(project.pdfQuality);
      final generatedPdf = await DocumentScannerService.createPdfFromImages(
        pages,
        qualityPreset: preset,
      );
      final targetPdfPath = '${projectDir.path}/document.pdf';
      final savedPdf = await generatedPdf.copy(targetPdfPath);
      newPdfPath = savedPdf.path;
    }

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pageFilters: updatedFilters,
      pdfPath: newPdfPath,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> reorderPagesOrder(String projectId, List<int> newOrder) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (newOrder.length != project.pagePaths.length) return null;

    final updatedPaths = [for (final i in newOrder) project.pagePaths[i]];
    final updatedOrigPaths = <String>[];
    for (final i in newOrder) {
      if (i < project.originalPagePaths.length) {
        updatedOrigPaths.add(project.originalPagePaths[i]);
      } else if (i < project.pagePaths.length) {
        updatedOrigPaths.add(project.pagePaths[i]);
      }
    }

    final updatedFilters = <String, String>{};
    for (int newIdx = 0; newIdx < newOrder.length; newIdx++) {
      final oldIdx = newOrder[newIdx];
      final filter = project.pageFilters[oldIdx.toString()];
      if (filter != null) {
        updatedFilters[newIdx.toString()] = filter;
      }
    }

    // Re-compile PDF with new order
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');
    final pages = updatedPaths.map((p) => File(p)).toList();
    final preset = PdfQualityPreset.fromString(project.pdfQuality);
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pageFilters: updatedFilters,
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> reorderPages(String projectId, int oldIndex, int newIndex) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    final updatedPaths = List<String>.from(project.pagePaths);
    final updatedOrigPaths = List<String>.from(project.originalPagePaths.isNotEmpty
        ? project.originalPagePaths
        : project.pagePaths);

    if (oldIndex < 0 || oldIndex >= updatedPaths.length) return null;
    if (newIndex < 0 || newIndex >= updatedPaths.length) return null;
    if (oldIndex == newIndex) return project;

    final item = updatedPaths.removeAt(oldIndex);
    updatedPaths.insert(newIndex, item);

    if (oldIndex < updatedOrigPaths.length) {
      final origItem = updatedOrigPaths.removeAt(oldIndex);
      updatedOrigPaths.insert(newIndex.clamp(0, updatedOrigPaths.length), origItem);
    }

    // Re-index filters
    final oldFilterList = List<String?>.generate(
      project.pagePaths.length,
      (i) => project.pageFilters[i.toString()],
    );
    final movedFilter = oldFilterList.removeAt(oldIndex);
    oldFilterList.insert(newIndex, movedFilter);

    final updatedFilters = <String, String>{};
    for (int i = 0; i < oldFilterList.length; i++) {
      if (oldFilterList[i] != null) {
        updatedFilters[i.toString()] = oldFilterList[i]!;
      }
    }

    // Re-compile PDF with new order
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');
    final pages = updatedPaths.map((p) => File(p)).toList();
    final preset = PdfQualityPreset.fromString(project.pdfQuality);
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      originalPagePaths: updatedOrigPaths,
      pageFilters: updatedFilters,
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> applyFilterToPage(
    String projectId,
    int pageIndex,
    PerspectiveFilter filter,
  ) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    if (pageIndex < 0 || pageIndex >= project.pagePaths.length) return null;

    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');

    final origPath = (pageIndex < project.originalPagePaths.length)
        ? project.originalPagePaths[pageIndex]
        : project.pagePaths[pageIndex];
    final origFile = File(origPath);
    if (!await origFile.exists()) return null;

    final targetPath =
        '${projectDir.path}/page_filtered_${pageIndex}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final filteredFile = await PerspectiveCropper.applyFilterToFile(
      origFile,
      filter,
      outputPath: targetPath,
    );

    final updatedPaths = List<String>.from(project.pagePaths);
    updatedPaths[pageIndex] = filteredFile.path;

    final updatedFilters = Map<String, String>.from(project.pageFilters);
    updatedFilters[pageIndex.toString()] = filter.name;

    // Re-compile PDF
    final pages = updatedPaths.map((p) => File(p)).toList();
    final preset = PdfQualityPreset.fromString(project.pdfQuality);
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pagePaths: updatedPaths,
      pageFilters: updatedFilters,
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> updatePdfQualityPreset(
    String projectId,
    PdfQualityPreset preset,
  ) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    final baseDir = await _getBaseDirectory();
    final projectDir = Directory('${baseDir.path}/$projectId');

    final pages = project.pagePaths.map((p) => File(p)).toList();
    final generatedPdf = await DocumentScannerService.createPdfFromImages(
      pages,
      qualityPreset: preset,
    );
    final targetPdfPath = '${projectDir.path}/document.pdf';
    final savedPdf = await generatedPdf.copy(targetPdfPath);

    final updatedProject = project.copyWith(
      pdfQuality: preset.name,
      pdfPath: savedPdf.path,
      updatedAt: DateTime.now(),
    );

    all[index] = updatedProject;
    await _saveAllProjects(all);
    return updatedProject;
  }

  Future<ScanProject?> renameProject(String projectId, String newName) async {
    final all = await loadProjects();
    final index = all.indexWhere((p) => p.id == projectId);
    if (index == -1) return null;

    final project = all[index];
    final updated = project.copyWith(
      name: newName.trim().isNotEmpty ? newName.trim() : project.name,
      updatedAt: DateTime.now(),
    );

    all[index] = updated;
    await _saveAllProjects(all);
    return updated;
  }

  Future<bool> deleteProject(String projectId) async {
    try {
      final all = await loadProjects();
      all.removeWhere((p) => p.id == projectId);
      await _saveAllProjects(all);

      final baseDir = await _getBaseDirectory();
      final projectDir = Directory('${baseDir.path}/$projectId');
      if (await projectDir.exists()) {
        await projectDir.delete(recursive: true);
      }
      return true;
    } catch (e) {
      debugPrint('[ScanProjectService] Error deleting project $projectId: $e');
      return false;
    }
  }
}
