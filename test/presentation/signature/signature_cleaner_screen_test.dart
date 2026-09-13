import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/signature/signature_cleaner_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyImage;

  setUp(() {
    dummyImage = File('${Directory.systemTemp.path}/test_sig_cleaner_img.jpg');
    dummyImage.writeAsBytesSync(List.filled(100, 0));
  });

  tearDown(() {
    if (dummyImage.existsSync()) {
      dummyImage.deleteSync();
    }
  });

  testWidgets(
    'SignatureCleanerScreen renders threshold slider and handles maximum drag without assertion error',
    (WidgetTester tester) async {
      // Set a realistic phone size
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: SignatureCleanerScreen(initialImage: dummyImage)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Slider is present
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Initial value is 0.65 (Balanced)
      final Slider initialSlider = tester.widget(sliderFinder);
      expect(initialSlider.value, 0.65);

      // Drag slider far to the right to reach the maximum (0.90)
      await tester.drag(sliderFinder, const Offset(300, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify it settled at max (0.90) without throwing any AssertionError
      final Slider maxSlider = tester.widget(sliderFinder);
      expect(maxSlider.value, lessThanOrEqualTo(0.90));
      expect(maxSlider.value, greaterThanOrEqualTo(0.30));

      // Drag slider far to the left to reach the minimum (0.30)
      await tester.drag(sliderFinder, const Offset(-600, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify it settled at min without error
      final Slider minSlider = tester.widget(sliderFinder);
      expect(minSlider.value, greaterThanOrEqualTo(0.30));
      expect(minSlider.value, lessThanOrEqualTo(0.90));

      // Tap Deep (80%) chip
      await tester.tap(find.text('Deep (80%)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final Slider deepSlider = tester.widget(sliderFinder);
      expect((deepSlider.value - 0.80).abs(), lessThan(0.01));

      // Verify Crop and Rotate action buttons are not present
      expect(find.byIcon(Icons.rotate_right_rounded), findsNothing);
      expect(find.byIcon(Icons.crop_rounded), findsNothing);
      expect(find.byTooltip('Rotate 90°'), findsNothing);
      expect(find.byTooltip('Crop Tightly'), findsNothing);
    },
  );
}
