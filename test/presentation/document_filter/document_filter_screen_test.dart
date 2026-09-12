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

    dummyDocFile = File('${Directory.systemTemp.path}/test_doc_filter_screen_img.jpg');
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
    test('PerspectiveCropper.processFilter generates a valid ProcessResult', () async {
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
    });

    testWidgets('Renders AppBar, Filter Options, Hold to Compare, and Apply button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Title & Subtitle
      expect(find.text('Document Scanner Filter'), findsOneWidget);
      expect(find.text('Remove shadows & convert to clean scan'), findsOneWidget);

      // Actions
      expect(find.byTooltip('Tilted? Straighten Corners'), findsOneWidget);
      expect(find.byTooltip('Rotate 90°'), findsOneWidget);

      // Filter options
      expect(find.text('Doc B&W (Clean Scan)'), findsOneWidget);
      expect(find.text('Grayscale'), findsOneWidget);
      expect(find.text('Vibrant / Enhanced'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);

      // Hold to compare button
      expect(find.text('Hold to Compare'), findsOneWidget);

      // Apply button
      expect(find.text('Apply & Save Scan'), findsOneWidget);
    });

    testWidgets('Switching filter options updates selection and checks icon', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Default selected is Doc B&W
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Switch to Grayscale
      await tester.tap(find.text('Grayscale'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Switch to Vibrant / Enhanced
      await tester.tap(find.text('Vibrant / Enhanced'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Switch to Original
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Rotate
      await tester.tap(find.byTooltip('Rotate 90°'));
      await tester.pumpAndSettle();
    });

    testWidgets('Applying filter in returnFilteredFile mode pops with resulting file', (tester) async {
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

      await tester.tap(find.text('Apply & Save Scan'));
      await tester.pumpAndSettle();

      expect(returnedResult, isNotNull);
      expect(returnedResult!.existsSync(), isTrue);
    });
  });
}
