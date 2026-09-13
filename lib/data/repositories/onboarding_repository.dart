import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key used to persist whether onboarding has been completed
const String kPrefOnboardingCompletedKey = 'pref_onboarding_completed';

/// StateNotifier to manage reactive onboarding completion state
class OnboardingNotifier extends StateNotifier<bool> {
  final SharedPreferences? _prefsOverride;

  OnboardingNotifier({SharedPreferences? prefs, bool? initialValue})
      : _prefsOverride = prefs,
        super(initialValue ?? false) {
    if (initialValue == null) {
      _loadStatus();
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefsOverride ?? await SharedPreferences.getInstance();
  }

  Future<void> _loadStatus() async {
    try {
      final prefs = await _getPrefs();
      state = prefs.getBool(kPrefOnboardingCompletedKey) ?? false;
    } catch (_) {
      state = false;
    }
  }

  /// Mark onboarding as completed and persist to disk
  Future<void> completeOnboarding() async {
    state = true;
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(kPrefOnboardingCompletedKey, true);
    } catch (_) {}
  }

  /// Reset onboarding completion (useful for testing or debugging)
  Future<void> resetOnboarding() async {
    state = false;
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(kPrefOnboardingCompletedKey, false);
    } catch (_) {}
  }
}

/// Global provider for onboarding completion status
final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});
