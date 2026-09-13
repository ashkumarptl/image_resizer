import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../image_service/safe_image_decoder.dart';

class ScannedPdfResult {
  final File pdfFile;
  final int pageCount;
  final List<File> pageImages;
  final DateTime scannedAt;

  ScannedPdfResult({
    required this.pdfFile,
    required this.pageCount,
    required this.pageImages,
    required this.scannedAt,
  });

  int get fileSizeBytes => pdfFile.existsSync() ? pdfFile.lengthSync() : 0;
}

enum PdfQualityPreset {
  low('Low (< 1 MB)', 'Compressed for email and job portals', 60, 1200),
  medium('Medium (< 2 MB)', 'Optimal for exams & govt uploads', 78, 1600),
  original(
    'Original (HQ)',
    'Full camera resolution and archival quality',
    92,
    4096,
  );

  final String label;
  final String subtitle;
  final int quality;
  final int maxDimension;

  const PdfQualityPreset(
    this.label,
    this.subtitle,
    this.quality,
    this.maxDimension,
  );

  static PdfQualityPreset fromString(String? val) {
    if (val == 'low') return PdfQualityPreset.low;
    if (val == 'original') return PdfQualityPreset.original;
    return PdfQualityPreset.medium;
  }
}

class _PdfGenerationParams {
  final List<String> imagePaths;
  final int quality;
  final int maxDimension;

  const _PdfGenerationParams({
    required this.imagePaths,
    required this.quality,
    required this.maxDimension,
  });
}

/// Service for CamScanner-like document scanning exclusively using Google ML Kit Document Scanner API.
///
/// Provides live document boundary detection, auto-capture, gallery import within scanner,
/// interactive 4-corner perspective correction, shadow removal, contrast enhancement, and PDF export.
class DocumentScannerService {
  final DocumentScanner Function(DocumentScannerOptions options)?
  scannerFactory;

  DocumentScannerService({this.scannerFactory});

  DocumentScanner _createScanner({
    required int pageLimit,
    ScannerMode mode = ScannerMode.full,
    bool isGalleryImport = true,
    Set<DocumentFormat> formats = const {DocumentFormat.jpeg},
  }) {
    final options = DocumentScannerOptions(
      documentFormats: formats,
      mode: mode,
      isGalleryImport: isGalleryImport,
      pageLimit: pageLimit,
    );

    if (scannerFactory != null) {
      return scannerFactory!(options);
    }
    return DocumentScanner(options: options);
  }

  /// Detects whether an exception was caused by the user voluntarily cancelling the scanner UI.
  bool _isUserCancelled(dynamic error) {
    if (error is PlatformException) {
      final msg = (error.message ?? '').toLowerCase();
      final details = (error.details ?? '').toString().toLowerCase();
      final code = error.code.toLowerCase();
      if (msg.contains('cancel') ||
          details.contains('cancel') ||
          code.contains('cancel')) {
        return true;
      }
    }
    final str = error.toString().toLowerCase();
    return str.contains('cancel');
  }

  /// Whether Google ML Kit Document Scanner is supported on the current platform.
  /// ML Kit Document Scanner requires Android or iOS native Google Play Services.
  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Fallback multi-image picker for platforms without ML Kit (e.g. macOS desktop)
  /// or when the native plugin is unavailable.
  Future<List<File>> _fallbackMultiImagePicker(int pageLimit) async {
    try {
      final picker = ImagePicker();
      final pickedList = await picker.pickMultiImage(limit: pageLimit);
      return pickedList.map((x) => File(x.path)).toList();
    } catch (e) {
      debugPrint('[DocumentScannerService] Fallback multi-picker error: $e');
      return [];
    }
  }

  /// Scans a single document using Google ML Kit Document Scanner.
  ///
  /// Returns the scanned, cropped, and enhanced [File], or `null` if cancelled.
  Future<File?> scanSingleDocument({
    ScannerMode mode = ScannerMode.full,
    bool isGalleryImport = true,
  }) async {
    final images = await scanMultipleDocuments(
      pageLimit: 1,
      mode: mode,
      isGalleryImport: isGalleryImport,
    );
    return images.isNotEmpty ? images.first : null;
  }

