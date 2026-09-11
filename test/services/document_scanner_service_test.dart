import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image_resizer/services/scanner/document_scanner_service.dart';

class FakeDocumentScanner implements DocumentScanner {
  final List<String>? imagesToReturn;
  final bool shouldThrow;
  final Object? errorToThrow;
  bool wasClosed = false;

  FakeDocumentScanner({
    this.imagesToReturn,
    this.shouldThrow = false,
    this.errorToThrow,
  });

  @override
  final id = 'test_id';

  @override
  DocumentScannerOptions get options => DocumentScannerOptions();

  @override
  Future<DocumentScanningResult> scanDocument() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (shouldThrow) {
      throw Exception('Google Play Services unavailable');
    }
    return DocumentScanningResult(
      pdf: null,
      images: imagesToReturn,
    );
  }

  @override
  Future<void> close() async {
    wasClosed = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late File sampleFile1;
  late File sampleFile2;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scanner_test_');
    sampleFile1 = File('${tempDir.path}/doc1.jpg')..writeAsStringSync('doc1');
    sampleFile2 = File('${tempDir.path}/doc2.jpg')..writeAsStringSync('doc2');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('DocumentScannerService Tests', () {
    test('scanMultipleDocuments returns files when scanner returns paths', () async {
      final fakeScanner = FakeDocumentScanner(
        imagesToReturn: [sampleFile1.path, sampleFile2.path],
      );

      final service = DocumentScannerService(
        scannerFactory: (_) => fakeScanner,
      );

      final result = await service.scanMultipleDocuments();

      expect(result.length, 2);
      expect(result[0].path, sampleFile1.path);
      expect(result[1].path, sampleFile2.path);
      expect(fakeScanner.wasClosed, isTrue);
    });

    test('scanSingleDocument returns the first file', () async {
      final fakeScanner = FakeDocumentScanner(
        imagesToReturn: [sampleFile1.path],
      );

      final service = DocumentScannerService(
        scannerFactory: (_) => fakeScanner,
      );

      final result = await service.scanSingleDocument();

      expect(result, isNotNull);
      expect(result!.path, sampleFile1.path);
    });

    test('scanSingleDocument returns null when cancelled / empty', () async {
      final fakeScanner = FakeDocumentScanner(
        imagesToReturn: [],
      );

      final service = DocumentScannerService(
        scannerFactory: (_) => fakeScanner,
      );

      final result = await service.scanSingleDocument();

      expect(result, isNull);
    });

    test('scanMultipleDocuments returns empty list when PlatformException indicates cancellation', () async {
      final fakeScanner = FakeDocumentScanner(
        errorToThrow: PlatformException(
          code: 'DocumentScanner',
          message: 'Operation cancelled',
        ),
      );

      final service = DocumentScannerService(
        scannerFactory: (_) => fakeScanner,
      );

      final result = await service.scanMultipleDocuments();

      expect(result, isEmpty);
      expect(fakeScanner.wasClosed, isTrue);
    });

    test('scanSingleDocument returns null when user cancels scanner', () async {
      final fakeScanner = FakeDocumentScanner(
        errorToThrow: PlatformException(
          code: 'DocumentScanner',
          message: 'Operation cancelled',
        ),
      );

      final service = DocumentScannerService(
        scannerFactory: (_) => fakeScanner,
      );

      final result = await service.scanSingleDocument();

      expect(result, isNull);
      expect(fakeScanner.wasClosed, isTrue);
    });
  });
}
