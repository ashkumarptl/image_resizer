import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/services/image_service/dpi_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Uint8List standardJpgBytes;
  late Uint8List standardPngBytes;

  setUpAll(() {
    // 1. Create a 200x200 test image
    final testImg = img.Image(width: 200, height: 200);
    img.fill(testImg, color: img.ColorRgba8(50, 150, 250, 255));

    standardJpgBytes = Uint8List.fromList(img.encodeJpg(testImg, quality: 90));
    standardPngBytes = Uint8List.fromList(img.encodePng(testImg));
  });

  group('DpiService Physical Dimension Calculations', () {
    test('calculatePixelsFromPhysicalSize correctly calculates pixels for inch units', () {
      final dims = DpiService.calculatePixelsFromPhysicalSize(
        width: 2.0,
        height: 2.0,
        unit: 'inch',
        dpi: 300,
      );
      expect(dims.width, 600);
      expect(dims.height, 600);
    });

    test('calculatePixelsFromPhysicalSize calculates pixels for cm units at 200 DPI', () {
      // 3.5cm x 4.5cm at 200 DPI (SSC / Indian Exam standard)
      // 3.5 * (200 / 2.54) = 275.59 -> 276
      // 4.5 * (200 / 2.54) = 354.33 -> 354
      final dims = DpiService.calculatePixelsFromPhysicalSize(
        width: 3.5,
        height: 4.5,
        unit: 'cm',
        dpi: 200,
      );
      expect(dims.width, 276);
      expect(dims.height, 354);
    });

    test('calculatePixelsFromPhysicalSize calculates pixels for mm units at 300 DPI', () {
      // 35mm x 45mm at 300 DPI (Passport standard)
      // 35 * (300 / 25.4) = 413.38 -> 413
      // 45 * (300 / 25.4) = 531.49 -> 531
      final dims = DpiService.calculatePixelsFromPhysicalSize(
        width: 35,
        height: 45,
        unit: 'mm',
        dpi: 300,
      );
      expect(dims.width, 413);
      expect(dims.height, 531);
    });
  });

  group('DpiService JPEG DPI Tests', () {
    test('Injects and reads 200 DPI into JPEG', () {
      final updatedBytes = DpiService.setDpi(standardJpgBytes, 200, format: 'jpg');
      expect(updatedBytes.length >= standardJpgBytes.length, isTrue);

      final readDpi = DpiService.readDpi(updatedBytes);
      expect(readDpi, 200);

      // Verify that the JPEG remains valid and decodable
      final decoded = img.decodeJpg(updatedBytes);
      expect(decoded, isNotNull);
      expect(decoded?.width, 200);
      expect(decoded?.height, 200);
    });

    test('Injects and reads 300 DPI into JPEG', () {
      final updatedBytes = DpiService.setDpi(standardJpgBytes, 300, format: 'jpeg');
      final readDpi = DpiService.readDpi(updatedBytes);
      expect(readDpi, 300);

      final decoded = img.decodeJpg(updatedBytes);
      expect(decoded, isNotNull);
      expect(decoded?.width, 200);
    });

    test('Overwrites existing DPI when setDpi is called repeatedly', () {
      final bytes200 = DpiService.setDpi(standardJpgBytes, 200, format: 'jpg');
      expect(DpiService.readDpi(bytes200), 200);

      final bytes600 = DpiService.setDpi(bytes200, 600, format: 'jpg');
      expect(DpiService.readDpi(bytes600), 600);
    });
  });

  group('DpiService PNG DPI Tests', () {
    test('Injects and reads 200 DPI into PNG via pHYs chunk', () {
      final updatedBytes = DpiService.setDpi(standardPngBytes, 200, format: 'png');
      expect(updatedBytes.length, greaterThan(standardPngBytes.length));

      final readDpi = DpiService.readDpi(updatedBytes);
      // Tolerance of 1 DPI due to meter/inch conversion rounding
      expect((readDpi! - 200).abs() <= 1, isTrue);

      // Verify PNG remains valid and decodable
      final decoded = img.decodePng(updatedBytes);
      expect(decoded, isNotNull);
      expect(decoded?.width, 200);
      expect(decoded?.height, 200);
    });

    test('Injects and reads 300 DPI into PNG via pHYs chunk', () {
      final updatedBytes = DpiService.setDpi(standardPngBytes, 300, format: 'png');
      final readDpi = DpiService.readDpi(updatedBytes);
      expect((readDpi! - 300).abs() <= 1, isTrue);

      final decoded = img.decodePng(updatedBytes);
      expect(decoded, isNotNull);
    });

    test('Replaces existing pHYs chunk when updating DPI on PNG', () {
      final bytes200 = DpiService.setDpi(standardPngBytes, 200, format: 'png');
      final bytes600 = DpiService.setDpi(bytes200, 600, format: 'png');

      final readDpi = DpiService.readDpi(bytes600);
      expect((readDpi! - 600).abs() <= 1, isTrue);
    });
  });

  group('DpiService Safety and Edge Cases', () {
    test('Returns original bytes for empty or corrupt data', () {
      final empty = Uint8List(0);
      expect(DpiService.readDpi(empty), isNull);
      expect(DpiService.setDpi(empty, 300), empty);

      final shortBytes = Uint8List.fromList([0xFF, 0xD8]);
      expect(DpiService.readDpi(shortBytes), isNull);
    });

    test('Ignores invalid targetDpi <= 0', () {
      final unchanged = DpiService.setDpi(standardJpgBytes, 0);
      expect(unchanged, standardJpgBytes);
    });
  });
}
