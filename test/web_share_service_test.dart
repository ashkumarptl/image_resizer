import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/services/web_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile1;
  late File sampleFile2;

  setUp(() async {
    HttpOverrides.global = null;
    tempDir = await Directory.systemTemp.createTemp('web_share_test_');
    sampleFile1 = File('${tempDir.path}/test_image_1.jpg');
    sampleFile2 = File('${tempDir.path}/test_image_2.png');

    await sampleFile1.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03]);
    await sampleFile2.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0x04, 0x05, 0x06]);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WebShareService Tests', () {
    test('startServer fails when provided file paths do not exist', () async {
      final service = WebShareService();
      expect(
        () => service.startServer(filePaths: ['/non/existent/file.jpg']),
        throwsA(isA<Exception>()),
      );
      service.dispose();
    });

    test('startServer binds and serves HTTP endpoints correctly', () async {
      final service = WebShareService();
      final events = <WebShareEvent>[];
      final sub = service.eventStream.listen(events.add);

      // Start server with 2 test files on an ephemeral port
      final url = await service.startServer(
        filePaths: [sampleFile1.path, sampleFile2.path],
        preferredPort: 0,
      );

      expect(url, isNotEmpty);
      expect(service.isRunning, isTrue);
      expect(service.port, isNotNull);
      expect(service.port, isPositive);
      expect(service.filePaths.length, equals(2));

      final client = HttpClient();

      try {
        // 1. Test GET / (HTML preview page)
        final rootReq = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/'));
        final rootRes = await rootReq.close();
        expect(rootRes.statusCode, equals(HttpStatus.ok));
        expect(rootRes.headers.contentType?.mimeType, equals('text/html'));
        final htmlContent = await rootRes.transform(const SystemEncoding().decoder).join();
        expect(htmlContent, contains('Image Tools Web Share'));
        expect(htmlContent, contains('test_image_1.jpg'));
        expect(htmlContent, contains('test_image_2.png'));
        expect(htmlContent, contains('Download All as ZIP Archive'));

        // Check clientConnected event was recorded
        expect(
          events.any((e) => e.type == WebShareEventType.clientConnected),
          isTrue,
        );

        // 2. Test GET /image?index=0 (Image Preview)
        final imgReq = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/image?index=0'));
        final imgRes = await imgReq.close();
        expect(imgRes.statusCode, equals(HttpStatus.ok));
        expect(imgRes.headers.contentType?.mimeType, equals('image/jpeg'));
        final imgBytes = await imgRes.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        expect(imgBytes, equals([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03]));

        // 3. Test GET /image?index=1 (Second image preview PNG)
        final img2Req = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/image?index=1'));
        final img2Res = await img2Req.close();
        expect(img2Res.statusCode, equals(HttpStatus.ok));
        expect(img2Res.headers.contentType?.mimeType, equals('image/png'));
        final img2Bytes = await img2Res.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        expect(img2Bytes, equals([0x89, 0x50, 0x4E, 0x47, 0x04, 0x05, 0x06]));

        // 4. Test GET /download?index=0 (Direct download with attachment header)
        final dlReq = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/download?index=0'));
        final dlRes = await dlReq.close();
        expect(dlRes.statusCode, equals(HttpStatus.ok));
        expect(
          dlRes.headers.value('Content-Disposition'),
          contains('attachment; filename="test_image_1.jpg"'),
        );
        final dlBytes = await dlRes.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        expect(dlBytes, equals([0xFF, 0xD8, 0xFF, 0xE0, 0x01, 0x02, 0x03]));

        // Check fileDownloaded event
        expect(
          events.any((e) => e.type == WebShareEventType.fileDownloaded && e.fileIndex == 0),
          isTrue,
        );

        // 5. Test GET /download-all (ZIP archive)
        final zipReq = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/download-all'));
        final zipRes = await zipReq.close();
        expect(zipRes.statusCode, equals(HttpStatus.ok));
        expect(zipRes.headers.contentType?.mimeType, equals('application/zip'));
        expect(
          zipRes.headers.value('Content-Disposition'),
          contains('attachment; filename="image_tools_batch.zip"'),
        );

        final zipBytes = await zipRes.fold<List<int>>([], (prev, elem) => prev..addAll(elem));
        expect(zipBytes, isNotEmpty);

        // Verify ZIP contents using archive package
        final archive = ZipDecoder().decodeBytes(zipBytes);
        expect(archive.length, equals(2));
        final fileNames = archive.map((f) => f.name).toList();
        expect(fileNames, contains('test_image_1.jpg'));
        expect(fileNames, contains('test_image_2.png'));

        // 6. Test GET /unknown-path -> 404
        final notFoundReq = await client.getUrl(Uri.parse('http://127.0.0.1:${service.port}/random_route'));
        final notFoundRes = await notFoundReq.close();
        expect(notFoundRes.statusCode, equals(HttpStatus.notFound));
      } finally {
        client.close();
        await service.stopServer();
        await Future.delayed(const Duration(milliseconds: 50));
        await sub.cancel();
        service.dispose();
      }

      expect(service.isRunning, isFalse);
      expect(
        events.any((e) => e.type == WebShareEventType.serverStopped),
        isTrue,
      );
    });
  });
}
