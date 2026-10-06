import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_resizer/presentation/signature/signature_cropper_helper.dart';

class MockImageCropper extends ImageCropper {
  final CroppedFile? returnFile;
  bool cropImageCalled = false;
  String? lastSourcePath;

  MockImageCropper({this.returnFile});

  @override
  Future<CroppedFile?> cropImage({
    required String sourcePath,
    int? maxWidth,
    int? maxHeight,
    CropAspectRatio? aspectRatio,
    List<CropAspectRatioPreset> aspectRatioPresets = const [
      CropAspectRatioPreset.original,
      CropAspectRatioPreset.square,
      CropAspectRatioPreset.ratio3x2,
      CropAspectRatioPreset.ratio4x3,
      CropAspectRatioPreset.ratio16x9,
    ],
    CropStyle cropStyle = CropStyle.rectangle,
    ImageCompressFormat compressFormat = ImageCompressFormat.jpg,
    int compressQuality = 90,
    List<PlatformUiSettings>? uiSettings,
  }) async {
    cropImageCalled = true;
    lastSourcePath = sourcePath;
    return returnFile;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File testFile;
  late File croppedFile;

  setUp(() {
    testFile = File('${Directory.systemTemp.path}/test_sig_raw.jpg');
    testFile.writeAsBytesSync([1, 2, 3, 4]);

    croppedFile = File('${Directory.systemTemp.path}/test_sig_cropped.jpg');
    croppedFile.writeAsBytesSync([5, 6, 7, 8]);
  });

  tearDown(() {
    if (testFile.existsSync()) testFile.deleteSync();
    if (croppedFile.existsSync()) croppedFile.deleteSync();
  });

  test(
    'SignatureCropperHelper returns cropped file when user confirms crop',
    () async {
      final mockCropper = MockImageCropper(
        returnFile: CroppedFile(croppedFile.path),
      );
      final result = await SignatureCropperHelper.cropSignature(
        testFile,
        cropperOverride: mockCropper,
      );

      expect(mockCropper.cropImageCalled, isTrue);
      expect(mockCropper.lastSourcePath, equals(testFile.path));
      expect(result, isNotNull);
      expect(result!.path, equals(croppedFile.path));
    },
  );

  test('SignatureCropperHelper returns null when user cancels crop', () async {
    final mockCropper = MockImageCropper(returnFile: null);
    final result = await SignatureCropperHelper.cropSignature(
      testFile,
      cropperOverride: mockCropper,
    );

    expect(mockCropper.cropImageCalled, isTrue);
    expect(result, isNull);
  });
}
