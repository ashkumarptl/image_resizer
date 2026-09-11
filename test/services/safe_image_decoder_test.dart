import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/services/image_service/safe_image_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List standardJpgBytes;
  late Uint8List ultraLargeJpgBytes;

  setUpAll(() {
    // 1. Standard 800x600 image
    final standardImg = img.Image(width: 800, height: 600);
    img.fill(standardImg, color: img.ColorRgba8(0, 128, 255, 255));
    standardJpgBytes = Uint8List.fromList(img.encodeJpg(standardImg, quality: 85));

    // 2. High-res 4000x3000 image (12MP) for scaling tests
    final largeImg = img.Image(width: 4000, height: 3000);
    img.fill(largeImg, color: img.ColorRgba8(255, 64, 64, 255));
    ultraLargeJpgBytes = Uint8List.fromList(img.encodeJpg(largeImg, quality: 75));
  });

  group('SafeImageDecoder Tests', () {
    test('readHeaderDimensions reads dimensions without full decoding', () {
      final dims = SafeImageDecoder.readHeaderDimensions(standardJpgBytes);
      expect(dims, isNotNull);
      expect(dims?.width, 800);
      expect(dims?.height, 600);
    });

    test('decodeSafe preserves exact dimensions for standard resolution images', () async {
      final decoded = await SafeImageDecoder.decodeSafe(standardJpgBytes);
      expect(decoded, isNotNull);
      expect(decoded?.width, 800);
      expect(decoded?.height, 600);
    });

    test('decodeSafe downsamples ultra-large images when exceeding maxDimension', () async {
      // Set maxDimension = 1600 on 4000x3000 image
      final decoded = await SafeImageDecoder.decodeSafe(
        ultraLargeJpgBytes,
        maxDimension: 1600,
        maxPixels: 2000000, // 2MP limit
      );

      expect(decoded, isNotNull);
      // Max dimension should be capped at <= 1600
      expect(decoded!.width <= 1600, isTrue);
      // Aspect ratio (4:3) must be preserved within 1 pixel
      final expectedHeight = (decoded.width * 3 / 4).round();
      expect((decoded.height - expectedHeight).abs() <= 1, isTrue);
    });

    test('ensureSafeForMlKit downsizes ultra-large file to safe resolution', () async {
      final tempDir = Directory.systemTemp.createTempSync('mlkit_test_');
      final sourceFile = File('${tempDir.path}/large_photo.jpg');
      await sourceFile.writeAsBytes(ultraLargeJpgBytes);

      final safeFile = await SafeImageDecoder.ensureSafeForMlKit(
        sourceFile,
        maxDimension: 1500,
      );

      expect(safeFile.existsSync(), isTrue);

      final safeBytes = safeFile.readAsBytesSync();
      final header = SafeImageDecoder.readHeaderDimensions(safeBytes);
      expect(header, isNotNull);
      expect(header!.width <= 1500, isTrue);
      expect(header.height <= 1500, isTrue);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });
  });
}