  /// Scans multiple documents in batch mode (up to [pageLimit] pages).
  ///
  /// Returns a list of scanned and perspective-corrected [File] objects, or `[]` if cancelled.
  Future<List<File>> scanMultipleDocuments({
    int pageLimit = 25,
    ScannerMode mode = ScannerMode.full,
    bool isGalleryImport = true,
  }) async {
    // If running on desktop (macOS/Windows/Linux) or Web where ML Kit is unsupported,
    // gracefully fall back to the standard file/image picker (unless a mock scanner is injected).
    if (!isSupported && scannerFactory == null) {
      debugPrint(
        '[DocumentScannerService] ML Kit Document Scanner is not supported on ${Platform.operatingSystem}. Falling back to ImagePicker.',
      );
      return _fallbackMultiImagePicker(pageLimit);
    }

    final scanner = _createScanner(
      pageLimit: pageLimit,
      mode: mode,
      isGalleryImport: isGalleryImport,
    );

    try {
      final DocumentScanningResult result = await scanner.scanDocument();

      final filePaths = result.images;
      if (filePaths == null || filePaths.isEmpty) {
        return [];
      }

      final files = <File>[];
      for (final path in filePaths) {
        final file = File(path);
        if (await file.exists()) {
          files.add(file);
        }
      }
      return files;
    } on MissingPluginException catch (e) {
      debugPrint(
        '[DocumentScannerService] MissingPluginException: $e. Falling back to ImagePicker.',
      );
      return _fallbackMultiImagePicker(pageLimit);
    } on PlatformException catch (e) {
      if (_isUserCancelled(e)) {
        debugPrint('[DocumentScannerService] User cancelled document scan');
        return [];
      }
      debugPrint(
        '[DocumentScannerService] PlatformException scanning document: $e. Falling back to ImagePicker.',
      );
      return _fallbackMultiImagePicker(pageLimit);
    } catch (e, stack) {
      if (_isUserCancelled(e)) {
        debugPrint('[DocumentScannerService] User cancelled document scan');
        return [];
      }
      debugPrint(
        '[DocumentScannerService] Error scanning document: $e\n$stack. Falling back to ImagePicker.',
      );
      return _fallbackMultiImagePicker(pageLimit);
    } finally {
      try {
        await scanner.close();
      } catch (_) {}
    }
  }

  /// Scans documents using Google ML Kit Document Scanner and compiles them directly into a PDF.
  ///
  /// Returns a [ScannedPdfResult] with the PDF file, page count, and page images, or `null` if cancelled.
  Future<ScannedPdfResult?> scanToPdf({
    int pageLimit = 50,
    ScannerMode mode = ScannerMode.full,
    bool isGalleryImport = true,
  }) async {
    if (!isSupported && scannerFactory == null) {
      debugPrint(
        '[DocumentScannerService] ML Kit Document Scanner is not supported on ${Platform.operatingSystem}. Falling back to image picker for PDF.',
      );
      final files = await _fallbackMultiImagePicker(pageLimit);
      if (files.isEmpty) return null;
      final pdfFile = await createPdfFromImages(files);
      return ScannedPdfResult(
        pdfFile: pdfFile,
        pageCount: files.length,
        pageImages: files,
        scannedAt: DateTime.now(),
      );
    }

    final scanner = _createScanner(
      pageLimit: pageLimit,
      mode: mode,
      isGalleryImport: isGalleryImport,
      formats: const {DocumentFormat.pdf, DocumentFormat.jpeg},
    );

    try {
      final DocumentScanningResult result = await scanner.scanDocument();

      final filePaths = result.images ?? [];
      final files = <File>[];
      for (final path in filePaths) {
        final file = File(path);
        if (await file.exists()) {
          files.add(file);
        }
      }

      File? pdfFile;
      final pdfUri = result.pdf?.uri;
      if (pdfUri != null && pdfUri.isNotEmpty) {
        final candidate = File(pdfUri);
        if (await candidate.exists()) {
          pdfFile = candidate;
        }
      }

      // If ML Kit returned images but no PDF file (e.g. platform variation or mock), compile images into PDF
      if (pdfFile == null && files.isNotEmpty) {
        pdfFile = await createPdfFromImages(files);
      }

      if (pdfFile == null && files.isEmpty) {
        return null;
      }

      final count = result.pdf?.pageCount ?? files.length;

      return ScannedPdfResult(
        pdfFile: pdfFile ?? files.first,
        pageCount: count > 0 ? count : files.length,
        pageImages: files,
        scannedAt: DateTime.now(),
      );
    } on MissingPluginException catch (e) {
      debugPrint(
        '[DocumentScannerService] MissingPluginException scanning PDF: $e. Falling back to image picker.',
      );
      final files = await _fallbackMultiImagePicker(pageLimit);
      if (files.isEmpty) return null;
      final pdfFile = await createPdfFromImages(files);
      return ScannedPdfResult(
        pdfFile: pdfFile,
        pageCount: files.length,
        pageImages: files,
        scannedAt: DateTime.now(),
      );
    } on PlatformException catch (e) {
      if (_isUserCancelled(e)) {
        debugPrint('[DocumentScannerService] User cancelled PDF scan');
        return null;
      }
      debugPrint('[DocumentScannerService] PlatformException scanning PDF: $e');
      rethrow;
    } catch (e, stack) {
      if (_isUserCancelled(e)) {
        debugPrint('[DocumentScannerService] User cancelled PDF scan');
        return null;
      }
      debugPrint('[DocumentScannerService] Error scanning PDF: $e\n$stack');
      rethrow;
    } finally {
      try {
        await scanner.close();
      } catch (_) {}
    }
  }

