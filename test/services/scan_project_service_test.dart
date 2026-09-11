import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/data/models/scan_project.dart';
import 'package:image_resizer/services/scanner/document_scanner_service.dart';
import 'package:image_resizer/services/scanner/scan_project_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScanProject Model Tests', () {
    test('serializes to and from JSON correctly', () {
      final now = DateTime.now();
      final project = ScanProject(
        id: 'proj_123',
        name: 'Passport & Visa',
        pagePaths: ['/path/to/page1.jpg', '/path/to/page2.jpg'],
        pdfPath: '/path/to/doc.pdf',
        createdAt: now,
        updatedAt: now,
      );

      final json = project.toJson();
      final fromJson = ScanProject.fromJson(json);

      expect(fromJson.id, equals('proj_123'));
      expect(fromJson.name, equals('Passport & Visa'));
      expect(fromJson.pageCount, equals(2));
      expect(fromJson.coverImagePath, equals('/path/to/page1.jpg'));
      expect(fromJson.pdfPath, equals('/path/to/doc.pdf'));
    });

    test('serializes to and from JSON correctly with new fields', () {
      final now = DateTime.now();
      final project = ScanProject(
        id: 'proj_123',
        name: 'Passport & Visa',
        pagePaths: ['/path/to/page1.jpg', '/path/to/page2.jpg'],
        originalPagePaths: ['/path/to/orig1.jpg', '/path/to/orig2.jpg'],
        pageFilters: {'0': 'bwClean', '1': 'magicColor'},
        pdfQuality: 'low',
        pdfPath: '/path/to/doc.pdf',
        createdAt: now,
        updatedAt: now,
      );

      final json = project.toJson();
      final fromJson = ScanProject.fromJson(json);

      expect(fromJson.id, equals('proj_123'));
      expect(fromJson.name, equals('Passport & Visa'));
      expect(fromJson.pageCount, equals(2));
      expect(fromJson.coverImagePath, equals('/path/to/page1.jpg'));
      expect(fromJson.originalPagePaths, equals(['/path/to/orig1.jpg', '/path/to/orig2.jpg']));
      expect(fromJson.pageFilters['0'], equals('bwClean'));
      expect(fromJson.pageFilters['1'], equals('magicColor'));
      expect(fromJson.pdfQuality, equals('low'));
      expect(fromJson.pdfPath, equals('/path/to/doc.pdf'));
    });

    test('copyWith modifies attributes properly', () {
      final project = ScanProject(
        id: 'proj_1',
        name: 'Original Name',
        pagePaths: ['p1'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = project.copyWith(
        name: 'Renamed Doc',
        pagePaths: ['p1', 'p2'],
        pdfQuality: 'original',
        pageFilters: {'0': 'documentGrayscale'},
      );
      expect(updated.name, equals('Renamed Doc'));
      expect(updated.pageCount, equals(2));
      expect(updated.id, equals('proj_1'));
      expect(updated.pdfQuality, equals('original'));
      expect(updated.pageFilters['0'], equals('documentGrayscale'));
    });
  });

  group('PdfQualityPreset Tests', () {
    test('fromString parses correctly with fallback to medium', () {
      expect(PdfQualityPreset.fromString('low'), equals(PdfQualityPreset.low));
      expect(PdfQualityPreset.fromString('medium'), equals(PdfQualityPreset.medium));
      expect(PdfQualityPreset.fromString('original'), equals(PdfQualityPreset.original));
      expect(PdfQualityPreset.fromString('unknown'), equals(PdfQualityPreset.medium));
      expect(PdfQualityPreset.fromString(null), equals(PdfQualityPreset.medium));
    });

    test('presets have correct compression quality and max dimensions', () {
      expect(PdfQualityPreset.low.quality, equals(60));
      expect(PdfQualityPreset.low.maxDimension, equals(1200));

      expect(PdfQualityPreset.medium.quality, equals(78));
      expect(PdfQualityPreset.medium.maxDimension, equals(1600));

      expect(PdfQualityPreset.original.quality, equals(92));
      expect(PdfQualityPreset.original.maxDimension, equals(4096));
    });
  });

  group('ScanProjectService Operations', () {
    late Directory tempDir;
    late ScanProjectService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('scan_service_test_');
      service = ScanProjectService(overrideBaseDirectory: tempDir);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reorderPages changes page order correctly and updates PDF', () async {
      final img1 = img.Image(width: 20, height: 20);
      final img2 = img.Image(width: 20, height: 20);
      img.fill(img1, color: img.ColorRgb8(255, 0, 0));
      img.fill(img2, color: img.ColorRgb8(0, 0, 255));

      final f1 = File('${tempDir.path}/p1.jpg')..writeAsBytesSync(img.encodeJpg(img1));
      final f2 = File('${tempDir.path}/p2.jpg')..writeAsBytesSync(img.encodeJpg(img2));

      final created = await service.createProject(
        name: 'Test Project',
        imageFiles: [f1, f2],
      );
      expect(created.pageCount, equals(2));
      final firstPathBefore = created.pagePaths[0];
      final secondPathBefore = created.pagePaths[1];

      // Reorder: Move page 0 to index 1
      final reordered = await service.reorderPages(created.id, 0, 1);
      expect(reordered, isNotNull);
      expect(reordered!.pagePaths[0], equals(secondPathBefore));
      expect(reordered.pagePaths[1], equals(firstPathBefore));
      expect(reordered.originalPagePaths.length, equals(2));
    });

    test('updatePdfQualityPreset updates preset and regenerates PDF', () async {
      final img1 = img.Image(width: 20, height: 20);
      img.fill(img1, color: img.ColorRgb8(100, 200, 100));
      final f1 = File('${tempDir.path}/p1.jpg')..writeAsBytesSync(img.encodeJpg(img1));

      final created = await service.createProject(
        name: 'Quality Doc',
        imageFiles: [f1],
      );
      expect(created.pdfQuality, equals('medium'));

      final updated = await service.updatePdfQualityPreset(created.id, PdfQualityPreset.low);
      expect(updated, isNotNull);
      expect(updated!.pdfQuality, equals('low'));
      expect(File(updated.pdfPath!).existsSync(), isTrue);
    });
  });
}
