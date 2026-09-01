import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_resizer/core/constants/preset_constants.dart';
import 'package:image_resizer/core/extensions/file_size_extension.dart';
import 'package:image_resizer/core/theme/theme_provider.dart';
import 'package:image_resizer/data/models/history_item.dart';
import 'package:image_resizer/data/models/image_preset.dart';
import 'package:image_resizer/data/models/process_options.dart';
import 'package:image_resizer/data/models/process_result.dart';
import 'package:image_resizer/services/image_service/batch_processor.dart';
import 'package:image_resizer/services/image_service/name_date_stamper.dart';
import 'package:image_resizer/services/image_service/signature_enhancer.dart';

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
      expect(presets.any((p) => p.id == 'ssc_photo'), true);
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
    test('HistoryItem toJson and fromJson match', () {
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
      );

      final json = item.toJson();
      final restored = HistoryItem.fromJson(json);

      expect(restored.id, '12345');
      expect(restored.outputSizeBytes, 51200);
      expect(restored.format, 'jpg');
    });
  });

  group('ProcessOptions Tests', () {
    test('ProcessOptions copyWith works', () {
      const opts = ProcessOptions(sourcePath: '/test.jpg', quality: 85);
      final updated = opts.copyWith(targetSizeKB: 50, outputFormat: 'webp');

      expect(updated.sourcePath, '/test.jpg');
      expect(updated.quality, 85);
      expect(updated.targetSizeKB, 50);
      expect(updated.outputFormat, 'webp');
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
  });
}
