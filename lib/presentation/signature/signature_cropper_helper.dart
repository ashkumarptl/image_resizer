import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../core/constants/app_colors.dart';
import '../../services/image_service/heic_converter.dart';

/// Helper to provide a standard crop experience for isolating signature areas.
class SignatureCropperHelper {
  SignatureCropperHelper._();

  /// Launches standard crop editor to let user select desired signature area.
  /// Converts HEIC if necessary and configures free-form & standard aspect ratios.
  /// Returns the cropped [File] if confirmed, or `null` if cancelled.
  static Future<File?> cropSignature(
    File sourceFile, {
    ImageCropper? cropperOverride,
  }) async {
    try {
      String sourcePath = sourceFile.path;
      if (HeicConverter.isHeicFile(sourcePath)) {
        sourcePath = await HeicConverter.ensureCompatibleImage(sourcePath);
      }

      final cropper = cropperOverride ?? ImageCropper();
      final cropped = await cropper.cropImage(
        sourcePath: sourcePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Signature Area',
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Signature Area',
            aspectRatioLockEnabled: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.ratio3x2,
              CropAspectRatioPreset.ratio4x3,
              CropAspectRatioPreset.ratio16x9,
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (cropped != null) {
        return File(cropped.path);
      }
    } catch (e) {
      debugPrint('[SignatureCropperHelper] Crop error: $e');
    }
    return null;
  }
}
