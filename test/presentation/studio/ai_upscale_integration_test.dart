import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/presentation/studio/models/studio_history_state.dart';
import 'package:image_resizer/presentation/studio/widgets/ai_upscale_sheet.dart';
import 'package:image_resizer/presentation/studio/widgets/compress_options_sheet.dart';
import 'package:image_resizer/presentation/studio/widgets/resize_options_sheet.dart';
import 'package:image_resizer/presentation/studio/widgets/studio_bottom_toolbar.dart';

void main() {
  group('Studio AI Upscale Integration Tests', () {
    test('StudioActiveTool enum contains upscale', () {
      expect(StudioActiveTool.values.contains(StudioActiveTool.upscale), isTrue);
    });

    test('AiUpscaleSheetResult model fields initialize correctly', () {
      final file = File('test_output.jpg');
      final result = AiUpscaleSheetResult(
        file: file,
        scale: 2,
        upscaledWidth: 1024,
        upscaledHeight: 768,
        duration: const Duration(seconds: 3),
      );

      expect(result.file.path, equals('test_output.jpg'));
      expect(result.scale, equals(2));
      expect(result.upscaledWidth, equals(1024));
      expect(result.upscaledHeight, equals(768));
      expect(result.duration.inSeconds, equals(3));
    });

    test('StudioHistoryState records hasUpscaled and compares in matches()', () {
      final file = File('sample.jpg');
      final state1 = StudioHistoryState(
        imageFile: file,
        originalWidth: 800,
        originalHeight: 600,
        fileSizeBytes: 10240,
        quarterTurns: 0,
        flipHorizontal: false,
        flipVertical: false,
        hasCropped: false,
        hasRemovedBg: false,
        hasUpscaled: false,
        resizeOption: ResizeSheetOption.none,
        targetWidth: 800,
        targetHeight: 600,
        selectedPercentage: 100,
        keepAspectRatio: true,
        compressionMode: CompressionSheetMode.none,
        selectedTargetSizeKB: 50,
        quality: 85,
        outputFormat: 'jpg',
      );

      final state2 = StudioHistoryState(
        imageFile: file,
        originalWidth: 800,
        originalHeight: 600,
        fileSizeBytes: 10240,
        quarterTurns: 0,
        flipHorizontal: false,
        flipVertical: false,
        hasCropped: false,
        hasRemovedBg: false,
        hasUpscaled: true,
        resizeOption: ResizeSheetOption.none,
        targetWidth: 800,
        targetHeight: 600,
        selectedPercentage: 100,
        keepAspectRatio: true,
        compressionMode: CompressionSheetMode.none,
        selectedTargetSizeKB: 50,
        quality: 85,
        outputFormat: 'jpg',
      );

      expect(state1.hasUpscaled, isFalse);
      expect(state2.hasUpscaled, isTrue);
      expect(state1.matches(state2), isFalse);
    });

    testWidgets('StudioBottomToolbar renders AI UPSCALE tool button and responds to tap', (tester) async {
      bool upscaleTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StudioBottomToolbar(
              activeTool: StudioActiveTool.none,
              hasRotated: false,
              hasFlipped: false,
              hasCropped: false,
              hasRemovedBg: false,
              hasUpscaled: false,
              onRotate: () {},
              onFlip: () {},
              onCrop: () {},
              onBgRemover: () {},
              onUpscale: () => upscaleTapped = true,
              onCompress: () {},
              onCompressLongPress: () {},
              onResize: () {},
              onFormat: () {},
            ),
          ),
        ),
      );

      final upscaleBtn = find.text('AI UPSCALE');
      expect(upscaleBtn, findsOneWidget);

      await tester.tap(upscaleBtn);
      await tester.pump();

      expect(upscaleTapped, isTrue);
    });
  });
}

