class HistoryItem {
  final String id;
  final String filePath;
  final String originalPath;
  final int originalSizeBytes;
  final int outputSizeBytes;
  final int width;
  final int height;
  final String format;
  final DateTime processedAt;

  const HistoryItem({
    required this.id,
    required this.filePath,
    required this.originalPath,
    required this.originalSizeBytes,
    required this.outputSizeBytes,
    required this.width,
    required this.height,
    required this.format,
    required this.processedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'originalPath': originalPath,
      'originalSizeBytes': originalSizeBytes,
      'outputSizeBytes': outputSizeBytes,
      'width': width,
      'height': height,
      'format': format,
      'processedAt': processedAt.toIso8601String(),
    };
  }

  factory HistoryItem.fromJson(Map<String, dynamic> json) {
    return HistoryItem(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      originalPath: (json['originalPath'] as String?) ?? '',
      originalSizeBytes: json['originalSizeBytes'] as int,
      outputSizeBytes: json['outputSizeBytes'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      format: json['format'] as String,
      processedAt: DateTime.parse(json['processedAt'] as String),
    );
  }
}