  /// Converts a list of image files into a clean, standard multi-page PDF document.
  static Future<File> createPdfFromImages(
    List<File> imageFiles, {
    String? outputFileName,
    PdfQualityPreset qualityPreset = PdfQualityPreset.medium,
  }) async {
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (_) {
      tempDir = Directory.systemTemp;
    }
    final name =
        outputFileName ??
        'doc_scan_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final pdfFile = File('${tempDir.path}/$name');

    final params = _PdfGenerationParams(
      imagePaths: imageFiles.map((f) => f.path).toList(),
      quality: qualityPreset.quality,
      maxDimension: qualityPreset.maxDimension,
    );
    final pdfBytes = await compute(_generatePdfBytesFromParams, params);
    await pdfFile.writeAsBytes(pdfBytes, flush: true);
    return pdfFile;
  }

  /// Internal worker to generate PDF binary representation from image paths and compression parameters.
  static List<int> _generatePdfBytesFromParams(_PdfGenerationParams params) {
    final imagePaths = params.imagePaths;
    final quality = params.quality;
    final maxDim = params.maxDimension;
    final buffer = BytesBuilder();
    // PDF 1.4 Header with binary comment
    buffer.add(utf8.encode('%PDF-1.4\n%\xE2\xE3\xCF\xD3\n'));

    final offsets = <int>[];
    int currentOffset = buffer.length;

    void addObj(String dict, [List<int>? streamBytes]) {
      offsets.add(currentOffset);
      final header = '${offsets.length} 0 obj\n$dict\n';
      final headerBytes = utf8.encode(header);
      buffer.add(headerBytes);
      currentOffset += headerBytes.length;

      if (streamBytes != null) {
        final sHeader = utf8.encode('stream\n');
        buffer.add(sHeader);
        currentOffset += sHeader.length;

        buffer.add(streamBytes);
        currentOffset += streamBytes.length;

        final sFooter = utf8.encode('\nendstream\n');
        buffer.add(sFooter);
        currentOffset += sFooter.length;
      }

      final footer = utf8.encode('endobj\n');
      buffer.add(footer);
      currentOffset += footer.length;
    }

    final n = imagePaths.length;
    // Obj 1: Catalog
    // Obj 2: Pages
    // For page i (0-indexed):
    //   Image XObject: Obj (3 + i*3)
    //   Content stream: Obj (4 + i*3)
    //   Page object: Obj (5 + i*3)

    // Placeholder offsets for Catalog and Pages, we add them first
    // 1: Catalog
    addObj('<< /Type /Catalog /Pages 2 0 R >>');

    // 2: Pages - kids are Obj (5 + i*3)
    final kidsStr = List.generate(n, (i) => '${5 + i * 3} 0 R').join(' ');
    addObj('<< /Type /Pages /Kids [ $kidsStr ] /Count $n >>');

    for (int i = 0; i < n; i++) {
      final file = File(imagePaths[i]);
      List<int> rawBytes = file.existsSync() ? file.readAsBytesSync() : [];
      if (rawBytes.isEmpty) continue;
      int width = 800;
      int height = 1100;

      final uint8 = Uint8List.fromList(rawBytes);
      final isJpeg =
          rawBytes.length >= 2 && rawBytes[0] == 0xFF && rawBytes[1] == 0xD8;
      final header = SafeImageDecoder.readHeaderDimensions(uint8);

      // Fast path: if already a valid JPEG, fits within maxDimension, and quality is original/high preset,
      // bypass slow pure-Dart decode/encode cycle and embed directly into PDF stream
      if (isJpeg &&
          header != null &&
          header.width <= maxDim &&
          header.height <= maxDim &&
          quality >= 90) {
        width = header.width;
        height = header.height;
      } else {
        // Ensure image is JPEG format for /DCTDecode with preset downsampling
        final decoded = img.decodeImage(uint8);
        if (decoded != null) {
          img.Image proc = decoded;
          if (proc.width > maxDim || proc.height > maxDim) {
            if (proc.width >= proc.height) {
              proc = img.copyResize(proc, width: maxDim);
            } else {
              proc = img.copyResize(proc, height: maxDim);
            }
          }
          width = proc.width;
          height = proc.height;
          // Always encode to valid JPEG stream with target quality
          rawBytes = img.encodeJpg(proc, quality: quality);
        } else if (header != null) {
          width = header.width;
          height = header.height;
        }
      }

      final imgObjNum = 3 + i * 3;
      final contentObjNum = 4 + i * 3;

      // Image XObject
      addObj(
        '<<\n'
        '/Type /XObject\n'
        '/Subtype /Image\n'
        '/Width $width\n'
        '/Height $height\n'
        '/ColorSpace /DeviceRGB\n'
        '/BitsPerComponent 8\n'
        '/Filter /DCTDecode\n'
        '/Length ${rawBytes.length}\n'
        '>>',
        rawBytes,
      );

      // Page dimensions matching standard points (using 72 DPI ratio or image pt)
      final pw = width.toDouble();
      final ph = height.toDouble();

      // Content stream
      final content = 'q $pw 0 0 $ph 0 0 cm /Im$i Do Q';
      final contentBytes = utf8.encode(content);
      addObj('<< /Length ${contentBytes.length} >>', contentBytes);

      // Page object
      addObj(
        '<<\n'
        '/Type /Page\n'
        '/Parent 2 0 R\n'
        '/MediaBox [0 0 $pw $ph]\n'
        '/Resources << /XObject << /Im$i $imgObjNum 0 R >> /ProcSet [/PDF /ImageC] >>\n'
        '/Contents $contentObjNum 0 R\n'
        '>>',
      );
    }

    final xrefOffset = currentOffset;
    final totalObjs = offsets.length + 1;
    final xrefHeader = utf8.encode('xref\n0 $totalObjs\n0000000000 65535 f \n');
    buffer.add(xrefHeader);

    for (final offset in offsets) {
      final offStr = offset.toString().padLeft(10, '0');
      buffer.add(utf8.encode('$offStr 00000 n \n'));
    }

    final trailer =
        'trailer\n'
        '<< /Size $totalObjs /Root 1 0 R >>\n'
        'startxref\n'
        '$xrefOffset\n'
        '%%EOF\n';
    buffer.add(utf8.encode(trailer));

    return buffer.toBytes();
  }

  /// Legacy alias to preserve compatibility while strictly using ML Kit Document Scanner.
  Future<File?> scanWithFallback({bool fallbackToCamera = false}) async {
    return scanSingleDocument();
  }
}
