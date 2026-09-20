import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/services/in_app_review_service.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeInAppReview extends Fake implements InAppReview {
  bool isAvailableVal = true;
  int requestReviewCallCount = 0;
  int openStoreListingCallCount = 0;

  @override
  Future<bool> isAvailable() async => isAvailableVal;

  @override
  Future<void> requestReview() async {
    requestReviewCallCount++;
  }

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {
    openStoreListingCallCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeInAppReview fakeReview;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    fakeReview = FakeInAppReview();
  });

  group('InAppReviewService Tests', () {
    test(
      'does not prompt before reaching minimum 3 successful actions',
      () async {
        // 1st action
        final prompted1 =
            await InAppReviewService.recordSuccessfulActionAndPromptIfNeeded(
              reviewInstance: fakeReview,
              prefsInstance: prefs,
            );
        expect(prompted1, false);
        expect(fakeReview.requestReviewCallCount, 0);
        expect(prefs.getInt(InAppReviewService.keySuccessCount), 1);

        // 2nd action
        final prompted2 =
            await InAppReviewService.recordSuccessfulActionAndPromptIfNeeded(
              reviewInstance: fakeReview,
              prefsInstance: prefs,
            );
        expect(prompted2, false);
        expect(fakeReview.requestReviewCallCount, 0);
        expect(prefs.getInt(InAppReviewService.keySuccessCount), 2);
      },
    );

    test('prompts on 3rd action when threshold is reached', () async {
      await prefs.setInt(InAppReviewService.keySuccessCount, 2);

      final prompted =
          await InAppReviewService.recordSuccessfulActionAndPromptIfNeeded(
            reviewInstance: fakeReview,
            prefsInstance: prefs,
          );

      expect(prompted, true);
      expect(fakeReview.requestReviewCallCount, 1);
      expect(prefs.getInt(InAppReviewService.keySuccessCount), 3);
      expect(prefs.getInt(InAppReviewService.keyLastPromptTime), isNotNull);
    });

    test('throttles subsequent prompts within 30 days', () async {
      // Set last prompt to 5 days ago
      final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));
      await prefs.setInt(
        InAppReviewService.keyLastPromptTime,
        fiveDaysAgo.millisecondsSinceEpoch,
      );
      await prefs.setInt(InAppReviewService.keySuccessCount, 5);

      final prompted =
          await InAppReviewService.recordSuccessfulActionAndPromptIfNeeded(
            reviewInstance: fakeReview,
            prefsInstance: prefs,
          );

      expect(prompted, false);
      expect(fakeReview.requestReviewCallCount, 0);
      expect(prefs.getInt(InAppReviewService.keySuccessCount), 6);
    });

    test('prompts again after 30 days interval', () async {
      // Set last prompt to 31 days ago
      final thirtyOneDaysAgo = DateTime.now().subtract(
        const Duration(days: 31),
      );
      await prefs.setInt(
        InAppReviewService.keyLastPromptTime,
        thirtyOneDaysAgo.millisecondsSinceEpoch,
      );
      await prefs.setInt(InAppReviewService.keySuccessCount, 10);

      final prompted =
          await InAppReviewService.recordSuccessfulActionAndPromptIfNeeded(
            reviewInstance: fakeReview,
            prefsInstance: prefs,
          );

      expect(prompted, true);
      expect(fakeReview.requestReviewCallCount, 1);
      expect(prefs.getInt(InAppReviewService.keySuccessCount), 11);
    });

    test(
      'openStoreListing calls underlying inAppReview openStoreListing',
      () async {
        await InAppReviewService.openStoreListing(reviewInstance: fakeReview);
        expect(fakeReview.openStoreListingCallCount, 1);
      },
    );
  });
}
