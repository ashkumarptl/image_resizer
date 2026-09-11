import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/preset_constants.dart';
import 'package:image_resizer/presentation/home/widgets/preset_carousel.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PresetCarousel prioritizes pinned presets to the front with ⭐ PINNED badge',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Pin 'gate_photo', which normally appears after SSC & UPSC
    const pinnedPresetId = 'gate_photo';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresetCarousel(
            presets: PresetConstants.indianGovtPresets,
            favoritePresetIds: const {pinnedPresetId},
            onPresetTap: (_) {},
            onSeeAllTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify pinned indicator in header and card star icon
    expect(find.text('1 PINNED'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);

    // Verify GATE 2025/2026 Photo is displayed as the first item in the carousel
    expect(find.text('GATE 2025/2026 Photo'), findsOneWidget);
  });

  testWidgets('PresetCarousel shows standard cards when no presets are pinned',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PresetCarousel(
            presets: PresetConstants.indianGovtPresets,
            favoritePresetIds: const {},
            onPresetTap: (_) {},
            onSeeAllTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No pinned badges
    expect(find.textContaining('PINNED'), findsNothing);
    expect(find.text('SSC Signature'), findsOneWidget);
  });
}
