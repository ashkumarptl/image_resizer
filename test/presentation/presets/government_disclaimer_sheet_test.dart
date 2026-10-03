import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/presets/presets_hub_screen.dart';
import 'package:image_resizer/presentation/presets/widgets/government_disclaimer_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GovernmentDisclaimerSheet Widget Tests', () {
    testWidgets('renders non-government disclaimer and official portal links', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: GovernmentDisclaimerSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Disclaimer & Official Sources'), findsOneWidget);

      // Check non-affiliation disclaimer text
      expect(find.text('Non-Government Affiliation Disclaimer'), findsOneWidget);
      expect(
        find.textContaining(
          'Image Tools is an independent utility application developed by Ash Spark',
        ),
        findsOneWidget,
      );

      // Check sources section and official portal items
      expect(
        find.text('Official Government & Examination Portals'),
        findsOneWidget,
      );
      expect(
        find.text('Staff Selection Commission (SSC)'),
        findsOneWidget,
      );
      expect(
        find.text('Union Public Service Commission (UPSC)'),
        findsOneWidget,
      );
      expect(
        find.text('https://ssc.gov.in'),
        findsOneWidget,
      );
      expect(
        find.text('https://upsc.gov.in'),
        findsOneWidget,
      );

      // Dismiss button exists
      expect(find.text('I Understand'), findsOneWidget);
    });

    testWidgets('PresetsHubScreen banner opens GovernmentDisclaimerSheet on tap', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PresetsHubScreen(initialTabIndex: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the disclaimer banner
      final bannerFinder = find.textContaining('Non-Govt Utility:');
      expect(bannerFinder, findsOneWidget);

      // Tap the banner to open the bottom sheet
      await tester.tap(bannerFinder);
      await tester.pumpAndSettle();

      // Bottom sheet is now visible
      expect(find.byType(GovernmentDisclaimerSheet), findsOneWidget);
      expect(find.text('Non-Government Affiliation Disclaimer'), findsOneWidget);

      // Tap 'I Understand' button
      await tester.tap(find.text('I Understand'));
      await tester.pumpAndSettle();

      // Bottom sheet is closed
      expect(find.byType(GovernmentDisclaimerSheet), findsNothing);
    });
  });
}
