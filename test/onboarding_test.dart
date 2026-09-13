import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/repositories/onboarding_repository.dart';
import 'package:image_resizer/presentation/onboarding/models/onboarding_models.dart';
import 'package:image_resizer/presentation/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingNotifier Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial state defaults to false when pref is empty', () async {
      final notifier = OnboardingNotifier();
      // Allow async _loadStatus to complete
      await Future.delayed(const Duration(milliseconds: 50));
      expect(notifier.state, isFalse);
    });

    test(
      'completeOnboarding sets state to true and updates SharedPreferences',
      () async {
        final notifier = OnboardingNotifier();
        await notifier.completeOnboarding();
        expect(notifier.state, isTrue);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefOnboardingCompletedKey), isTrue);
      },
    );

    test(
      'resetOnboarding resets state to false and updates SharedPreferences',
      () async {
        final notifier = OnboardingNotifier();
        await notifier.completeOnboarding();
        expect(notifier.state, isTrue);

        await notifier.resetOnboarding();
        expect(notifier.state, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool(kPrefOnboardingCompletedKey), isFalse);
      },
    );

    test('respects initialValue parameter', () {
      final notifier = OnboardingNotifier(initialValue: true);
      expect(notifier.state, isTrue);
    });
  });

  group('Onboarding Models Tests', () {
    test('contains exactly 3 configured pages', () {
      final pages = OnboardingPageData.pages;
      expect(pages.length, equals(3));
      expect(pages[0].pageIndex, equals(0));
      expect(pages[1].pageIndex, equals(1));
      expect(pages[2].pageIndex, equals(2));
    });

    test('Page 1 features represent Edit Studio capabilities', () {
      final page1 = OnboardingPageData.pages[0];
      expect(page1.badge, equals('ALL-IN-ONE EDIT STUDIO'));
      expect(page1.title, equals('Photo & Image Studio'));
      final titles = page1.features.map((f) => f.title).toList();
      expect(titles, contains('Smart Target Size Compressor'));
      expect(titles, contains('Pixel & Print DPI Resizer'));
      expect(titles, contains('Multi-Format Converter'));
      expect(titles, contains('AI Background Remover'));
      expect(titles, contains('AI Super-Resolution Upscale'));
      expect(titles, contains('Doc Clean Filter & Crop'));
    });

    test('Page 2 features represent Scan to PDF capabilities', () {
      final page2 = OnboardingPageData.pages[1];
      expect(page2.badge, equals('DOCUMENT SCANNER'));
      expect(page2.title, equals('Scan to PDF Studio'));
      final titles = page2.features.map((f) => f.title).toList();
      expect(titles, contains('Multi-Page Smart Scanner'));
      expect(titles, contains('Smart PDF Size Optimizer'));
      expect(titles, contains('Drag & Drop Page Reorder'));
      expect(titles, contains('Project Library & Search'));
      expect(titles, contains('Wireless Print & Instant Share'));
      expect(titles, contains('In-Studio Page Refinement'));
    });

    test('Page 3 features represent Exam Tools & Presets capabilities', () {
      final page3 = OnboardingPageData.pages[2];
      expect(page3.badge, equals('GOVT & EXAM READY'));
      expect(page3.title, equals('Exam Tools & Presets'));
      final titles = page3.features.map((f) => f.title).toList();
      expect(titles, contains('50+ Govt & Exam Presets'));
      expect(titles, contains('Signature B&W Cleaner'));
      expect(titles, contains('Name & Date Photo Stamp'));
      expect(titles, contains('Perspective Crop & Deskew'));
      expect(titles, contains('100% Offline & Private'));
    });
  });

  group('OnboardingScreen Widget Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget createWidget({bool isRevisit = false}) {
      return ProviderScope(
        child: MaterialApp(home: OnboardingScreen(isRevisit: isRevisit)),
      );
    }

    testWidgets(
      'renders Page 1 (Edit Studio) initially with Step 1 indicator',
      (WidgetTester tester) async {
        await tester.pumpWidget(createWidget());
        await tester.pumpAndSettle();

        // Check step indicator
        expect(find.text('Step 1 of 3'), findsOneWidget);

        // Check hero header
        expect(find.text('ALL-IN-ONE EDIT STUDIO'), findsOneWidget);
        expect(find.text('Photo & Image Studio'), findsOneWidget);

        // Check feature items
        expect(find.text('Smart Target Size Compressor'), findsOneWidget);
        expect(find.text('Pixel & Print DPI Resizer'), findsOneWidget);
        expect(find.text('Multi-Format Converter'), findsOneWidget);

        // Check navigation buttons
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
      },
    );

    testWidgets('navigates through all 3 pages using Next and Prev buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();

      // Step 1: Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify Page 2 (Scan to PDF)
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('DOCUMENT SCANNER'), findsOneWidget);
      expect(find.text('Scan to PDF Studio'), findsOneWidget);
      expect(find.text('Multi-Page Smart Scanner'), findsOneWidget);
      expect(find.text('Smart PDF Size Optimizer'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      // Step 2: Tap Next to go to Page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify Page 3 (Exam Tools & Presets)
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('GOVT & EXAM READY'), findsOneWidget);
      expect(find.text('Exam Tools & Presets'), findsOneWidget);
      expect(find.text('50+ Govt & Exam Presets'), findsOneWidget);
      expect(find.text('Signature B&W Cleaner'), findsOneWidget);
      expect(find.text('Name & Date Photo Stamp'), findsOneWidget);

      // Verify "Get Started" button is visible instead of "Next"
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Next'), findsNothing);

      // Tap Previous button
      await tester.tap(find.byTooltip('Previous'));
      await tester.pumpAndSettle();

      // Verify back on Page 2
      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Scan to PDF Studio'), findsOneWidget);
    });

    testWidgets('revisit mode shows close button and Got It on last page', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidget(isRevisit: true));
      await tester.pumpAndSettle();

      // Skip is hidden, Close button is present
      expect(find.text('Skip'), findsNothing);
      expect(find.byTooltip('Close Guide'), findsOneWidget);

      // Navigate to Page 3
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Verify last button says "Got It" in revisit mode
      expect(find.text('Got It'), findsOneWidget);
      expect(find.text('Get Started'), findsNothing);
    });
  });
}
