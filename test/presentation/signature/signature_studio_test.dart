import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/signature/signature_cleaner_screen.dart';
import 'package:image_resizer/presentation/signature/widgets/signature_studio_bottom_toolbar.dart';
import 'package:image_resizer/presentation/studio/widgets/studio_info_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyImage;

  setUp(() {
    dummyImage = File('${Directory.systemTemp.path}/test_sig_studio_img.jpg');
    dummyImage.writeAsBytesSync(List.filled(100, 0));
  });

  tearDown(() {
    if (dummyImage.existsSync()) {
      dummyImage.deleteSync();
    }
  });

  testWidgets(
    'Signature Studio renders StudioInfoCard, dominant canvas, and switches tools in toolbar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: SignatureCleanerScreen(initialImage: dummyImage)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Studio Header & Info Card
      expect(find.text('Signature Studio'), findsOneWidget);
      expect(find.byType(StudioInfoCard), findsOneWidget);

      // 2. Verify Bottom Toolbar is present
      expect(find.byType(SignatureStudioBottomToolbar), findsOneWidget);
      expect(find.text('CLEAN'), findsOneWidget);
      expect(find.text('INK COLOR'), findsOneWidget);
      expect(find.text('TARGET KB'), findsOneWidget);
      expect(find.text('DIMENSIONS'), findsOneWidget);

      // 3. Initially CLEAN is active -> Shadow Removal Strength is visible
      expect(find.text('Shadow Removal Strength'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // 4. Switch to INK COLOR tool
      await tester.tap(find.text('INK COLOR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Ink Color Tone'), findsOneWidget);
      expect(find.text('Dark Navy'), findsOneWidget);
      expect(find.text('Pure Black'), findsOneWidget);
      expect(find.text('Royal Blue'), findsOneWidget);

      // Select Pure Black
      await tester.tap(find.text('Pure Black'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 5. Switch to TARGET KB tool (Pure custom input)
      await tester.tap(find.text('TARGET KB'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Custom Target Size Limit'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);

      // Test entering a custom target size like 25
      await tester.enterText(find.byType(TextField), '25');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('< 25 KB'), findsOneWidget);

      // 6. Switch to DIMENSIONS tool
      await tester.tap(find.text('DIMENSIONS'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Standard Dimensions'), findsOneWidget);
      expect(find.text('2:1 Standard'), findsOneWidget);

      // 7. Verify AppBar actions (Save checkmark, Rotate, Crop, Reset)
      expect(find.byTooltip('Save Clean Signature'), findsOneWidget);
      expect(find.byTooltip('Rotate'), findsOneWidget);
      expect(find.byTooltip('Crop Signature Area'), findsOneWidget);
      expect(find.byTooltip('Change Image'), findsOneWidget);

      // 8. Verify Hold to Compare button is present on canvas
      expect(find.text('Hold to Compare'), findsOneWidget);
    },
  );
}
