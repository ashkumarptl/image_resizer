import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Privacy-first Analytics Service for Image Resizer
/// IMPORTANT: No image names, raw file paths, image pixels, or sensitive user data are tracked.
/// Only technical metadata (format, dimensions, execution time, size in KB) is recorded.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log App Open
  static Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
      debugPrint('[Analytics] Event: app_open');
    } catch (e) {
      debugPrint('[Analytics] Error logging app_open: $e');
    }
  }

  /// Funnel Step 1: User picks/selects an image
  static Future<void> logImageSelected({
    required String fileType,
    required int width,
    required int height,
    required int sizeKb,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'image_selected',
        parameters: {
          'file_type': fileType.toLowerCase(),
          'input_width': width,
          'input_height': height,
          'input_size_kb': sizeKb,
        },
      );
      debugPrint('[Analytics] Event: image_selected (${width}x$height, ${sizeKb}KB)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Funnel Step 2: User triggers image resizing
  static Future<void> logResizeStarted({
    required String outputFormat,
    required int targetWidth,
    required int targetHeight,
    required String resizeMode,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'resize_started',
        parameters: {
          'output_format': outputFormat.toLowerCase(),
          'target_width': targetWidth,
          'target_height': targetHeight,
          'resize_mode': resizeMode,
        },
      );
      debugPrint('[Analytics] Event: resize_started ($outputFormat -> ${targetWidth}x$targetHeight)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Funnel Step 3: Resizing completed successfully
  static Future<void> logResizeCompleted({
    required String outputFormat,
    required int outputWidth,
    required int outputHeight,
    required int outputSizeKb,
    required int durationMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'resize_completed',
        parameters: {
          'output_format': outputFormat.toLowerCase(),
          'output_width': outputWidth,
          'output_height': outputHeight,
          'output_size_kb': outputSizeKb,
          'duration_ms': durationMs,
        },
      );
      debugPrint('[Analytics] Event: resize_completed in ${durationMs}ms');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Technical Drop-off: Processing/resizing failed
  static Future<void> logResizeFailed({
    required String reason,
    required String fileType,
    required int inputWidth,
    required int inputHeight,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'resize_failed',
        parameters: {
          'failure_reason': reason.length > 90 ? reason.substring(0, 90) : reason,
          'file_type': fileType.toLowerCase(),
          'input_width': inputWidth,
          'input_height': inputHeight,
        },
      );
      debugPrint('[Analytics] Event: resize_failed ($reason)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Funnel Step 4: Output image saved to device/gallery
  static Future<void> logImageSaved({
    required String outputFormat,
    required int sizeKb,
    required String destination,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'image_saved',
        parameters: {
          'output_format': outputFormat.toLowerCase(),
          'size_kb': sizeKb,
          'destination': destination,
        },
      );
      debugPrint('[Analytics] Event: image_saved ($outputFormat, ${sizeKb}KB to $destination)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Image Shared to external app
  static Future<void> logImageShared({
    required String outputFormat,
    required int sizeKb,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'image_shared',
        parameters: {
          'output_format': outputFormat.toLowerCase(),
          'size_kb': sizeKb,
        },
      );
      debugPrint('[Analytics] Event: image_shared ($outputFormat)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Output format selected
  static Future<void> logFormatSelected({required String format}) async {
    try {
      await _analytics.logEvent(
        name: 'format_selected',
        parameters: {'format': format.toLowerCase()},
      );
      debugPrint('[Analytics] Event: format_selected ($format)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Image compression operation
  static Future<void> logCompressionUsed({
    required int targetQuality,
    required int originalSizeKb,
    required int compressedSizeKb,
  }) async {
    final savingsPercent = originalSizeKb > 0
        ? (((originalSizeKb - compressedSizeKb) / originalSizeKb) * 100).round()
        : 0;

    try {
      await _analytics.logEvent(
        name: 'compression_used',
        parameters: {
          'target_quality': targetQuality,
          'original_size_kb': originalSizeKb,
          'compressed_size_kb': compressedSizeKb,
          'savings_percent': savingsPercent,
        },
      );
      debugPrint('[Analytics] Event: compression_used (Quality $targetQuality, Saved $savingsPercent%)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  /// Batch operations tracking
  static Future<void> logBatchResizeStarted({required int count}) async {
    try {
      await _analytics.logEvent(
        name: 'batch_resize_started',
        parameters: {'batch_count': count},
      );
      debugPrint('[Analytics] Event: batch_resize_started ($count items)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }

  static Future<void> logBatchResizeCompleted({
    required int totalImages,
    required int successCount,
    required int failedCount,
    required int durationMs,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'batch_resize_completed',
        parameters: {
          'total_images': totalImages,
          'success_count': successCount,
          'failed_count': failedCount,
          'duration_ms': durationMs,
        },
      );
      debugPrint('[Analytics] Event: batch_resize_completed (Success: $successCount, Failed: $failedCount in ${durationMs}ms)');
    } catch (e) {
      debugPrint('[Analytics] Error: $e');
    }
  }
}
