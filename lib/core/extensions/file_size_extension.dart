extension FileSizeExtension on int {
  /// Converts integer bytes into human-readable formatted string (e.g. "48 KB", "2.4 MB")
  String toReadableFileSize({int decimals = 1}) {
    if (this <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    if (i == 0) {
      return '${size.toInt()} ${suffixes[i]}';
    }

    final formatted = size.toStringAsFixed(decimals);
    // Remove trailing zero if applicable (e.g., "5.0" -> "5")
    final clean = formatted.endsWith('.0')
        ? formatted.substring(0, formatted.length - 2)
        : formatted;
    return '$clean ${suffixes[i]}';
  }
}
