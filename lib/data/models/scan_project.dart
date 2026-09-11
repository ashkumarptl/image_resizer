import 'dart:io';

class ScanProject {
  final String id;
  final String name;
  final List<String> pagePaths;
  final List<String> originalPagePaths;
  final Map<String, String> pageFilters;
  final String pdfQuality;
  final String? pdfPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ScanProject({
    required this.id,
    required this.name,
    required this.pagePaths,
    List<String>? originalPagePaths,
    Map<String, String>? pageFilters,
    this.pdfQuality = 'medium',
    this.pdfPath,
    required this.createdAt,
    required this.updatedAt,
  })  : originalPagePaths = originalPagePaths ?? pagePaths,
        pageFilters = pageFilters ?? const {};

  int get pageCount => pagePaths.length;

  String? get coverImagePath => pagePaths.isNotEmpty ? pagePaths.first : null;

  int get pdfSizeBytes {
    if (pdfPath != null) {
      final file = File(pdfPath!);
      if (file.existsSync()) {
        return file.lengthSync();
      }
    }
    return 0;
  }

  ScanProject copyWith({
    String? id,
    String? name,
    List<String>? pagePaths,
    List<String>? originalPagePaths,
    Map<String, String>? pageFilters,
    String? pdfQuality,
    String? pdfPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScanProject(
      id: id ?? this.id,
      name: name ?? this.name,
      pagePaths: pagePaths ?? this.pagePaths,
      originalPagePaths: originalPagePaths ?? this.originalPagePaths,
      pageFilters: pageFilters ?? this.pageFilters,
      pdfQuality: pdfQuality ?? this.pdfQuality,
      pdfPath: pdfPath ?? this.pdfPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pagePaths': pagePaths,
      'originalPagePaths': originalPagePaths,
      'pageFilters': pageFilters,
      'pdfQuality': pdfQuality,
      'pdfPath': pdfPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ScanProject.fromJson(Map<String, dynamic> json) {
    final pages = (json['pagePaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    final origPages = (json['originalPagePaths'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        pages;

    final filters = (json['pageFilters'] as Map<String, dynamic>?)
            ?.map((k, v) => MapEntry(k, v.toString())) ??
        <String, String>{};

    return ScanProject(
      id: json['id'] as String,
      name: json['name'] as String,
      pagePaths: pages,
      originalPagePaths: origPages,
      pageFilters: filters,
      pdfQuality: (json['pdfQuality'] as String?) ?? 'medium',
      pdfPath: json['pdfPath'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}
