import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/data/models/process_options.dart';
import 'package:image_resizer/presentation/widgets/processing_progress_modal.dart';
import 'package:image_resizer/services/image_service/image_processor.dart';

void main() {
  group('Low-End Device Performance & Isolate Dimension Tests', () {
    late Directory tempDir;
    late File testJpegFile;
    late File testPngFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('perf_test_');
      testJpegFile = File('${tempDir.path}/sample.jpg');
      testPngFile = File('${tempDir.path}/sample.png');

      // Create a 240x160 sample image
      final sampleImg = img.Image(width: 240, height: 160);
      img.fill(sampleImg, color: img.ColorRgb8(25, 120, 200));

      await testJpegFile.writeAsBytes(img.encodeJpg(sampleImg));
      await testPngFile.writeAsBytes(img.encodePng(sampleImg));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'readImageDimensions returns correct dimensions without freezing main thread',
      () async {
        final jpegDims = await ImageProcessor.readImageDimensions(
          testJpegFile.path,
        );
        expect(jpegDims, isNotNull);
        expect(jpegDims!.width, 240);
        expect(jpegDims.height, 160);

        final pngDims = await ImageProcessor.readImageDimensions(
          testPngFile.path,
        );
        expect(pngDims, isNotNull);
        expect(pngDims!.width, 240);
        expect(pngDims.height, 160);

        // Non-existent file test
        final nullDims = await ImageProcessor.readImageDimensions(
          '${tempDir.path}/does_not_exist.jpg',
        );
        expect(nullDims, isNull);
      },
    );

    test(
      'processImage streams onProgress callbacks with stage descriptions',
      () async {
        final progressValues = <double>[];
        final stageMessages = <String>[];

        final options = ProcessOptions(
          sourcePath: testJpegFile.path,
          targetSizeKB: 20,
          quality: 80,
        );

        final result = await ImageProcessor.processImage(
          options,
          onProgress: (progress, stage) {
            progressValues.add(progress);
            stageMessages.add(stage);
          },
        );

        expect(result, isNotNull);
        expect(File(result.outputPath).existsSync(), true);

        // Verify progress was reported progressively
        expect(progressValues.isNotEmpty, true);
        expect(progressValues.last, 1.0);
        expect(
          stageMessages.any((msg) => msg.toLowerCase().contains('reading')),
          true,
        );
        expect(
          stageMessages.any((msg) => msg.toLowerCase().contains('decoding')),
          true,
        );
      },
    );

    test(
      'processImage with preventSizeIncrease ensures output does not exceed original size for direct encoding',
      () async {
        final origSize = testJpegFile.lengthSync();
        final options = ProcessOptions(
          sourcePath: testJpegFile.path,
          quality: 95,
          preventSizeIncrease: true,
        );

        final result = await ImageProcessor.processImage(options);
        expect(result, isNotNull);
        expect(result.outputSizeBytes, lessThanOrEqualTo(origSize));
      },
    );

    test('ImageDimensions equality and toString work properly', () {
      const d1 = ImageDimensions(width: 1920, height: 1080);
      const d2 = ImageDimensions(width: 1920, height: 1080);
      const d3 = ImageDimensions(width: 1080, height: 1920);

      expect(d1, equals(d2));
      expect(d1 == d3, false);
      expect(d1.toString(), '1920x1080');
      expect(d1.hashCode, equals(d2.hashCode));
    });
  });

  group('ProcessingProgressModal Widget Tests', () {
    testWidgets(
      'Renders progress percentage, stage description, and reassurance badge',
      (tester) async {
        final progressNotifier = ValueNotifier<ProcessingProgressState>(
          const ProcessingProgressState(
            progress: 0.65,
            stage: 'Optimizing resolution & compression...',
          ),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProcessingProgressModal(
                progressNotifier: progressNotifier,
                title: 'Processing High-Res Image',
              ),
            ),
          ),
        );

        await tester.pump();

        // Check title and percent
        expect(find.text('Processing High-Res Image'), findsOneWidget);
        expect(find.text('65'), findsOneWidget);
        expect(find.text('%'), findsOneWidget);

        // Check stage message and reassurance badge
        expect(
          find.text('Optimizing resolution & compression...'),
          findsOneWidget,
        );
        expect(
          find.text('Background Isolate • UI stays responsive'),
          findsOneWidget,
        );
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        // Update state to 100% complete
        progressNotifier.value = const ProcessingProgressState(
          progress: 1.0,
          stage: 'Complete',
          isCompleted: true,
        );
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('100'), findsOneWidget);
        expect(find.text('Complete'), findsOneWidget);
        expect(find.byIcon(Icons.check_rounded), findsOneWidget);

        await tester.pumpAndSettle();
      },
    );
  });
}
