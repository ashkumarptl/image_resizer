import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/perspective_crop/perspective_crop_screen.dart';
import 'package:image_resizer/presentation/perspective_crop/widgets/perspective_crop_canvas.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyImageFile;

  setUpAll(() async {
    final image = img.Image(width: 300, height: 200);
    img.fill(image, color: img.ColorRgb8(200, 200, 200));
    final bytes = img.encodeJpg(image);

    dummyImageFile = File(
      '${Directory.systemTemp.path}/test_perspective_screen_img.jpg',
    );
    await dummyImageFile.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (dummyImageFile.existsSync()) {
      await dummyImageFile.delete();
    }
  });

  Widget buildTestWidget({bool returnCroppedFile = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: PerspectiveCropScreen(
          initialImage: dummyImageFile,
          returnCroppedFile: returnCroppedFile,
        ),
      ),
    );
  }

  group('PerspectiveCropScreen Widget Tests', () {
    testWidgets('Renders AppBar, Canvas, Presets, Filters, and Apply Button', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify AppBar elements
      expect(find.text('Perspective Crop & Deskew'), findsOneWidget);
      expect(
        find.text('Drag 4 corners to align document boundaries'),
        findsOneWidget,
      );
      expect(find.byTooltip('Fit to Bounds'), findsOneWidget);
      expect(find.byTooltip('Rotate 90°'), findsOneWidget);
      expect(find.byTooltip('Reset Corners'), findsOneWidget);

      // Verify Canvas
      expect(find.byType(PerspectiveCropCanvas), findsOneWidget);

      // Verify Preset chips
      expect(find.text('Auto / Natural'), findsOneWidget);
      expect(find.text('A4 Document'), findsOneWidget);
      expect(find.text('ID Card'), findsOneWidget);

      // Verify Primary Action Button
      expect(find.text('Apply Perspective Crop'), findsOneWidget);
    });

    testWidgets('Tapping presets updates active selection and corners', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initial state: full bounds (0.0, 0.0) -> (1.0, 1.0)
      var canvas = tester.widget<PerspectiveCropCanvas>(
        find.byType(PerspectiveCropCanvas),
      );
      expect(canvas.topLeft.x, equals(0.0));
      expect(canvas.topLeft.y, equals(0.0));
      expect(canvas.bottomRight.x, equals(1.0));
      expect(canvas.bottomRight.y, equals(1.0));
      expect(find.text('Ratio: A4 Document'), findsNothing);

      // Tap A4 Document chip: snaps corners and displays ratio indicator badge
      await tester.tap(find.text('A4 Document'));
      await tester.pumpAndSettle();
      expect(find.text('Ratio: A4 Document'), findsOneWidget);

      canvas = tester.widget<PerspectiveCropCanvas>(
        find.byType(PerspectiveCropCanvas),
      );
      expect(canvas.topLeft.x, greaterThanOrEqualTo(0.0));
      expect(canvas.topRight.x, lessThanOrEqualTo(1.0));

      // Tap ID Card chip
      await tester.tap(find.text('ID Card'));
      await tester.pumpAndSettle();
      expect(find.text('Ratio: ID Card'), findsOneWidget);

      // Tap Auto / Natural chip: snaps back to full bounds
      await tester.tap(find.text('Auto / Natural'));
      await tester.pumpAndSettle();
      expect(find.text('Ratio: Auto / Natural'), findsNothing);
      canvas = tester.widget<PerspectiveCropCanvas>(
        find.byType(PerspectiveCropCanvas),
      );
      expect(canvas.topLeft.x, equals(0.0));
      expect(canvas.bottomRight.x, equals(1.0));

      // Tap Rotate 90° button
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();

      // Tap Fit to Bounds
      await tester.tap(find.byTooltip('Fit to Bounds'));
      await tester.pumpAndSettle();

      // Tap Reset Corners
      await tester.tap(find.byTooltip('Reset Corners'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Applying crop in returnCroppedFile mode pops with resulting file',
      (tester) async {
        File? returnedResult;

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () async {
                      returnedResult = await Navigator.of(context).push<File>(
                        MaterialPageRoute(
                          builder: (_) => PerspectiveCropScreen(
                            initialImage: dummyImageFile,
                            returnCroppedFile: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Perspective'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Open screen
        await tester.tap(find.text('Open Perspective'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Apply Perspective Crop'), findsOneWidget);

        // Tap apply button
        await tester.tap(find.text('Apply Perspective Crop'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 500));

        expect(returnedResult, isNotNull);
        expect(returnedResult!.existsSync(), isTrue);

        if (returnedResult != null && returnedResult!.existsSync()) {
          try {
            returnedResult!.deleteSync();
          } catch (_) {}
        }
      },
    );
  });
}
