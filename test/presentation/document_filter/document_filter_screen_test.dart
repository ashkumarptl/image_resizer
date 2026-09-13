import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/document_filter/document_filter_screen.dart';
import 'package:image_resizer/services/image_service/perspective_cropper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File dummyDocFile;

  setUpAll(() async {
    final image = img.Image(width: 300, height: 200);
    img.fill(image, color: img.ColorRgb8(220, 220, 220));
    final bytes = img.encodeJpg(image);

    dummyDocFile = File(
      '${Directory.systemTemp.path}/test_doc_filter_screen_img.jpg',
    );
    await dummyDocFile.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (dummyDocFile.existsSync()) {
      await dummyDocFile.delete();
    }
  });

  Widget buildTestWidget({bool returnFilteredFile = false}) {
    return ProviderScope(
      child: MaterialApp(
        home: DocumentFilterScreen(
          initialImage: dummyDocFile,
          returnFilteredFile: returnFilteredFile,
        ),
      ),
    );
  }

  group('DocumentFilterScreen Widget & Service Tests', () {
    test(
      'PerspectiveCropper.processFilter generates a valid ProcessResult',
      () async {
        final result = await PerspectiveCropper.processFilter(
          dummyDocFile,
          PerspectiveFilter.documentBw,
          quality: 85,
          quarterTurns: 1,
        );

        expect(result.originalPath, equals(dummyDocFile.path));
        expect(result.outputPath, isNotEmpty);
        expect(File(result.outputPath).existsSync(), isTrue);
        expect(result.outputWidth, equals(200)); // rotated 90 deg from 300x200
        expect(result.outputHeight, equals(300));
        expect(result.finalQuality, equals(85));
      },
    );

    testWidgets(
      'Renders Color Filter bottom bar, Filter Options, and Hold to Compare',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Title in bottom bar
        expect(find.text('Color Filter'), findsOneWidget);

        // Actions
        expect(find.byTooltip('Tilted? Straighten Corners'), findsOneWidget);
        expect(find.byTooltip('Rotate 90°'), findsOneWidget);

        // Filter presets header
        expect(find.text('Filter Presets'), findsOneWidget);

        // Filter options
        expect(find.text('Original'), findsOneWidget);
        expect(find.text('Vivid Light'), findsWidgets);
        expect(find.text('Contrast B&W'), findsOneWidget);
        expect(find.text('Vibrant'), findsOneWidget);

        // Badges
        expect(find.text('Pro'), findsWidgets);

        // Hold to compare button
        expect(find.text('Hold to Compare'), findsOneWidget);

        // Apply button
        expect(find.byTooltip('Apply & Save Scan'), findsOneWidget);
      },
    );

    testWidgets('Switching filter options updates selection', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Default selected is Vivid Light
      expect(find.text('Vivid Light'), findsWidgets);

      // Switch to Original
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      // Switch to Contrast B&W
      await tester.tap(find.text('Contrast B&W'));
      await tester.pumpAndSettle();

      // Switch to Vibrant
      await tester.tap(find.text('Vibrant'));
      await tester.pumpAndSettle();

      // Rotate
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();
    });

    testWidgets('Hold to compare interacts properly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final compareFinder = find.text('Hold to Compare');
      expect(compareFinder, findsOneWidget);

      final gesture = await tester.startGesture(
        tester.getCenter(compareFinder),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Release
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
      'Applying filter in returnFilteredFile mode pops with resulting file',
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
                          builder: (_) => DocumentFilterScreen(
                            initialImage: dummyDocFile,
                            returnFilteredFile: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('Open Filter Screen'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Filter Screen'));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Apply & Save Scan'));
        await tester.pumpAndSettle();

        expect(returnedResult, isNotNull);
        expect(returnedResult!.existsSync(), isTrue);
      },
    );

    testWidgets(
      'Mobile phone layout renders horizontal filter strip and hold to compare',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.text('Color Filter'), findsOneWidget);
        expect(find.text('Filter Presets'), findsOneWidget);
        expect(find.text('Vivid Light'), findsWidgets);
        expect(find.text('Hold to Compare'), findsOneWidget);
        expect(find.byTooltip('Apply & Save Scan'), findsOneWidget);

        // Tap and hold Compare
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Hold to Compare')),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Showing Original (Unfiltered)'), findsOneWidget);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(find.text('Showing Original (Unfiltered)'), findsNothing);
      },
    );
  });
}
