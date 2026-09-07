import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/presentation/result/widgets/before_after_card.dart';
import 'package:image_resizer/presentation/result/widgets/fullscreen_image_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File originalFile;
  late File outputFile;
  late ProcessResult sampleResult;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('result_preview_test_');
    originalFile = File('${tempDir.path}/original.jpg');
    outputFile = File('${tempDir.path}/output.jpg');

    // Write dummy bytes
    await originalFile.writeAsBytes(List.generate(1024, (i) => i % 256));
    await outputFile.writeAsBytes(List.generate(512, (i) => i % 256));

    sampleResult = ProcessResult(
      originalPath: originalFile.path,
      outputPath: outputFile.path,
      originalSizeBytes: 1024,
      outputSizeBytes: 512,
      originalWidth: 1000,
      originalHeight: 800,
      outputWidth: 500,
      outputHeight: 400,
      outputFormat: 'jpg',
      finalQuality: 80,
      processingTime: const Duration(milliseconds: 120),
    );
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('BeforeAfterCard shows "Tap to preview" badge and opens FullscreenImagePreview on tap', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BeforeAfterCard(result: sampleResult),
        ),
      ),
    );

    // Verify BeforeAfterCard rendered
    expect(find.text('Tap to preview'), findsOneWidget);
    expect(find.text('Tap for Original'), findsOneWidget);
    expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

    // Tap on the image area / "Tap to preview"
    await tester.tap(find.text('Tap to preview'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400)); // finish page transition

    // Verify FullscreenImagePreview is opened
    expect(find.byType(FullscreenImagePreview), findsOneWidget);
    expect(find.text('Optimized Image'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Pinch or double-tap to zoom'), findsOneWidget);
    expect(find.text('Optimized'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);

    // Tap "Original" toggle tab in the fullscreen preview
    await tester.tap(find.text('Original'));
    await tester.pump();

    // Verify switched to Original Image
    expect(find.text('Original Image'), findsOneWidget);

    // Tap back button to return to result card
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FullscreenImagePreview), findsNothing);
    expect(find.byType(BeforeAfterCard), findsOneWidget);
  });

  testWidgets('FullscreenImagePreview supports double tap zoom and reset zoom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FullscreenImagePreview(
          result: sampleResult,
          initialShowOriginal: false,
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Reset Zoom'), findsNothing);

    // Double tap the interactive viewer
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byType(InteractiveViewer));
    await tester.pump();

    // Now reset zoom button should be visible
    expect(find.text('Reset Zoom'), findsOneWidget);

    // Tap Reset Zoom
    await tester.tap(find.text('Reset Zoom'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('Reset Zoom'), findsNothing);
  });
}
