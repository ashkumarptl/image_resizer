import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/services/image_service/perspective_cropper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File testImageFile;
  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp;
    final testImage = img.Image(width: 400, height: 400);
    // Draw a colored background with shapes
    img.fill(testImage, color: img.ColorRgb8(240, 240, 240));
    img.fillRect(
      testImage,
      x1: 50,
      y1: 50,
      x2: 350,
      y2: 350,
      color: img.ColorRgb8(20, 50, 180),
    );

    final bytes = img.encodeJpg(testImage);
    testImageFile = File('${tempDir.path}/test_perspective_src.jpg');
    await testImageFile.writeAsBytes(bytes);
  });

  tearDownAll(() async {
    if (testImageFile.existsSync()) {
      await testImageFile.delete();
    }
  });

  group('PerspectiveCropper Service Tests', () {
    test('NormalizedPoint equality and copyWith', () {
      const p1 = NormalizedPoint(0.2, 0.3);
      const p2 = NormalizedPoint(0.2, 0.3);
      final p3 = p1.copyWith(x: 0.5);

      expect(p1, equals(p2));
      expect(p1.hashCode, equals(p2.hashCode));
      expect(p3.x, 0.5);
      expect(p3.y, 0.3);
      expect(p1.toString(), 'NormalizedPoint(0.2, 0.3)');
    });

    test('PerspectiveCropOptions copyWith works', () {
      final options = PerspectiveCropOptions(
        sourcePath: testImageFile.path,
        topLeft: const NormalizedPoint(0.1, 0.1),
        topRight: const NormalizedPoint(0.9, 0.1),
        bottomRight: const NormalizedPoint(0.9, 0.9),
        bottomLeft: const NormalizedPoint(0.1, 0.9),
      );

      final updated = options.copyWith(
        preset: PerspectiveCropPreset.a4,
        filter: PerspectiveFilter.documentBw,
        quarterTurns: 2,
      );

      expect(updated.preset, PerspectiveCropPreset.a4);
      expect(updated.filter, PerspectiveFilter.documentBw);
      expect(updated.quarterTurns, 2);
      expect(updated.sourcePath, testImageFile.path);
    });

    test('rectifyImage rectifies quadrilateral with auto preset', () async {
      final options = PerspectiveCropOptions(
        sourcePath: testImageFile.path,
        topLeft: const NormalizedPoint(0.125, 0.125),
        topRight: const NormalizedPoint(0.875, 0.125),
        bottomRight: const NormalizedPoint(0.875, 0.875),
        bottomLeft: const NormalizedPoint(0.125, 0.875),
        preset: PerspectiveCropPreset.auto,
      );

      final result = await PerspectiveCropper.rectifyImage(options);

      expect(File(result.outputPath).existsSync(), isTrue);
      expect(result.outputWidth, greaterThan(0));
      expect(result.outputHeight, greaterThan(0));
      expect(result.outputSizeBytes, greaterThan(0));
      expect(result.originalWidth, 400);
      expect(result.originalHeight, 400);
    });

    test('rectifyImage generates A4 document ratio', () async {
      final options = PerspectiveCropOptions(
        sourcePath: testImageFile.path,
        topLeft: const NormalizedPoint(0.1, 0.1),
        topRight: const NormalizedPoint(0.9, 0.1),
        bottomRight: const NormalizedPoint(0.9, 0.9),
        bottomLeft: const NormalizedPoint(0.1, 0.9),
        preset: PerspectiveCropPreset.a4,
      );

      final result = await PerspectiveCropper.rectifyImage(options);
      final ratio = result.outputHeight / result.outputWidth;
      // A4 ratio is ~1.414
      expect(ratio, closeTo(1.414, 0.05));
    });

    test('rectifyImage generates ID Card ratio', () async {
      final options = PerspectiveCropOptions(
        sourcePath: testImageFile.path,
        topLeft: const NormalizedPoint(0.1, 0.1),
        topRight: const NormalizedPoint(0.9, 0.1),
        bottomRight: const NormalizedPoint(0.9, 0.9),
        bottomLeft: const NormalizedPoint(0.1, 0.9),
        preset: PerspectiveCropPreset.idCard,
      );

      final result = await PerspectiveCropper.rectifyImage(options);
      final ratio = result.outputWidth / result.outputHeight;
      // ID Card ratio is ~1.586
      expect(ratio, closeTo(1.586, 0.05));
    });

    test('rectifyImage applies document filters and rotation', () async {
      for (final filter in PerspectiveFilter.values) {
        final options = PerspectiveCropOptions(
          sourcePath: testImageFile.path,
          topLeft: const NormalizedPoint(0.1, 0.1),
          topRight: const NormalizedPoint(0.9, 0.1),
          bottomRight: const NormalizedPoint(0.9, 0.9),
          bottomLeft: const NormalizedPoint(0.1, 0.9),
          preset: PerspectiveCropPreset.square,
          filter: filter,
          quarterTurns: 1,
        );

        final result = await PerspectiveCropper.rectifyImage(options);
        expect(File(result.outputPath).existsSync(), isTrue);
        expect(result.outputWidth, equals(result.outputHeight));
      }
    });

    test('applyFilter applies all filters without throwing', () {
      final sample = img.Image(width: 50, height: 50);
      img.fill(sample, color: img.ColorRgb8(120, 150, 200));

      for (final filter in PerspectiveFilter.values) {
        final filtered = PerspectiveCropper.applyFilter(sample, filter);
        expect(filtered.width, equals(50));
        expect(filtered.height, equals(50));
      }
    });
  });
}
