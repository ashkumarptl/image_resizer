import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service managing Google Play & App Store In-App Reviews.
///
/// Complies with Google Play In-App Review API policies:
/// 1. No review-gating: Does not show intermediate "rate us 5 stars" dialogs.
/// 2. Non-intrusive timing: Only prompted after meaningful user value (>= 3 successful exports).
/// 3. Quota-respecting: Enforces a minimum 30-day throttle between prompt attempts.
/// 4. Direct manual action: Provides explicit store listing redirect for Settings screen.
class InAppReviewService {
  InAppReviewService._();

  static const String keySuccessCount = 'in_app_review_success_count';
  static const String keyLastPromptTime = 'in_app_review_last_prompt_time';

  /// Minimum successful operations before considering a prompt
  static const int minSuccessfulActions = 3;

  /// Minimum interval (in days) between automated in-app review requests
  static const int minDaysBetweenPrompts = 30;

  /// Default Google Play package name for fallback URL launcher
  static const String playStorePackageName = 'com.ashkumar.imageresizer';

  /// Records a successful user action (e.g. image saved to gallery, batch exported).
  ///
  /// Evaluates whether the user has experienced sufficient value to receive
  /// a natural in-app review request, respecting Google Play quota guidelines.
  static Future<bool> recordSuccessfulActionAndPromptIfNeeded({
    InAppReview? reviewInstance,
    SharedPreferences? prefsInstance,
  }) async {
    try {
      final prefs = prefsInstance ?? await SharedPreferences.getInstance();
      final currentCount = (prefs.getInt(keySuccessCount) ?? 0) + 1;
      await prefs.setInt(keySuccessCount, currentCount);

      final lastPromptMillis = prefs.getInt(keyLastPromptTime) ?? 0;
      final now = DateTime.now();
      final lastPromptDate = DateTime.fromMillisecondsSinceEpoch(
        lastPromptMillis,
      );
      final daysSinceLastPrompt = now.difference(lastPromptDate).inDays;

      // Threshold check: at least 3 completed tasks and >= 30 days since last prompt
      final isThresholdMet =
          currentCount >= minSuccessfulActions &&
          (lastPromptMillis == 0 ||
              daysSinceLastPrompt >= minDaysBetweenPrompts);

      if (!isThresholdMet) {
        return false;
      }

      final review = reviewInstance ?? InAppReview.instance;
      final isAvailable = await review.isAvailable();

      if (isAvailable) {
        await review.requestReview();
        await prefs.setInt(keyLastPromptTime, now.millisecondsSinceEpoch);
        return true;
      }
    } catch (e) {
      debugPrint('[InAppReviewService] Error requesting in-app review: $e');
    }
    return false;
  }

  /// Directly opens the Google Play Store or Apple App Store listing.
  ///
  /// Designed for manual user-initiated taps (e.g. "Rate on Google Play" in Settings).
  static Future<void> openStoreListing({
    String? appStoreId,
    InAppReview? reviewInstance,
  }) async {
    try {
      final review = reviewInstance ?? InAppReview.instance;
      if (await review.isAvailable()) {
        await review.openStoreListing(appStoreId: appStoreId);
        return;
      }
    } catch (e) {
      debugPrint('[InAppReviewService] review.openStoreListing failed: $e');
    }

    // Fallback: direct Play Store URL launch on Android or web
    try {
      if (!kIsWeb && Platform.isAndroid) {
        final marketUri = Uri.parse('market://details?id=$playStorePackageName');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      final webUri = Uri.parse(
        'https://play.google.com/store/apps/details?id=$playStorePackageName',
      );
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[InAppReviewService] Fallback store URL launch failed: $e');
    }
  }
}
