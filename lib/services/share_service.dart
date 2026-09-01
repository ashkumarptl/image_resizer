import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  ShareService._();

  /// Share processed image file via system share sheet (WhatsApp, Gmail, etc.)
  static Future<void> shareImage(String filePath, {String? text}) async {
    try {
      final file = XFile(filePath);
      await SharePlus.instance.share(
        ShareParams(
          files: [file],
          text: text ?? 'Optimized with Image Tools',
        ),
      );
    } catch (e) {
      debugPrint('Error sharing file: $e');
    }
  }
}
