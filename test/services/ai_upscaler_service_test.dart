import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/services/ai_upscaler_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiUpscalerService service;

  setUp(() {
    service = AiUpscalerService();
  });

  group('AiUpscalerService Tests', () {
    test('Singleton instance maintains consistent reference', () {
      final s1 = AiUpscalerService();
      final s2 = AiUpscalerService();
      expect(identical(s1, s2), isTrue);
    });

    test('Upscales test image with 2x scale and updates dimensions', () async {
      // Create a small 20x20 test image
      final testImg = img.Image(width: 20, height: 20);
      img.fill(testImg, color: img.ColorRgb8(255, 100, 50));
      final bytes = Uint8List.fromList(img.encodeJpg(testImg));

      final result = await service.upscale(
        inputBytes: bytes,
        scale: 2,
        tileSize: 128,
      );

      expect(result.originalWidth, equals(20));
      expect(result.originalHeight, equals(20));
      expect(result.upscaledWidth, equals(40));
      expect(result.upscaledHeight, equals(40));
      expect(result.scale, equals(2));
      expect(result.imageBytes.isNotEmpty, isTrue);
      expect(result.duration.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('Upscales test image with 4x scale', () async {
      final testImg = img.Image(width: 15, height: 15);
      img.fill(testImg, color: img.ColorRgb8(0, 150, 255));
      final bytes = Uint8List.fromList(img.encodeJpg(testImg));

      final result = await service.upscale(
        inputBytes: bytes,
        scale: 4,
        tileSize: 128,
      );

      expect(result.originalWidth, equals(15));
      expect(result.originalHeight, equals(15));
      expect(result.upscaledWidth, equals(60));
      expect(result.upscaledHeight, equals(60));
      expect(result.scale, equals(4));
    });
  });
}
