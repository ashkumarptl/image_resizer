import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_options.dart';
import 'package:image_resizer/presentation/batch/batch_screen.dart';
import 'package:image_resizer/presentation/batch/models/batch_item_model.dart';
import 'package:image_resizer/presentation/batch/widgets/batch_image_card.dart';
import 'package:image_resizer/presentation/batch/widgets/batch_item_settings_sheet.dart';
import 'package:image_resizer/presentation/batch/widgets/batch_pdf_export_sheet.dart';
import 'package:image_resizer/services/image_service/batch_processor.dart';

import 'package:image_resizer/services/image_service/image_processor.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleImage1;
  late File sampleImage2;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('batch_test_');

    // Generate valid small png images for tests
    final img1 = img.Image(width: 80, height: 60);
    img.fill(img1, color: img.ColorRgb8(255, 0, 0));
    final bytes1 = img.encodePng(img1);
    sampleImage1 = File('${tempDir.path}/img_1.png')..writeAsBytesSync(bytes1);

    final img2 = img.Image(width: 100, height: 100);
    img.fill(img2, color: img.ColorRgb8(0, 255, 0));
    final bytes2 = img.encodePng(img2);
    sampleImage2 = File('${tempDir.path}/img_2.png')..writeAsBytesSync(bytes2);
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('BatchItemModel Tests', () {
    test('Initializes correctly fromFile', () {
      final item = BatchItemModel.fromFile(sampleImage1);
      expect(item.path, sampleImage1.path);
      expect(item.fileName, 'img_1.png');
      expect(item.fileSizeBytes, greaterThan(0));
      expect(item.hasCustomOptions, false);
      expect(item.dimensions, isNull);
      expect(item.resolutionString, 'Loading...');
    });

    test('copyWith updates dimensions and customOptions', () {
      final item = BatchItemModel.fromFile(sampleImage1);
      const dims = ImageDimensions(width: 80, height: 60);
      final withDims = item.copyWith(dimensions: dims);
      expect(withDims.dimensions, dims);
      expect(withDims.resolutionString, '80×60');

      const customOpts = ProcessOptions(
        sourcePath: '/dummy',
        targetSizeKB: 50,
        outputFormat: 'webp',
      );
      final customized = withDims.copyWith(customOptions: customOpts);
      expect(customized.hasCustomOptions, true);
      expect(customized.customOptions?.targetSizeKB, 50);
      expect(customized.customOptions?.outputFormat, 'webp');

      final cleared = customized.copyWith(clearCustomOptions: true);
      expect(cleared.hasCustomOptions, false);
      expect(cleared.customOptions, isNull);
    });
  });

  group('BatchProcessor with itemOverrides Tests', () {
    test('Applies itemOverrides correctly per image', () async {
      const baseOptions = ProcessOptions(
        sourcePath: '',
        targetSizeKB: 100,
        outputFormat: 'jpg',
      );

      final overrideForImg2 = ProcessOptions(
        sourcePath: sampleImage2.path,
        targetSizeKB: 25,
        outputFormat: 'webp',
      );

      final result = await BatchProcessor.processBatch(
        sourceFilePaths: [sampleImage1.path, sampleImage2.path],
        baseOptions: baseOptions,
        itemOverrides: {
          sampleImage2.path: overrideForImg2,
        },
        createZip: true,
      );

      expect(result.results.length, 2);
      // Image 1 should be output as jpg (from baseOptions)
      expect(result.results[0].outputFormat, 'jpg');
      // Image 2 should be output as webp (from itemOverrides)
      expect(result.results[1].outputFormat, 'webp');
      expect(result.zipFilePath, isNotNull);
    });
  });

  group('BatchImageCard Widget Tests', () {
    testWidgets('Renders thumbnail, metadata, custom badge, and handles actions', (tester) async {
      var removed = false;
      var previewed = false;
      var cropped = false;
      var customized = false;

      final item = BatchItemModel(
        file: sampleImage1,
        fileSizeBytes: 2048,
        dimensions: const ImageDimensions(width: 80, height: 60),
        customOptions: const ProcessOptions(sourcePath: '', targetSizeKB: 50),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchImageCard(
              item: item,
              onRemove: () => removed = true,
              onTapPreview: () => previewed = true,
              onTapCrop: () => cropped = true,
              onCustomize: () => customized = true,
            ),
          ),
        ),
      );

      expect(find.text('img_1.png'), findsOneWidget);
      expect(find.text('80×60'), findsOneWidget);
      expect(find.text('CUSTOM'), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      expect(removed, true);

      // Tap preview button
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();
      expect(previewed, true);

      // Tap crop button
      await tester.tap(find.byIcon(Icons.crop_rounded));
      await tester.pump();
      expect(cropped, true);

      // Tap customize button
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pump();
      expect(customized, true);
    });
  });

  group('BatchItemSettingsSheet Widget Tests', () {
    testWidgets('Toggles customize switch, modifies KB, and saves custom options', (tester) async {
      ProcessOptions? savedOptions;

      final item = BatchItemModel(
        file: sampleImage1,
        fileSizeBytes: 2048,
        dimensions: const ImageDimensions(width: 80, height: 60),
      );

      const defaultOptions = ProcessOptions(
        sourcePath: '/path/to/img_1.png',
        targetSizeKB: 100,
        outputFormat: 'jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchItemSettingsSheet(
              item: item,
              defaultOptions: defaultOptions,
              onSave: (opts) => savedOptions = opts,
            ),
          ),
        ),
      );

      expect(find.text('Customize for this image'), findsOneWidget);
      expect(find.text('Keep Default'), findsOneWidget);

      // Toggle switch to enable customization
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('Apply Custom'), findsOneWidget);
      expect(find.text('Target Size (KB)'), findsOneWidget);

      // Select 50 KB chip
      await tester.tap(find.text('50 KB'));
      await tester.pumpAndSettle();

      // Tap Apply Custom
      await tester.tap(find.text('Apply Custom'));
      await tester.pumpAndSettle();

      expect(savedOptions, isNotNull);
      expect(savedOptions?.targetSizeKB, 50);
    });
  });

  group('BatchScreen Widget Tests', () {
    testWidgets('Renders empty state with Smart Document Scanner option', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BatchScreen(),
          ),
        ),
      );

      expect(find.text('Batch Processing'), findsOneWidget);
      expect(find.text('Select Multiple Images'), findsOneWidget);
      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('From Gallery'), findsNothing);
      expect(find.text('Take Photo'), findsNothing);
    });

    testWidgets('Renders cards and options when initialized with images', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BatchScreen(
              initialImages: [sampleImage1, sampleImage2],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Images Selected'), findsOneWidget);
      expect(find.text('+ Scan More'), findsWidgets);
      expect(find.text('Default Batch Settings'), findsOneWidget);
      expect(find.text('Target Size (KB)'), findsWidgets);
      expect(find.text('Scale Dimensions'), findsOneWidget);

      // Verify edit in studio button is in batch cards
      expect(find.byIcon(Icons.crop_rounded), findsNWidgets(2));

      // Switch to Scale Dimensions mode
      await tester.tap(find.text('Scale Dimensions'));
      await tester.pumpAndSettle();

      expect(find.text('Resize Dimensions (% of original)'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);

      // Switch back to Target Size (KB)
      await tester.tap(find.text('Target Size (KB)').first);
      await tester.pumpAndSettle();

      expect(find.text('Custom Target Size'), findsOneWidget);

      // Verify PDF export action in AppBar
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.picture_as_pdf_outlined));
      await tester.pumpAndSettle();

      // Verify BatchPdfExportSheet opens
      expect(find.text('Export as PDF Document'), findsOneWidget);
      expect(find.text('2 pages will be merged into one file'), findsOneWidget);
      expect(find.text('💾 Save to Downloads'), findsOneWidget);
      expect(find.text('Share PDF Document'), findsOneWidget);
    });
  });

  group('BatchPdfExportSheet Widget Tests', () {
    testWidgets('Renders correctly with presets and custom filename', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BatchPdfExportSheet(
              imageFiles: [sampleImage1, sampleImage2],
              defaultFileName: 'Test_Batch.pdf',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Export as PDF Document'), findsOneWidget);
      expect(find.text('2 pages will be merged into one file'), findsOneWidget);
      expect(find.text('PDF File Name'), findsOneWidget);
      expect(find.text('Test_Batch'), findsOneWidget);
      expect(find.text('Document Quality'), findsOneWidget);
      expect(find.text('Medium (< 2 MB)'), findsOneWidget);

      // Verify quality preset chips are present
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Medium'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);

      // Tap Low preset
      await tester.tap(find.text('Low'));
      await tester.pumpAndSettle();
      expect(find.text('Low (< 1 MB)'), findsOneWidget);

      // Action buttons
      expect(find.text('💾 Save to Downloads'), findsOneWidget);
      expect(find.text('Share PDF Document'), findsOneWidget);
    });
  });

  group('BatchScreen Small Screen Overflow Tests', () {
    testWidgets('BatchScreen empty card does not overflow on 360px and 320px narrow screens',
        (WidgetTester tester) async {
      // 1. Test on standard small phone screen (360x640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BatchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);

      // 2. Test on ultra-narrow 320px screen
      tester.view.physicalSize = const Size(320, 640);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);
    });
  });
}

