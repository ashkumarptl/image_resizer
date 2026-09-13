import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_resizer/core/constants/preset_constants.dart';
import 'package:image_resizer/core/extensions/file_size_extension.dart';
import 'package:image_resizer/core/theme/app_theme.dart';
import 'package:image_resizer/core/theme/theme_provider.dart';
import 'package:image_resizer/data/models/history_item.dart';
import 'package:image_resizer/data/models/image_preset.dart';
import 'package:image_resizer/data/models/process_options.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/data/repositories/history_repository.dart';
import 'package:image_resizer/services/image_service/batch_processor.dart';
import 'package:image_resizer/services/image_service/image_processor.dart';
import 'package:image_resizer/services/image_service/metadata_stripper.dart';
import 'package:image_resizer/services/image_service/name_date_stamper.dart';
import 'package:image_resizer/services/image_service/signature_enhancer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FileSizeExtension Tests', () {
    test('Formats bytes correctly', () {
      expect(0.toReadableFileSize(), '0 B');
      expect(512.toReadableFileSize(), '512 B');
      expect(1024.toReadableFileSize(), '1 KB');
      expect((50 * 1024).toReadableFileSize(), '50 KB');
      expect((2400 * 1024).toReadableFileSize(), '2.3 MB');
    });
  });

  group('PresetConstants Tests', () {
    test('Indian Govt presets are non-empty and valid', () {
      final presets = PresetConstants.indianGovtPresets;
      expect(presets.isNotEmpty, true);
      expect(presets.any((p) => p.id == 'ssc_signature'), true);
      expect(presets.any((p) => p.id == 'cg_vyapam_photo'), true);
      expect(presets.any((p) => p.id == 'upsc_photo'), true);
    });

    test('ImagePreset toJson and fromJson match', () {
      final preset = PresetConstants.indianGovtPresets.first;
      final json = preset.toJson();
      final restored = ImagePreset.fromJson(json);

      expect(restored.id, preset.id);
      expect(restored.name, preset.name);
      expect(restored.targetSizeKB, preset.targetSizeKB);
      expect(restored.category, preset.category);
    });
  });

  group('ProcessResult Tests', () {
    test('Calculates saved percentage accurately', () {
      final result = ProcessResult(
        originalPath: '/test/orig.png',
        outputPath: '/test/out.jpg',
        originalSizeBytes: 1000,
        outputSizeBytes: 200,
        originalWidth: 1000,
        originalHeight: 1000,
        outputWidth: 500,
        outputHeight: 500,
        outputFormat: 'jpg',
        finalQuality: 80,
        processingTime: const Duration(milliseconds: 120),
      );

      expect(result.savedPercentage, 80.0);
      expect(result.isSizeReduced, true);
    });
  });

  group('HistoryItem Serialization Tests', () {
    test('HistoryItem toJson and fromJson match with thumbnailPath', () {
      final item = HistoryItem(
        id: '12345',
        filePath: '/path/to/img.jpg',
        originalPath: '/path/to/orig.png',
        originalSizeBytes: 204800,
        outputSizeBytes: 51200,
        width: 350,
        height: 450,
        format: 'jpg',
        processedAt: DateTime(2026, 9, 1, 12, 0),
        thumbnailPath: '/path/to/thumb_12345.jpg',
      );

      final json = item.toJson();
      final restored = HistoryItem.fromJson(json);

      expect(restored.id, '12345');
      expect(restored.outputSizeBytes, 51200);
      expect(restored.format, 'jpg');
      expect(restored.thumbnailPath, '/path/to/thumb_12345.jpg');
    });

    test('HistoryItem fromJson handles null thumbnailPath gracefully', () {
      final json = {
        'id': 'legacy_1',
        'filePath': '/legacy/path.png',
        'originalPath': '',
        'originalSizeBytes': 1000,
        'outputSizeBytes': 500,
        'width': 100,
        'height': 100,
        'format': 'png',
        'processedAt': DateTime(2026, 1, 1).toIso8601String(),
      };

      final restored = HistoryItem.fromJson(json);
      expect(restored.id, 'legacy_1');
      expect(restored.thumbnailPath, isNull);
    });

    test('HistoryItem copyWith updates fields properly', () {
      final item = HistoryItem(
        id: '1',
        filePath: '/orig.jpg',
        originalPath: '',
        originalSizeBytes: 100,
        outputSizeBytes: 50,
        width: 10,
        height: 10,
        format: 'jpg',
        processedAt: DateTime(2026, 1, 1),
      );

      final updated = item.copyWith(thumbnailPath: '/thumb.jpg');
      expect(updated.thumbnailPath, '/thumb.jpg');
      expect(updated.id, '1');
    });
  });

  group('HistoryRepository Thumbnail Caching Tests', () {
    late Directory tempDir;
    late File sampleImageFile;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('hist_test_');

      // Create a test 300x200 JPEG image
      final imgObj = img.Image(width: 300, height: 200);
      img.fill(imgObj, color: img.ColorRgb8(255, 0, 0));
      sampleImageFile = File('${tempDir.path}/sample.jpg')
        ..writeAsBytesSync(img.encodeJpg(imgObj));
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('generateThumbnail creates a 120x120 cached image', () async {
      final repo = HistoryRepository();
      final thumbPath = await repo.generateThumbnail(
        sampleImageFile.path,
        'item_1',
      );

      expect(thumbPath, isNotNull);
      final thumbFile = File(thumbPath!);
      expect(thumbFile.existsSync(), isTrue);

      final decoded = img.decodeImage(thumbFile.readAsBytesSync())!;
      expect(decoded.width, equals(120));
      expect(decoded.height, equals(120));
    });

    test(
      'addHistoryItem generates and caches thumbnail automatically',
      () async {
        final repo = HistoryRepository();
        final item = HistoryItem(
          id: 'test_auto_thumb',
          filePath: sampleImageFile.path,
          originalPath: sampleImageFile.path,
          originalSizeBytes: sampleImageFile.lengthSync(),
          outputSizeBytes: sampleImageFile.lengthSync(),
          width: 300,
          height: 200,
          format: 'jpg',
          processedAt: DateTime.now(),
        );

        await repo.addHistoryItem(item);
        final history = await repo.getRecentHistory();

        expect(history.length, 1);
        expect(history.first.thumbnailPath, isNotNull);
        expect(File(history.first.thumbnailPath!).existsSync(), isTrue);

        // Verify clearHistory cleans up files
        await repo.clearHistory();
        final afterClear = await repo.getRecentHistory();
        expect(afterClear.isEmpty, isTrue);
      },
    );
  });

  group('ProcessOptions Tests', () {
    test('ProcessOptions copyWith works', () {
      const opts = ProcessOptions(sourcePath: '/test.jpg', quality: 85);
      final updated = opts.copyWith(
        targetSizeKB: 50,
        outputFormat: 'webp',
        strictDimensions: true,
        quarterTurns: 1,
        flipHorizontal: true,
        flipVertical: false,
      );

      expect(updated.sourcePath, '/test.jpg');
      expect(updated.quality, 85);
      expect(updated.targetSizeKB, 50);
      expect(updated.outputFormat, 'webp');
      expect(opts.strictDimensions, false);
      expect(updated.strictDimensions, true);
      expect(opts.quarterTurns, 0);
      expect(updated.quarterTurns, 1);
      expect(opts.flipHorizontal, false);
      expect(updated.flipHorizontal, true);
      expect(updated.flipVertical, false);
      expect(opts.preventSizeIncrease, true);
      final withoutPrevent = opts.copyWith(preventSizeIncrease: false);
      expect(withoutPrevent.preventSizeIncrease, false);
      expect(opts.stripMetadata, true);
      final withoutStrip = opts.copyWith(stripMetadata: false);
      expect(withoutStrip.stripMetadata, false);
    });
  });

  group('MetadataStripper & Privacy Tests', () {
    test('inspectMetadata detects when image has no EXIF', () {
      final imgObj = img.Image(width: 50, height: 50);
      final bytes = Uint8List.fromList(img.encodeJpg(imgObj));
      final info = MetadataStripper.inspectMetadata(bytes);
      expect(info.hasGps, isFalse);
      expect(info.cameraMake, isNull);
      expect(info.hasSensitiveData, isFalse);
    });

    test('stripFromImage removes all EXIF and text metadata', () {
      final imgObj = img.Image(width: 80, height: 80);
      imgObj.exif['ifd0']['Make'] = 'Apple';
      imgObj.exif['ifd0']['Model'] = 'iPhone 15 Pro';
      imgObj.textData = {'Author': 'Sensitive User'};

      expect(imgObj.hasExif, isTrue);
      expect(imgObj.exif.isEmpty, isFalse);
      expect(imgObj.textData?.isNotEmpty, isTrue);

      MetadataStripper.stripFromImage(imgObj);

      expect(imgObj.exif.isEmpty, isTrue);
      expect(imgObj.textData?.isEmpty ?? true, isTrue);

      final cleanBytes = Uint8List.fromList(img.encodeJpg(imgObj));
      final info = MetadataStripper.inspectMetadata(cleanBytes);
      expect(info.hasSensitiveData, isFalse);
      expect(info.cameraMake, isNull);
      expect(info.cameraModel, isNull);
    });

    test('ImageProcessor strips metadata automatically by default', () async {
      final tempDir = Directory.systemTemp.createTempSync('meta_test_');
      try {
        final imgObj = img.Image(width: 100, height: 100);
        imgObj.exif['ifd0']['Make'] = 'Canon';
        imgObj.exif['ifd0']['Model'] = 'EOS 5D';
        final srcFile = File('${tempDir.path}/with_camera_data.jpg')
          ..writeAsBytesSync(img.encodeJpg(imgObj));

        const options = ProcessOptions(
          sourcePath: '',
          stripMetadata: true,
          quality: 80,
        );
        final runOpts = options.copyWith(sourcePath: srcFile.path);

        final result = await ImageProcessor.processImage(runOpts);
        expect(result.metadataStripped, isTrue);

        final outputBytes = File(result.outputPath).readAsBytesSync();
        final info = MetadataStripper.inspectMetadata(outputBytes);
        expect(info.hasSensitiveData, isFalse);
        expect(info.cameraMake, isNull);
        expect(info.cameraModel, isNull);
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('Phase 4 Services & Options Tests', () {
    test('SignatureEnhanceOptions initializes with defaults', () {
      const opts = SignatureEnhanceOptions(sourcePath: '/sig.jpg');
      expect(opts.threshold, 0.65);
      expect(opts.targetSizeKB, 19);
      expect(opts.targetWidth, 400);
    });

    test('PhotoStampOptions initializes with valid parameters', () {
      const opts = PhotoStampOptions(
        sourcePath: '/photo.jpg',
        candidateName: 'ANIL KUMAR',
        dateOfPhoto: '01/09/2026',
      );
      expect(opts.candidateName, 'ANIL KUMAR');
      expect(opts.dateOfPhoto, '01/09/2026');
      expect(opts.targetSizeKB, 48);
    });

    test('BatchProgress calculates percentage correctly', () {
      const prog = BatchProgress(
        completed: 5,
        total: 10,
        currentFileName: 'img_5.jpg',
      );
      expect(prog.percentage, 0.5);
    });
  });

  group('Settings & Theme Tests', () {
    test('ThemeModeNotifier defaults to system and updates mode', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final notifier = ThemeModeNotifier();
      expect(notifier.state, ThemeMode.system);

      await notifier.setThemeMode(ThemeMode.dark);
      expect(notifier.state, ThemeMode.dark);

      await notifier.setThemeMode(ThemeMode.light);
      expect(notifier.state, ThemeMode.light);
    });

    test(
      'AppTheme enforces Material 3 shapes, surface tint, and stadium buttons',
      () {
        final light = AppTheme.lightTheme;
        expect(light.useMaterial3, isTrue);
        expect(light.colorScheme.surfaceTint, isNotNull);

        // Card shape: 20dp
        final cardBorder = light.cardTheme.shape as RoundedRectangleBorder;
        expect(cardBorder.borderRadius, equals(BorderRadius.circular(20)));

        // Dialog shape: 28dp
        final dialogBorder = light.dialogTheme.shape as RoundedRectangleBorder;
        expect(dialogBorder.borderRadius, equals(BorderRadius.circular(28)));

        // Button shapes: StadiumBorder
        expect(
          light.elevatedButtonTheme.style?.shape?.resolve({}),
          isA<StadiumBorder>(),
        );
        expect(
          light.filledButtonTheme.style?.shape?.resolve({}),
          isA<StadiumBorder>(),
        );

        final dark = AppTheme.darkTheme;
        expect(dark.useMaterial3, isTrue);
        expect(dark.colorScheme.surfaceTint, isNotNull);

        final darkCardBorder = dark.cardTheme.shape as RoundedRectangleBorder;
        expect(darkCardBorder.borderRadius, equals(BorderRadius.circular(20)));

        final darkDialogBorder =
            dark.dialogTheme.shape as RoundedRectangleBorder;
        expect(
          darkDialogBorder.borderRadius,
          equals(BorderRadius.circular(28)),
        );
      },
    );
  });
}
