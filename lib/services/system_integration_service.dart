import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service managing native Android system integrations:
/// 1. Receiving images shared into the app (Share Target / Open with)
/// 2. Handling Android Home Screen Launcher Shortcuts
/// 3. Opening saved images directly in Google Photos / Device Gallery
class SystemIntegrationService {
  SystemIntegrationService._();
  static final SystemIntegrationService instance = SystemIntegrationService._();

  static const MethodChannel _channel =
      MethodChannel('com.ashspark.image_resizer/system_integration');

  final StreamController<String> _sharedFileController =
      StreamController<String>.broadcast();
  final StreamController<String> _shortcutController =
      StreamController<String>.broadcast();

  Stream<String> get onSharedFile => _sharedFileController.stream;
  Stream<String> get onShortcut => _shortcutController.stream;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onSharedFileReceived':
          final path = call.arguments as String?;
          if (path != null && path.isNotEmpty) {
            _sharedFileController.add(path);
          }
          break;
        case 'onShortcutReceived':
          final shortcut = call.arguments as String?;
          if (shortcut != null && shortcut.isNotEmpty) {
            _shortcutController.add(shortcut);
          }
          break;
        default:
          break;
      }
    });
  }

  /// Checks if the app was launched by sharing an image into it.
  Future<String?> getInitialSharedFile() async {
    try {
      final path = await _channel.invokeMethod<String>('getInitialSharedFile');
      return (path != null && path.isNotEmpty) ? path : null;
    } catch (e) {
      debugPrint('Error getting initial shared file: $e');
      return null;
    }
  }

  /// Checks if the app was launched via an Android App Shortcut.
  Future<String?> getInitialShortcut() async {
    try {
      final shortcut = await _channel.invokeMethod<String>('getInitialShortcut');
      return (shortcut != null && shortcut.isNotEmpty) ? shortcut : null;
    } catch (e) {
      debugPrint('Error getting initial shortcut: $e');
      return null;
    }
  }

  /// Opens the given image file in Google Photos / Gallery via Android ACTION_VIEW intent.
  Future<bool> openInGallery(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'openInGallery',
        {'path': filePath},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error opening in gallery: $e');
      return false;
    }
  }

  /// Direct prints the image via native system print manager / dialog.
  Future<bool> printImage(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'printImage',
        {'path': filePath},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing image via system service: $e');
      return false;
    }
  }

  /// Direct prints the PDF document via native system print manager / spooler.
  Future<bool> printPdf(String filePath) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'printPdf',
        {'path': filePath},
      );
      return result ?? false;
    } catch (e) {
      debugPrint('Error printing PDF via system service: $e');
      return false;
    }
  }

  /// Converts a HEIC / HEIF image file to standard JPEG using native platform decoder.
  Future<String?> convertHeicToJpeg(String sourcePath, {String? targetPath}) async {
    try {
      final destPath = targetPath ??
          '${sourcePath.replaceAll(RegExp(r'\.(heic|heif)$', caseSensitive: false), '')}_converted_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final result = await _channel.invokeMethod<String>(
        'convertHeicToJpeg',
        {
          'path': sourcePath,
          'targetPath': destPath,
          'quality': 95,
        },
      );
      return result;
    } catch (e) {
      debugPrint('[SystemIntegrationService] Error converting HEIC via platform: $e');
      return null;
    }
  }

  @visibleForTesting
  void dispose() {
    _sharedFileController.close();
    _shortcutController.close();
  }
}
