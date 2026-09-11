enum PresetCategory {
  exam,
  identity,
  social,
  custom,
}

enum ExamCategory {
  centralGovt('Central Govt', 'SSC, UPSC, Railways & Central recruitment'),
  statePsc('State PSC', 'State Public Service Commissions & Vyapam'),
  banking('Banking', 'IBPS, SBI PO, Clerk & Insurance'),
  defence('Defence', 'NDA, CDS, AFCAT, Agniveer & Armed Forces'),
  academic('Academic', 'GATE, JEE, NEET, CUET & Entrance Exams'),
  identity('ID & Docs', 'Passport, PAN, Aadhaar & National IDs');

  final String label;
  final String description;

  const ExamCategory(this.label, this.description);

  static ExamCategory? fromString(String? val) {
    if (val == null) return null;
    return ExamCategory.values.firstWhere(
      (c) => c.name == val,
      orElse: () => ExamCategory.centralGovt,
    );
  }
}

class ImagePreset {
  final String id;
  final String name;
  final String description;
  final PresetCategory category;
  final ExamCategory? examCategory;
  final List<String> searchKeywords;
  final int? targetSizeKB;
  final int? minSizeKB;
  final int? targetWidth;
  final int? targetHeight;
  final String outputFormat;
  final String badgeText;
  final String iconEmoji;
  final int? targetDpi;

  const ImagePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.examCategory,
    this.searchKeywords = const [],
    this.targetSizeKB,
    this.minSizeKB,
    this.targetWidth,
    this.targetHeight,
    this.outputFormat = 'jpg',
    required this.badgeText,
    this.iconEmoji = '📄',
    this.targetDpi,
  });

  bool matchesQuery(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return true;
    if (name.toLowerCase().contains(clean)) return true;
    if (description.toLowerCase().contains(clean)) return true;
    if (badgeText.toLowerCase().contains(clean)) return true;
    if (examCategory != null && examCategory!.label.toLowerCase().contains(clean)) return true;
    return searchKeywords.any((k) => k.toLowerCase().contains(clean));
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'examCategory': examCategory?.name,
      'searchKeywords': searchKeywords,
      'targetSizeKB': targetSizeKB,
      'minSizeKB': minSizeKB,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'outputFormat': outputFormat,
      'badgeText': badgeText,
      'iconEmoji': iconEmoji,
      'targetDpi': targetDpi,
    };
  }

  factory ImagePreset.fromJson(Map<String, dynamic> json) {
    return ImagePreset(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      category: PresetCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => PresetCategory.exam,
      ),
      examCategory: ExamCategory.fromString(json['examCategory'] as String?),
      searchKeywords: (json['searchKeywords'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      targetSizeKB: json['targetSizeKB'] as int?,
      minSizeKB: json['minSizeKB'] as int?,
      targetWidth: json['targetWidth'] as int?,
      targetHeight: json['targetHeight'] as int?,
      outputFormat: (json['outputFormat'] as String?) ?? 'jpg',
      badgeText: (json['badgeText'] as String?) ?? '',
      iconEmoji: (json['iconEmoji'] as String?) ?? '📄',
      targetDpi: json['targetDpi'] as int?,
    );
  }
}
