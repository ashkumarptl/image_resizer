import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/result/widgets/next_actions_section.dart';
import 'package:image_resizer/presentation/scan_to_pdf/scan_to_pdf_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NextActionsSection renders all smart action suggestions', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NextActionsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify section header
    expect(find.text('NEXT ACTIONS FOR YOUR FORM'), findsOneWidget);

    // Verify suggestion cards
    expect(find.text('Need Signature for same form?'), findsOneWidget);
    expect(find.text('Scan another document to PDF'), findsOneWidget);
    expect(find.text('Name & Date Photo Stamp'), findsOneWidget);
    expect(find.text('Straighten / Deskew Document'), findsOneWidget);
  });

  testWidgets('Tapping Scan another document opens ScanToPdfScreen', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NextActionsSection()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap on Scan another document to PDF
    await tester.tap(find.text('Scan another document to PDF'));
    await tester.pumpAndSettle();

    // Verify ScanToPdfScreen is mounted
    expect(find.byType(ScanToPdfScreen), findsOneWidget);
    expect(find.text('Scan to PDF'), findsWidgets);
  });
}
