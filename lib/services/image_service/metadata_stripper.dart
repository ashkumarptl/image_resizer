import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Metadata summary representing sensitive EXIF and location tags
class ImageMetadataInfo {
  final bool hasExif;
  final bool hasGps;
  final String? cameraMake;
  final String? cameraModel;
  final String? software;
  final String? dateTime;
  final double? latitude;
  final double? longitude;

  const ImageMetadataInfo({
    this.hasExif = false,
    this.hasGps = false,
    this.cameraMake,
    this.cameraModel,
    this.software,
    this.dateTime,
    this.latitude,
    this.longitude,
  });

  /// True if image contains either GPS coordinates or identifiable camera/device tags
  bool get hasSensitiveData =>
      hasGps ||
      cameraMake != null ||
      cameraModel != null ||
      latitude != null ||
      longitude != null;

  @override
  String toString() {
    return 'ImageMetadataInfo(hasExif: $hasExif, hasGps: $hasGps, make: $cameraMake, model: $cameraModel)';
  }
}

/// Helper service to detect and strip GPS, camera, and device metadata from images.
class MetadataStripper {
  MetadataStripper._();

  /// Inspects image bytes to detect EXIF, camera, and GPS location tags
  static ImageMetadataInfo inspectMetadata(Uint8List bytes) {
    try {
      img.ExifData? exif;
      try {
        exif = img.ExifData.fromInputBuffer(img.InputBuffer(bytes));
      } catch (_) {
        // Fallback: decode basic header if possible
        final decoded = img.decodeImage(bytes);
        if (decoded != null && decoded.hasExif) {
          exif = decoded.exif;
        }
      }

      if (exif == null || exif.isEmpty) {
        return const ImageMetadataInfo();
      }

      String? make;
      String? model;
      String? software;
      String? dateTime;
      bool hasGps = false;
      double? lat;
      double? lon;

      // Check IFD0 (Camera/Device tags)
      if (exif.directories.containsKey('ifd0')) {
        final ifd0 = exif['ifd0'];
        make = ifd0[0x010f]?.toString(); // Make
        model = ifd0[0x0110]?.toString(); // Model
        software = ifd0[0x0131]?.toString(); // Software
        dateTime = ifd0[0x0132]?.toString(); // DateTime

        // Check GPS sub-directory
        if (ifd0.sub.containsKey('gps')) {
          final gps = ifd0.sub['gps'];
          if (!gps.isEmpty) {
            hasGps = true;
          }
        }
      }

      // Also check top-level GPS tag or directories
      if (!hasGps) {
        hasGps =
            exif.hasTag(0x8825) ||
            exif.directories.containsKey('gps') ||
            (exif.hasTag(0x0001) && exif.hasTag(0x0002));
      }

      return ImageMetadataInfo(
        hasExif: true,
        hasGps: hasGps,
        cameraMake: make?.trim(),
        cameraModel: model?.trim(),
        software: software?.trim(),
        dateTime: dateTime?.trim(),
        latitude: lat,
        longitude: lon,
      );
    } catch (_) {
      return const ImageMetadataInfo();
    }
  }

  /// Strips all EXIF, GPS, camera hardware identifiers, and text data from an in-memory image
  static void stripFromImage(img.Image image) {
    if (image.hasExif) {
      image.exif.clear();
      image.exif.thumbnailData = null;
    }
    image.textData?.clear();
  }

  /// Convenience utility to scrub metadata from an existing file and write out a sanitized copy
  static Future<File> stripFileMetadata(
    File inputFile, {
    String? outputPath,
  }) async {
    final bytes = await inputFile.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception('Failed to decode image for metadata stripping');
    }

    stripFromImage(image);

    String outPath = outputPath ?? '';
    if (outPath.isEmpty) {
      String basePath;
      try {
        final tempDir = await getTemporaryDirectory();
        basePath = tempDir.path;
      } catch (_) {
        basePath = Directory.systemTemp.path;
      }
      final filename = p.basenameWithoutExtension(inputFile.path);
      final ext = p.extension(inputFile.path).toLowerCase();
      outPath = p.join(
        basePath,
        '${filename}_clean_${DateTime.now().millisecondsSinceEpoch}$ext',
      );
    }

    final ext = p.extension(outPath).toLowerCase();
    Uint8List cleanBytes;
    if (ext == '.png') {
      cleanBytes = Uint8List.fromList(img.encodePng(image));
    } else if (ext == '.webp') {
      cleanBytes = Uint8List.fromList(img.encodeWebP(image));
    } else {
      cleanBytes = Uint8List.fromList(img.encodeJpg(image, quality: 90));
    }

    final outFile = File(outPath);
    await outFile.parent.create(recursive: true);
    await outFile.writeAsBytes(cleanBytes);
    return outFile;
  }
}
