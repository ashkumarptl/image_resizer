import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/services/image_service/heic_converter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HeicConverter Tests', () {
    test('isHeicFile identifies file extension accurately', () {
      expect(HeicConverter.isHeicFile('/path/to/image.heic'), isTrue);
      expect(HeicConverter.isHeicFile('/path/to/image.HEIC'), isTrue);
      expect(HeicConverter.isHeicFile('/path/to/image.heif'), isTrue);
      expect(HeicConverter.isHeicFile('/path/to/image.HEIF'), isTrue);
      expect(HeicConverter.isHeicFile('/path/to/image.jpg'), isFalse);
      expect(HeicConverter.isHeicFile('/path/to/image.png'), isFalse);
      expect(HeicConverter.isHeicFile('/path/to/image.webp'), isFalse);
    });

    test(
      'ensureCompatibleImage returns non-HEIC file as-is without processing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('heic_test_');
        final jpgFile = File('${tempDir.path}/test.jpg');
        await jpgFile.writeAsBytes([1, 2, 3, 4]);

        final result = await HeicConverter.ensureCompatibleImage(jpgFile.path);
        expect(result, equals(jpgFile.path));

        await tempDir.delete(recursive: true);
      },
    );
  });
}
