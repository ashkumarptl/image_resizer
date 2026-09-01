import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Firebase Crashlytics Service for robust crash and error tracking
class CrashlyticsService {
  CrashlyticsService._();

  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Initialize Crashlytics handlers for Flutter and Async errors
  static Future<void> initialize() async {
    // 1. Configure collection: In debug mode we can keep it off or on, in release mode it is always enabled
    if (kDebugMode) {
      await _crashlytics.setCrashlyticsCollectionEnabled(false);
      debugPrint('[Crashlytics] Collection disabled in debug mode.');
    } else {
      await _crashlytics.setCrashlyticsCollectionEnabled(true);
      debugPrint('[Crashlytics] Collection enabled in release mode.');
    }

    // 2. Flutter framework errors (UI / Widget build exceptions)
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kDebugMode) {
        FlutterError.presentError(details);
      }
      _crashlytics.recordFlutterFatalError(details);
    };

    // 3. Platform Dispatcher errors (Async / Isolate / Uncaught Zone errors)
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      _crashlytics.recordError(error, stack, fatal: true);
      return true;
    };

    // 4. Set App Version metadata for version vs crash rate tracking
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _crashlytics.setCustomKey('app_version', packageInfo.version);
      await _crashlytics.setCustomKey('build_number', packageInfo.buildNumber);
    } catch (e) {
      debugPrint('[Crashlytics] Could not read PackageInfo: $e');
    }
  }

  /// Attach technical context before heavy image operations to debug OutOfMemory (OOM) crashes
  static Future<void> setProcessingContext({
    required String operation,
    required int inputWidth,
    required int inputHeight,
    required int inputSizeKb,
    String? outputFormat,
  }) async {
    try {
      await _crashlytics.setCustomKey('current_operation', operation);
      await _crashlytics.setCustomKey('last_image_width', inputWidth);
      await _crashlytics.setCustomKey('last_image_height', inputHeight);
      await _crashlytics.setCustomKey('last_image_size_kb', inputSizeKb);
      if (outputFormat != null) {
        await _crashlytics.setCustomKey('output_format', outputFormat);
      }
      await _crashlytics.log('Starting $operation on ${inputWidth}x$inputHeight (${inputSizeKb}KB)');
    } catch (e) {
      debugPrint('[Crashlytics] Failed to set processing context: $e');
    }
  }

  /// Clear or reset the operation context after completion
  static Future<void> clearProcessingContext() async {
    try {
      await _crashlytics.setCustomKey('current_operation', 'idle');
    } catch (_) {}
  }

  /// Record a non-fatal caught exception with optional explanation
  static Future<void> recordNonFatalError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
  }) async {
    try {
      await _crashlytics.recordError(
        exception,
        stack,
        reason: reason,
        fatal: false,
      );
      debugPrint('[Crashlytics] Recorded non-fatal error: $reason | $exception');
    } catch (e) {
      debugPrint('[Crashlytics] Error recording non-fatal: $e');
    }
  }
}
