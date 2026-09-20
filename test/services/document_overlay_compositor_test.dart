import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/presentation/document_overlay/models/overlay_item_model.dart';
import 'package:image_resizer/services/image_service/document_overlay_compositor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('overlay_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return tempDir.path;
    });
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('OverlayItemModel Tests', () {
    test('Default values and copyWith work properly', () {
      final dummyFile = File('dummy.jpg');
      final model = OverlayItemModel(
        id: 'test_1',
        file: dummyFile,
        type: OverlayItemType.photo,
        label: 'Aadhaar Card',
        normalizedX: 0.5,
        normalizedY: 0.3,
        normalizedWidth: 0.6,
        normalizedHeight: 0.4,
      );

      expect(model.id, 'test_1');
      expect(model.type, OverlayItemType.photo);
      expect(model.normalizedX, 0.5);
      expect(model.hasBorder, false);

      final updated = model.copyWith(
        hasBorder: true,
        rotation: 1.57,
        opacity: 0.9,
      );

      expect(updated.hasBorder, true);
      expect(updated.rotation, 1.57);
      expect(updated.opacity, 0.9);
      expect(updated.normalizedX, 0.5);
    });
  });

  group('DocumentOverlayCompositor Tests', () {
    test('Composites A4 sheet with two layers (Aadhaar Front & Back)', () async {
      // Create two small dummy images
      final frontImg = img.Image(width: 200, height: 120);
      img.fill(frontImg, color: img.ColorRgba8(255, 100, 100, 255)); // Red
      final frontFile = File('${tempDir.path}/front.jpg');
      await frontFile.writeAsBytes(img.encodeJpg(frontImg));

      final backImg = img.Image(width: 200, height: 120);
      img.fill(backImg, color: img.ColorRgba8(100, 100, 255, 255)); // Blue
      final backFile = File('${tempDir.path}/back.jpg');
      await backFile.writeAsBytes(img.encodeJpg(backImg));

      final layers = [
        OverlayLayerConfig(
          imagePath: frontFile.path,
          normalizedX: 0.5,
          normalizedY: 0.3,
          normalizedWidth: 0.6,
          normalizedHeight: 0.25,
          hasBorder: true,
        ),
        OverlayLayerConfig(
          imagePath: backFile.path,
          normalizedX: 0.5,
          normalizedY: 0.7,
          normalizedWidth: 0.6,
          normalizedHeight: 0.25,
          hasBorder: true,
        ),
      ];

      final params = DocumentOverlayParams(
        pageSize: CanvasPageSize.a4Portrait,
        layers: layers,
        outputFormat: 'jpg',
        outputQuality: 90,
      );

      final result = await DocumentOverlayCompositor.composite(params);

      expect(File(result.outputPath).existsSync(), true);
      expect(result.outputWidth, 2480);
      expect(result.outputHeight, 3508);
      expect(result.outputSizeBytes > 0, true);
      expect(result.outputFormat, 'jpg');
    });

    test('Composites A4 sheet with base document and signature layer', () async {
      // Create a base document image
      final baseDoc = img.Image(width: 400, height: 600);
      img.fill(baseDoc, color: img.ColorRgba8(240, 240, 240, 255));
      final baseFile = File('${tempDir.path}/base_doc.jpg');
      await baseFile.writeAsBytes(img.encodeJpg(baseDoc));

      final sigImg = img.Image(width: 150, height: 50);
      img.fill(sigImg, color: img.ColorRgba8(0, 50, 200, 255));
      final sigFile = File('${tempDir.path}/signature.png');
      await sigFile.writeAsBytes(img.encodePng(sigImg));

      final params = DocumentOverlayParams(
        baseImagePath: baseFile.path,
        pageSize: CanvasPageSize.a4Landscape,
        layers: [
          OverlayLayerConfig(
            imagePath: sigFile.path,
            normalizedX: 0.75,
            normalizedY: 0.8,
            normalizedWidth: 0.2,
            normalizedHeight: 0.1,
          ),
        ],
        outputFormat: 'jpg',
      );

      final result = await DocumentOverlayCompositor.composite(params);

      expect(File(result.outputPath).existsSync(), true);
      expect(result.outputWidth, 3508);
      expect(result.outputHeight, 2480);
      expect(result.outputSizeBytes > 0, true);
    });
  });
}
