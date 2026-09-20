import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/data/models/process_options.dart';
import 'package:image_resizer/presentation/batch/batch_screen.dart';
import 'package:image_resizer/presentation/batch/notifiers/batch_notifier.dart';
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
        itemOverrides: {sampleImage2.path: overrideForImg2},
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
    testWidgets(
      'Renders thumbnail, metadata, custom badge, and handles actions',
      (tester) async {
        var removed = false;
        var previewed = false;
        var cropped = false;

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
                onCustomize: () {},
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

        // Tap crop / studio edit button (now on card in place of settings)
        await tester.tap(find.byIcon(Icons.crop_rounded));
        await tester.pump();
        expect(cropped, true);

        // Verify tune icon is removed from card
        expect(find.byIcon(Icons.tune_rounded), findsNothing);
      },
    );
  });

  group('BatchItemSettingsSheet Widget Tests', () {
    testWidgets(
      'Toggles customize switch, modifies KB, and saves custom options',
      (tester) async {
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
      },
    );
  });

  group('BatchScreen Widget Tests', () {
    testWidgets('Renders empty state with Smart Document Scanner option', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BatchScreen())),
      );

      expect(find.text('Batch Processing'), findsOneWidget);
      expect(find.text('Select Multiple Images'), findsOneWidget);
      expect(find.text('Smart Document Scanner'), findsOneWidget);
      expect(find.text('ML KIT'), findsOneWidget);
      expect(find.text('Import from Gallery'), findsOneWidget);
      expect(find.text('From Gallery'), findsNothing);
      expect(find.text('Take Photo'), findsNothing);
    });

    testWidgets('Renders cards and options when initialized with images', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BatchScreen(initialImages: [sampleImage1, sampleImage2]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Images Selected'), findsOneWidget);
      expect(find.text('+ Scan More'), findsWidgets);
      expect(find.text('Default Batch Settings'), findsOneWidget);
      expect(find.text('Target Size (KB)'), findsWidgets);
      expect(find.text('Scale Dimensions'), findsOneWidget);

      // Verify crop studio editing button is in batch cards
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
    testWidgets('Renders correctly with presets and custom filename', (
      tester,
    ) async {
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
    testWidgets(
      'BatchScreen empty card does not overflow on 360px and 320px narrow screens',
      (WidgetTester tester) async {
        // 1. Test on standard small phone screen (360x640)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: BatchScreen())),
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
      },
    );
  });

  group('BatchNotifier & BatchState Unit Tests', () {
    test('Initializes with empty state and adds files', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchNotifierProvider(null).notifier);
      var state = container.read(batchNotifierProvider(null));

      expect(state.items, isEmpty);
      expect(state.canProcess, false);
      expect(state.totalSelectedBytes, 0);

      notifier.addFiles([sampleImage1, sampleImage2]);
      state = container.read(batchNotifierProvider(null));

      expect(state.items.length, 2);
      expect(state.canProcess, true);
      expect(state.totalSelectedBytes, greaterThan(0));
      expect(state.customizedItemCount, 0);

      // Change settings
      notifier.setActiveMode(BatchMode.scalePercentage);
      notifier.setScalePercentage(50);
      notifier.setOutputFormat('webp');

      state = container.read(batchNotifierProvider(null));
      expect(state.activeMode, BatchMode.scalePercentage);
      expect(state.selectedScalePercentage, 50);
      expect(state.outputFormat, 'webp');

      final baseOpts = state.createBaseOptions();
      expect(baseOpts.outputFormat, 'webp');
      expect(baseOpts.resizePercentage, 50);

      // Custom option on item 0
      const customOpt = ProcessOptions(sourcePath: '', targetSizeKB: 75);
      notifier.setItemCustomOptions(0, customOpt);
      state = container.read(batchNotifierProvider(null));
      expect(state.customizedItemCount, 1);
      expect(state.items[0].hasCustomOptions, true);

      // Reset all custom overrides
      notifier.resetAllCustomOverrides();
      state = container.read(batchNotifierProvider(null));
      expect(state.customizedItemCount, 0);

      // Remove single item
      notifier.removeItemAt(0);
      state = container.read(batchNotifierProvider(null));
      expect(state.items.length, 1);

      // Clear all
      notifier.clearAll();
      state = container.read(batchNotifierProvider(null));
      expect(state.items, isEmpty);
    });

    test('Reordering, Multi-selection, Live estimation, and Quick Presets', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchNotifierProvider(null).notifier);
      notifier.addFiles([sampleImage1, sampleImage2]);
      var state = container.read(batchNotifierProvider(null));

      // 1. Reordering
      expect(state.items.first.path, sampleImage1.path);
      notifier.reorderItems(0, 2);
      state = container.read(batchNotifierProvider(null));
      expect(state.items.first.path, sampleImage2.path);

      // 2. Multi-selection
      expect(state.hasSelection, false);
      notifier.toggleItemSelection(sampleImage1.path);
      state = container.read(batchNotifierProvider(null));
      expect(state.hasSelection, true);
      expect(state.selectionCount, 1);
      expect(state.isAllSelected, false);

      notifier.selectAll();
      state = container.read(batchNotifierProvider(null));
      expect(state.isAllSelected, true);
      expect(state.selectionCount, 2);

      notifier.deselectAll();
      state = container.read(batchNotifierProvider(null));
      expect(state.hasSelection, false);

      // 3. Output Estimation
      expect(state.estimatedTotalOutputBytes, greaterThan(0));
      expect(state.estimatedTotalOutputBytes, lessThanOrEqualTo(state.totalSelectedBytes));
      expect(state.estimatedSavedPercentage, greaterThanOrEqualTo(0.0));

      // 5. Bulk delete selected
      notifier.toggleItemSelection(sampleImage1.path);
      notifier.removeSelectedItems();
      state = container.read(batchNotifierProvider(null));
      expect(state.items.length, 1);
      expect(state.items.first.path, sampleImage2.path);
      expect(state.hasSelection, false);
    });

    test('Cancellation and Failure tracking with Retry support', () async {
      final token = BatchCancellationToken();
      expect(token.isCancelled, false);
      token.cancel();
      expect(token.isCancelled, true);

      // Process batch with already cancelled token
      const baseOptions = ProcessOptions(
        sourcePath: '',
        targetSizeKB: 100,
        outputFormat: 'jpg',
      );

      final cancelledResult = await BatchProcessor.processBatch(
        sourceFilePaths: [sampleImage1.path, sampleImage2.path],
        baseOptions: baseOptions,
        cancellationToken: token,
      );

      expect(cancelledResult.isCancelled, true);

      // Process batch with an invalid file to verify failure tracking
      final failureResult = await BatchProcessor.processBatch(
        sourceFilePaths: ['/invalid/path/non_existent.jpg', sampleImage1.path],
        baseOptions: baseOptions,
      );

      expect(failureResult.hasFailures, true);
      expect(failureResult.failureCount, 1);
      expect(failureResult.failures.first.fileName, 'non_existent.jpg');
      expect(failureResult.successCount, 1);
    });

    test('Dynamic Per-Image Settings: focusing item overrides its settings dynamically', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(batchNotifierProvider(null).notifier);
      notifier.addFiles([sampleImage1, sampleImage2]);
      var state = container.read(batchNotifierProvider(null));

      // Global defaults
      expect(state.activeMode, BatchMode.targetSize);
      expect(state.selectedTargetSizeKB, 100);
      expect(state.focusedItemPath, isNull);
      expect(state.focusedItem, isNull);

      // Focus first image
      notifier.setFocusedItem(sampleImage1.path);
      state = container.read(batchNotifierProvider(null));
      expect(state.focusedItemPath, sampleImage1.path);
      expect(state.focusedItem?.fileName, sampleImage1.path.split('/').last);

      // Modifying setting while focused modifies customOptions for that item ONLY
      notifier.setTargetSizeKB(350);
      notifier.setOutputFormat('png');
      state = container.read(batchNotifierProvider(null));

      // Global defaults unchanged
      expect(state.selectedTargetSizeKB, 100);
      expect(state.outputFormat, 'jpg');

      // Focused item has custom options
      expect(state.focusedItem?.hasCustomOptions, true);
      expect(state.focusedItem?.customOptions?.targetSizeKB, 350);
      expect(state.focusedItem?.customOptions?.outputFormat, 'png');

      // Second image does not have custom options
      expect(state.items[1].hasCustomOptions, false);

      // Reset focused item options
      notifier.resetFocusedItemOptions();
      state = container.read(batchNotifierProvider(null));
      expect(state.focusedItem?.hasCustomOptions, false);

      // Clear focus
      notifier.clearFocusedItem();
      state = container.read(batchNotifierProvider(null));
      expect(state.focusedItemPath, isNull);
      expect(state.focusedItem, isNull);
    });
  });

  group('Dynamic Per-Image Settings Widget Tests', () {
    testWidgets('Clicking image card dynamically opens custom settings in BatchSettingsCard', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BatchScreen(initialImages: [sampleImage1, sampleImage2]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows global settings
      expect(find.text('Default Batch Settings'), findsOneWidget);
      expect(find.text('EDITING'), findsNothing);
      expect(find.text('CUSTOM IMAGE'), findsNothing);

      // Tap on the first image thumbnail to focus it
      await tester.tap(
        find.descendant(
          of: find.byType(BatchImageCard).first,
          matching: find.byType(GestureDetector),
        ).first,
      );
      await tester.pumpAndSettle();

      // Now settings card morphs to focused item custom settings
      expect(find.text('CUSTOM IMAGE'), findsOneWidget);
      expect(find.text('EDITING'), findsOneWidget);
      expect(find.text('Default Batch Settings'), findsNothing);

      // Tap close button on the focused settings banner
      await tester.tap(find.byTooltip('Back to Batch Defaults'));
      await tester.pumpAndSettle();

      // Reverts to Default Batch Settings
      expect(find.text('Default Batch Settings'), findsOneWidget);
      expect(find.text('EDITING'), findsNothing);

      // Now tap specifically on the mid-section (file name text)
      final fileNameText = sampleImage2.path.split('/').last;
      await tester.tap(find.text(fileNameText));
      await tester.pumpAndSettle();

      // Should focus the second image
      expect(find.text('CUSTOM IMAGE'), findsOneWidget);
      expect(find.text('EDITING'), findsOneWidget);
    });

    testWidgets('Checking image select checkbox immediately opens custom settings, and multi-selection shows multi-select banner', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BatchScreen(initialImages: [sampleImage1, sampleImage2]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially shows global settings
      expect(find.text('Default Batch Settings'), findsOneWidget);

      // Tap select checkbox on first image
      await tester.tap(find.byKey(ValueKey('batch_card_select_${sampleImage1.path}')));
      await tester.pumpAndSettle();

      // Now custom settings card is displayed for the selected image!
      expect(find.text('CUSTOM IMAGE'), findsOneWidget);
      expect(find.text('Default Batch Settings'), findsNothing);

      // Select second image as well
      await tester.tap(find.byKey(ValueKey('batch_card_select_${sampleImage2.path}')));
      await tester.pumpAndSettle();

      // Now multi-selection banner is displayed in BatchSettingsCard
      expect(find.text('2 SELECTED'), findsOneWidget);
      expect(find.text('Settings apply to all 2 images'), findsOneWidget);
    });
  });
}


