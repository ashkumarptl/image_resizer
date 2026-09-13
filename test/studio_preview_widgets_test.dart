import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/studio/image_studio_screen.dart';
import 'package:image_resizer/presentation/studio/widgets/studio_bottom_toolbar.dart';
import 'package:image_resizer/presentation/studio/widgets/studio_info_card.dart';
import 'package:image_resizer/presentation/studio/widgets/compress_options_sheet.dart';
import 'package:image_resizer/presentation/studio/widgets/resize_options_sheet.dart';
import 'package:image_resizer/presentation/studio/widgets/flip_options_sheet.dart';
import 'package:image_resizer/presentation/widgets/discard_changes_sheet.dart';

void main() {
  group('StudioInfoCard Widget Tests', () {
    testWidgets('Renders file name, dimensions, size and target summary', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioInfoCard(
              filePath: '/storage/emulated/0/Pictures/IMG-20260905.jpg',
              width: 1080,
              height: 1920,
              fileSizeBytes: 2048000,
              targetSummary: 'Target: < 50 KB • JPG',
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('IMG-20260905.jpg'), findsOneWidget);
      expect(find.text('JPG'), findsOneWidget);
      expect(find.text('1080 × 1920 px   •   2 MB'), findsOneWidget);
      expect(find.text('Target: < 50 KB • JPG'), findsOneWidget);
    });

    testWidgets('Renders structured live estimate, savings pill, and format conversion', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioInfoCard(
              filePath: '/storage/emulated/0/Pictures/sample_photo.jpg',
              width: 1000,
              height: 1000,
              fileSizeBytes: 100000,
              estimatedSizeBytes: 50000,
              outputFormat: 'webp',
              targetGoal: 'Target: < 50 KB',
              outputWidth: 500,
              outputHeight: 500,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text('sample_photo.jpg'), findsOneWidget);
      expect(find.text('JPG'), findsOneWidget);
      expect(find.text('WEBP'), findsOneWidget);
      expect(find.text('Est: 48.8 KB'), findsOneWidget);
      expect(find.text('-50% saved'), findsOneWidget);
      expect(find.text('Target: < 50 KB'), findsOneWidget);
      expect(find.text('➔ 500×500'), findsOneWidget);
    });

    testWidgets('Renders calculating estimate state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudioInfoCard(
              filePath: '/storage/emulated/0/Pictures/sample_photo.jpg',
              width: 1000,
              height: 1000,
              fileSizeBytes: 100000,
              isCalculating: true,
              isDark: true,
            ),
          ),
        ),
      );

      expect(find.text('Calculating estimate...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('StudioBottomToolbar Widget Tests', () {
    testWidgets('Renders all toolbar buttons and responds to taps', (tester) async {
      bool rotateTapped = false;
      bool flipTapped = false;
      bool cropTapped = false;
      bool compressTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioBottomToolbar(
              activeTool: StudioActiveTool.compress,
              hasRotated: true,
              hasFlipped: false,
              hasCropped: true,
              onRotate: () => rotateTapped = true,
              onFlip: () => flipTapped = true,
              onCrop: () => cropTapped = true,
              onCompress: () => compressTapped = true,
              onResize: () {},
              onFormat: () {},
              onBgRemover: () {},
            ),
          ),
        ),
      );

      expect(find.text('ROTATE'), findsOneWidget);
      expect(find.text('FLIP'), findsOneWidget);
      expect(find.text('CROP'), findsOneWidget);
      expect(find.text('COMPRESS'), findsOneWidget);
      expect(find.text('RESIZE'), findsOneWidget);
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('BG REMOVE'), findsOneWidget);
      expect(find.text('REPLACE'), findsNothing);

      // Verify badges
      expect(find.text('ACTIVE'), findsOneWidget); // for rotated
      expect(find.text('DONE'), findsOneWidget); // for cropped
      expect(find.text('PRIMARY'), findsNothing); // primary badge removed

      // Tap buttons
      await tester.tap(find.text('ROTATE'));
      expect(rotateTapped, true);

      await tester.tap(find.text('FLIP'));
      expect(flipTapped, true);

      await tester.tap(find.text('CROP'));
      expect(cropTapped, true);

      await tester.tap(find.text('COMPRESS'));
      expect(compressTapped, true);
    });

    testWidgets('Renders scroll container and chevron edge indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudioBottomToolbar(
              activeTool: StudioActiveTool.compress,
              onRotate: () {},
              onFlip: () {},
              onCrop: () {},
              onCompress: () {},
              onResize: () {},
              onFormat: () {},
              onBgRemover: () {},
              enableSwipeAnimation: false,
            ),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    });
  });

  group('FlipOptionsSheet Widget Tests', () {
    testWidgets('Renders horizontal and vertical flip options', (tester) async {
      bool appliedH = false;
      bool appliedV = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlipOptionsSheet(
              initialFlipHorizontal: false,
              initialFlipVertical: false,
              onApply: (h, v) {
                appliedH = h;
                appliedV = v;
              },
            ),
          ),
        ),
      );

      expect(find.text('Flip Image Orientation'), findsOneWidget);
      expect(find.text('Horizontal'), findsOneWidget);
      expect(find.text('Vertical'), findsOneWidget);

      await tester.tap(find.text('Horizontal'));
      await tester.pump();
      expect(appliedH, true);
      expect(appliedV, false);
    });
  });

  group('CompressOptionsSheet Widget Tests', () {
    testWidgets('Renders preset size chips and applies settings', (tester) async {
      CompressionSheetMode? appliedMode;
      int? appliedSize;
      double? appliedQuality;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompressOptionsSheet(
              initialMode: CompressionSheetMode.targetSize,
              initialTargetSizeKB: 50,
              initialQuality: 85,
              originalSizeBytes: 500000,
              onApply: (mode, size, quality) {
                appliedMode = mode;
                appliedSize = size;
                appliedQuality = quality;
              },
            ),
          ),
        ),
      );

      expect(find.text('Compression Settings'), findsOneWidget);
      expect(find.text('50 KB'), findsWidgets);
      expect(find.text('100 KB'), findsOneWidget);

      // Select 100 KB chip
      await tester.tap(find.text('100 KB'));
      await tester.pump();

      // Tap apply button
      await tester.tap(find.text('Apply Compression Settings'));
      await tester.pump();

      expect(appliedMode, CompressionSheetMode.targetSize);
      expect(appliedSize, 100);
      expect(appliedQuality, 85);
    });

    testWidgets('Target size slider is rendered and changes value on interaction', (tester) async {
      CompressionSheetMode? appliedMode;
      int? appliedSize;
      double? appliedQuality;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CompressOptionsSheet(
                initialMode: CompressionSheetMode.targetSize,
                initialTargetSizeKB: 50,
                initialQuality: 85,
                originalSizeBytes: 500000,
                onApply: (mode, size, quality) {
                  appliedMode = mode;
                  appliedSize = size;
                  appliedQuality = quality;
                },
              ),
            ),
          ),
        ),
      );

      // Verify slider exists
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider towards left
      await tester.drag(sliderFinder, const Offset(-60, 0));
      await tester.pump();

      // Tap apply button
      await tester.tap(find.text('Apply Compression Settings'));
      await tester.pump();

      expect(appliedMode, CompressionSheetMode.targetSize);
      expect(appliedSize, isNotNull);
      expect(appliedSize != 50, isTrue);
      expect(appliedQuality, 85);
    });
  });

  group('ResizeOptionsSheet Widget Tests', () {
    testWidgets('Renders Presets tab with Popular, Social, and Documents presets and applies selection',
        (tester) async {
      ResizeSheetOption? appliedOption;
      int? appliedW;
      int? appliedH;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResizeOptionsSheet(
              initialOption: ResizeSheetOption.none,
              originalWidth: 1536,
              originalHeight: 1024,
              originalSizeBytes: 1600000,
              initialTargetWidth: 1536,
              initialTargetHeight: 1024,
              initialPercentage: 50,
              initialKeepAspectRatio: true,
              onApply: ({
                required option,
                required targetWidth,
                required targetHeight,
                required percentage,
                required keepAspectRatio,
              }) {
                appliedOption = option;
                appliedW = targetWidth;
                appliedH = targetHeight;
              },
            ),
          ),
        ),
      );

      // Verify title, subtitle and top tabs
      expect(find.text('Resize Dimensions'), findsOneWidget);
      expect(find.text('Choose a preset size or enter custom dimensions'), findsOneWidget);
      expect(find.text('Presets'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Percentage'), findsOneWidget);

      // Verify Popular section presets
      expect(find.text('Popular'), findsOneWidget);
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('1536 × 1024'), findsOneWidget);
      expect(find.text('Square'), findsOneWidget);
      expect(find.text('1080 × 1080'), findsWidgets);
      expect(find.text('Portrait'), findsOneWidget);
      expect(find.text('Story'), findsOneWidget);
      expect(find.text('HD'), findsOneWidget);
      expect(find.text('Full HD'), findsOneWidget);
      expect(find.text('2K'), findsOneWidget);
      expect(find.text('4K'), findsOneWidget);

      // Verify Social Media section presets
      expect(find.text('Social Media'), findsOneWidget);
      expect(find.text('Insta Post'), findsOneWidget);
      expect(find.text('Insta Story'), findsOneWidget);
      expect(find.text('YouTube Thumb'), findsOneWidget);
      expect(find.text('LinkedIn Post'), findsOneWidget);

      // Verify Documents section presets
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('A4 Portrait'), findsOneWidget);
      expect(find.text('2480 × 3508'), findsOneWidget);
      expect(find.text('Signature'), findsOneWidget);
      expect(find.text('400 × 200'), findsOneWidget);

      // Select Square preset (1080 × 1080)
      await tester.tap(find.text('Square'));
      await tester.pump();

      // Tap Apply Resize Dimensions
      await tester.tap(find.text('Apply Resize Dimensions'));
      await tester.pump();

      expect(appliedOption, ResizeSheetOption.exactPixels);
      expect(appliedW, 1080);
      expect(appliedH, 1080);
    });

    testWidgets('Custom tab updates dimensions and maintains aspect ratio',
        (tester) async {
      ResizeSheetOption? appliedOption;
      int? appliedW;
      int? appliedH;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResizeOptionsSheet(
              initialOption: ResizeSheetOption.exactPixels,
              originalWidth: 1000,
              originalHeight: 500,
              originalSizeBytes: 1000000,
              initialTargetWidth: 800,
              initialTargetHeight: 400,
              initialPercentage: 50,
              initialKeepAspectRatio: true,
              onApply: ({
                required option,
                required targetWidth,
                required targetHeight,
                required percentage,
                required keepAspectRatio,
              }) {
                appliedOption = option;
                appliedW = targetWidth;
                appliedH = targetHeight;
              },
            ),
          ),
        ),
      );

      // Switch to Custom tab
      await tester.tap(find.text('Custom'));
      await tester.pump();

      expect(find.text('Enter Dimensions'), findsOneWidget);
      expect(find.text('Common Sizes'), findsOneWidget);
      expect(find.text('Keep Aspect Ratio'), findsOneWidget);
      expect(find.text('Use Original'), findsOneWidget);

      // Tap common size 512
      await tester.tap(find.text('512'));
      await tester.pump();

      // Apply
      await tester.tap(find.text('Apply Resize Dimensions'));
      await tester.pump();

      expect(appliedOption, ResizeSheetOption.exactPixels);
      expect(appliedW, 512);
      expect(appliedH, 256); // 1000:500 aspect ratio -> 512:256
    });

    testWidgets('Percentage tab scales dimensions proportionally',
        (tester) async {
      ResizeSheetOption? appliedOption;
      int? appliedW;
      int? appliedH;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResizeOptionsSheet(
              initialOption: ResizeSheetOption.percentage,
              originalWidth: 1200,
              originalHeight: 800,
              originalSizeBytes: 1000000,
              initialTargetWidth: 600,
              initialTargetHeight: 400,
              initialPercentage: 50,
              initialKeepAspectRatio: true,
              onApply: ({
                required option,
                required targetWidth,
                required targetHeight,
                required percentage,
                required keepAspectRatio,
              }) {
                appliedOption = option;
                appliedW = targetWidth;
                appliedH = targetHeight;
              },
            ),
          ),
        ),
      );

      // Should open directly on Percentage tab
      expect(find.text('Select Scale Percentage'), findsOneWidget);
      expect(find.text('75%'), findsWidgets);

      // Tap 75% pill
      await tester.tap(find.text('75%').first);
      await tester.pump();

      expect(find.text('900 × 600 px'), findsOneWidget);

      // Apply
      await tester.tap(find.text('Apply Resize Dimensions'));
      await tester.pump();

      expect(appliedOption, ResizeSheetOption.percentage);
      expect(appliedW, 900);
      expect(appliedH, 600);
    });
  });

  group('DiscardChangesSheet Widget Tests', () {
    testWidgets('Renders discard prompt and handles Keep Editing vs Discard & Exit',
        (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await DiscardChangesSheet.show(context);
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Discard Changes?'), findsOneWidget);
      expect(find.text('Keep Editing'), findsOneWidget);
      expect(find.text('Discard & Exit'), findsOneWidget);

      // Test Keep Editing (returns false)
      await tester.tap(find.text('Keep Editing'));
      await tester.pumpAndSettle();
      expect(result, isFalse);

      // Open sheet again
      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      // Test Discard & Exit (returns true)
      await tester.tap(find.text('Discard & Exit'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });

  group('ImageStudioScreen Quick Presets & Zoom Tests', () {
    late Directory tempDir;
    late File testImageFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('studio_test_');
      testImageFile = File('${tempDir.path}/test.jpg');
      // Create minimal valid 10x10 JPEG bytes
      final testImg = img.Image(width: 10, height: 10);
      await testImageFile.writeAsBytes(img.encodeJpg(testImg));
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Defaults to no active tool and opens compress on toolbar tap',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(initialImage: testImageFile),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Compress preset chips are NOT visible by default
      expect(find.text('20 KB'), findsNothing);
      expect(find.text('50 KB'), findsNothing);

      // Tap COMPRESS toolbar button to toggle on
      await tester.tap(find.text('COMPRESS'));
      await tester.pump();

      // Now preset chips are visible
      expect(find.text('Original'), findsWidgets);
      expect(find.text('20 KB'), findsOneWidget);
      expect(find.text('50 KB'), findsWidgets);
    });

    testWidgets('Renders Quick KB preset chips and updates target KB on tap',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: testImageFile,
              initialTool: StudioActiveTool.compress,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Verify preset chips are rendered (including Original)
      expect(find.text('Original'), findsWidgets);
      expect(find.text('20 KB'), findsOneWidget);
      expect(find.text('50 KB'), findsWidgets); // chip + deck/button
      expect(find.text('100 KB'), findsOneWidget);
      expect(find.text('200 KB'), findsOneWidget);
      expect(find.text('Custom...'), findsOneWidget);

      // Initially defaults to Original compression (preserves full original quality)
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byTooltip('Save with Original Quality'), findsOneWidget);
      expect(find.textContaining('Original Quality'), findsOneWidget);

      // Tap 50 KB chip -> switches to 50 KB target
      await tester.tap(find.text('50 KB').first);
      await tester.pump();
      expect(find.byTooltip('Compress to < 50 KB & Save'), findsOneWidget);
      expect(find.textContaining('Target: < 50 KB'), findsOneWidget);

      // Tap Original chip -> switches back to Original
      await tester.tap(find.text('Original').first);
      await tester.pump();
      expect(find.byTooltip('Save with Original Quality'), findsOneWidget);
      expect(find.textContaining('Original Quality'), findsOneWidget);

      // Tap 20 KB chip
      await tester.tap(find.text('20 KB'));
      await tester.pump();
      expect(find.byTooltip('Compress to < 20 KB & Save'), findsOneWidget);
      expect(find.textContaining('Target: < 20 KB'), findsOneWidget);

      // Tap 100 KB chip
      await tester.ensureVisible(find.text('100 KB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('100 KB'));
      await tester.pump();
      expect(find.byTooltip('Compress to < 100 KB & Save'), findsOneWidget);
      expect(find.textContaining('Target: < 100 KB'), findsOneWidget);

      // Tap 200 KB chip
      await tester.ensureVisible(find.text('200 KB'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('200 KB'));
      await tester.pump();
      expect(find.byTooltip('Compress to < 200 KB & Save'), findsOneWidget);
      expect(find.textContaining('Target: < 200 KB'), findsOneWidget);

      // Tap COMPRESS in bottom toolbar to toggle inactive -> chips should hide
      await tester.tap(find.text('COMPRESS'));
      await tester.pump();
      expect(find.text('20 KB'), findsNothing);
      expect(find.text('100 KB'), findsNothing);

      // Tap COMPRESS again in bottom toolbar to activate -> chips should reappear
      await tester.tap(find.text('COMPRESS'));
      await tester.pump();
      expect(find.text('20 KB'), findsOneWidget);
      expect(find.text('Original'), findsWidgets);
    });

    testWidgets('InteractiveViewer double-tap toggles zoom and Reset Zoom button',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(initialImage: testImageFile),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Initially at 1.0x scale: inspection hint is visible, Reset Zoom is not
      expect(find.text('Pinch or double-tap to inspect'), findsOneWidget);
      expect(find.text('Reset Zoom'), findsNothing);

      // Double-tap on the preview canvas
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(InteractiveViewer));
      await tester.pump();

      // Zoomed in: Reset Zoom button is visible, inspection hint is hidden
      expect(find.text('Reset Zoom'), findsOneWidget);
      expect(find.text('Pinch or double-tap to inspect'), findsNothing);

      // Tap Reset Zoom button
      await tester.tap(find.text('Reset Zoom'));
      await tester.pump();

      // Reset to 1.0x scale: inspection hint returns
      expect(find.text('Pinch or double-tap to inspect'), findsOneWidget);
      expect(find.text('Reset Zoom'), findsNothing);

      // Settle double-tap gesture timeout
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('Toggle button toggles between Preview and Original image',
        (tester) async {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(initialImage: testImageFile),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      // Toggle button should be present
      final toggleButton = find.byKey(const ValueKey('studio_toggle_original_button'));
      expect(toggleButton, findsOneWidget);

      // Default state: Viewing preview with applied settings, button offers "Tap for Original"
      expect(find.text('Tap for Original'), findsOneWidget);
      expect(find.byIcon(Icons.compare), findsOneWidget);
      expect(find.byKey(const ValueKey('canvas_original_image')), findsNothing);

      // Tap toggle button -> switches to Original
      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.text('Viewing Original'), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byKey(const ValueKey('canvas_original_image')), findsOneWidget);

      // Tap toggle button again -> switches back to Preview
      await tester.tap(toggleButton);
      await tester.pump();

      expect(find.text('Tap for Original'), findsOneWidget);
      expect(find.byIcon(Icons.compare), findsOneWidget);
      expect(find.byKey(const ValueKey('canvas_original_image')), findsNothing);
    });

    testWidgets('Undo and Redo buttons enable and revert/restore state correctly',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: testImageFile,
              initialTool: StudioActiveTool.compress,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 150));
      });
      await tester.pump();

      final undoButtonFinder = find.byKey(const ValueKey('studio_undo_button'));
      final redoButtonFinder = find.byKey(const ValueKey('studio_redo_button'));

      expect(undoButtonFinder, findsOneWidget);
      expect(redoButtonFinder, findsOneWidget);

      // Initially, no adjustments made -> both Undo and Redo are disabled
      IconButton undoBtn = tester.widget(undoButtonFinder);
      IconButton redoBtn = tester.widget(redoButtonFinder);
      expect(undoBtn.onPressed, isNull);
      expect(redoBtn.onPressed, isNull);

      // 1. Perform adjustment: Tap 50 KB preset chip
      await tester.tap(find.text('50 KB').first);
      await tester.pump();

      expect(find.byTooltip('Compress to < 50 KB & Save'), findsOneWidget);

      // Now Undo should be enabled, Redo disabled
      undoBtn = tester.widget(undoButtonFinder);
      redoBtn = tester.widget(redoButtonFinder);
      expect(undoBtn.onPressed, isNotNull);
      expect(redoBtn.onPressed, isNull);

      // 2. Tap Undo -> Should revert back to Original Quality
      await tester.tap(undoButtonFinder);
      await tester.pump();

      expect(find.byTooltip('Save with Original Quality'), findsOneWidget);
      undoBtn = tester.widget(undoButtonFinder);
      redoBtn = tester.widget(redoButtonFinder);
      expect(undoBtn.onPressed, isNull); // At initial state, cannot undo further
      expect(redoBtn.onPressed, isNotNull); // Can redo back to 50 KB

      // 3. Tap Redo -> Should restore 50 KB target
      await tester.tap(redoButtonFinder);
      await tester.pump();

      expect(find.byTooltip('Compress to < 50 KB & Save'), findsOneWidget);
      undoBtn = tester.widget(undoButtonFinder);
      redoBtn = tester.widget(redoButtonFinder);
      expect(undoBtn.onPressed, isNotNull);
      expect(redoBtn.onPressed, isNull);

      // 4. Perform second adjustment: Rotate
      await tester.ensureVisible(find.text('ROTATE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ROTATE'));
      await tester.pump();

      // Undo once -> Reverts rotation back to 50 KB unrotated
      await tester.tap(undoButtonFinder);
      await tester.pump();

      expect(find.byTooltip('Compress to < 50 KB & Save'), findsOneWidget);
      redoBtn = tester.widget(redoButtonFinder);
      expect(redoBtn.onPressed, isNotNull);

      // Undo again -> Reverts 50 KB back to Original
      await tester.tap(undoButtonFinder);
      await tester.pump();

      expect(find.byTooltip('Save with Original Quality'), findsOneWidget);

      // Redo once -> Restores 50 KB
      await tester.tap(redoButtonFinder);
      await tester.pump();
      expect(find.byTooltip('Compress to < 50 KB & Save'), findsOneWidget);
    });

    testWidgets('Renders tablet portrait layout correctly with top canvas and bottom control deck',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: testImageFile,
              initialTool: StudioActiveTool.compress,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();

      // Top preset row and canvas
      expect(find.text('Original'), findsWidgets);
      expect(find.text('Process & Save Image'), findsOneWidget);
      // Tool selector tabs in pro deck
      expect(find.text('Compress'), findsWidgets);
      expect(find.text('Resize'), findsWidgets);
      expect(find.text('Format'), findsWidgets);
    });

    testWidgets('Renders tablet landscape layout correctly with left canvas and right inspector',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageStudioScreen(
              initialImage: testImageFile,
              initialTool: StudioActiveTool.compress,
            ),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump();

      // Top preset row and canvas
      expect(find.text('Original'), findsWidgets);
      expect(find.text('Process & Save Image'), findsOneWidget);
      // Tool selector tabs in side inspector
      expect(find.text('Compress'), findsWidgets);
      expect(find.text('Resize'), findsWidgets);
      expect(find.text('Format'), findsWidgets);
      expect(find.text('Tools'), findsWidgets);
    });
  });
}
