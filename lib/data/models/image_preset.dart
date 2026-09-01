enum PresetCategory {
  exam,
  identity,
  social,
  custom,
}

class ImagePreset {
  final String id;
  final String name;
  final String description;
  final PresetCategory category;
  final int? targetSizeKB;
  final int? minSizeKB;
  final int? targetWidth;
  final int? targetHeight;
  final String outputFormat;
  final String badgeText;
  final String iconEmoji;

  const ImagePreset({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.targetSizeKB,
    this.minSizeKB,
    this.targetWidth,
    this.targetHeight,
    this.outputFormat = 'jpg',
    required this.badgeText,
    this.iconEmoji = '📄',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.name,
      'targetSizeKB': targetSizeKB,
      'minSizeKB': minSizeKB,
      'targetWidth': targetWidth,
      'targetHeight': targetHeight,
      'outputFormat': outputFormat,
      'badgeText': badgeText,
      'iconEmoji': iconEmoji,
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
      targetSizeKB: json['targetSizeKB'] as int?,
      minSizeKB: json['minSizeKB'] as int?,
      targetWidth: json['targetWidth'] as int?,
      targetHeight: json['targetHeight'] as int?,
      outputFormat: (json['outputFormat'] as String?) ?? 'jpg',
      badgeText: (json['badgeText'] as String?) ?? '',
      iconEmoji: (json['iconEmoji'] as String?) ?? '📄',
    );
  }
}
