import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/presets/presets_hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildPresetsHubScreen({int initialTabIndex = 1}) {
    return ProviderScope(
      child: MaterialApp(
        home: PresetsHubScreen(initialTabIndex: initialTabIndex),
      ),
    );
  }

  testWidgets('PresetsHubScreen renders search bar and category filter chips',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Verify search bar exists
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search UPSC, SSC, GATE, NEET, 50 KB...'), findsOneWidget);

    // Verify filter chips exist
    expect(find.text('All'), findsOneWidget);
    expect(find.text('Central Govt'), findsOneWidget);
    expect(find.text('State PSC'), findsOneWidget);
    expect(find.text('Banking'), findsOneWidget);
    expect(find.text('Defence'), findsOneWidget);
    expect(find.text('Academic'), findsOneWidget);
    expect(find.text('ID & Docs'), findsOneWidget);

    // Initial state shows presets
    expect(find.text('SSC Signature'), findsOneWidget);
  });

  testWidgets('Typing in search bar filters presets dynamically',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Type 'GATE' in search bar
    await tester.enterText(find.byType(TextField), 'GATE');
    await tester.pumpAndSettle();

    // GATE presets should be visible, SSC should not
    expect(find.text('GATE 2025/2026 Photo'), findsOneWidget);
    expect(find.text('GATE Signature'), findsOneWidget);
    expect(find.text('SSC Signature'), findsNothing);

    // Clear search using close icon button
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // SSC should be visible again
    expect(find.text('SSC Signature'), findsOneWidget);
  });

  testWidgets('Tapping category filter chip filters presets by category',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Tap 'Banking' chip
    await tester.tap(find.text('Banking'));
    await tester.pumpAndSettle();

    // Banking presets should appear, SSC or Defence should not
    expect(find.text('IBPS / Bank PO Photo'), findsOneWidget);
    expect(find.text('SBI PO / Clerk Photo'), findsOneWidget);
    expect(find.text('SSC Signature'), findsNothing);

    // Tap 'Defence' chip
    await tester.tap(find.text('Defence'));
    await tester.pumpAndSettle();

    expect(find.text('NDA / CDS Defence Photo'), findsOneWidget);
    expect(find.text('AFCAT Air Force Photo'), findsOneWidget);
    expect(find.text('IBPS / Bank PO Photo'), findsNothing);
  });

  testWidgets('Toggling star pins preset and shows Pinned Presets bar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Initially no pinned bar
    expect(find.text('Pinned Presets'), findsNothing);

    // Find star button for the first card (SSC Signature)
    final starButtonFinder = find.byIcon(Icons.star_outline_rounded).first;
    await tester.tap(starButtonFinder);
    await tester.pumpAndSettle();

    // SnackBar appears
    expect(find.textContaining('Pinned "SSC Signature" to Home Screen ⭐'), findsOneWidget);

    // Pinned presets section appears
    expect(find.text('Pinned Presets'), findsOneWidget);

    // Star icon is now filled
    expect(find.byIcon(Icons.star_rounded), findsWidgets);
  });

  testWidgets('Empty search result shows clear button and restores list when tapped',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Search query with no match
    await tester.enterText(find.byType(TextField), 'zzzz9999nonexistent');
    await tester.pumpAndSettle();

    expect(find.text('No presets found'), findsOneWidget);
    expect(find.text('Clear Search & Filters'), findsOneWidget);

    // Tap 'Clear Search & Filters'
    await tester.tap(find.text('Clear Search & Filters'));
    await tester.pumpAndSettle();

    // List is restored
    expect(find.text('SSC Signature'), findsOneWidget);
  });

  testWidgets('Tablet horizontal screen renders 2-column GridView and centered tab pill',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPresetsHubScreen(initialTabIndex: 1));
    await tester.pumpAndSettle();

    // Verify GridView is used instead of single-column ListView on horizontal tablet
    expect(find.byType(GridView), findsOneWidget);

    // Verify presets are displayed
    expect(find.text('SSC Signature'), findsOneWidget);
    expect(find.text('UPSC Civil Services Photo'), findsOneWidget);

    // Switch to Exam Tools tab
    await tester.tap(find.text('Exam Tools'));
    await tester.pumpAndSettle();

    // Verify Exam Document Tools header and cards exist
    expect(find.text('Signature B&W Cleaner'), findsOneWidget);
    expect(find.text('Name & Date Photo Stamp'), findsOneWidget);
    expect(find.text('Perspective Crop & Deskew'), findsOneWidget);
  });
}
