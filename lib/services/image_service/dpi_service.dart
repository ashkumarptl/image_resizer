import 'dart:math' as math;
import 'dart:typed_data';

/// Provides fast, lossless DPI (Dots Per Inch) inspection, metadata injection,
/// and physical print size conversion for JPEG and PNG images.
class DpiService {
  DpiService._();

  /// Default screen resolution DPI when none is specified in metadata
  static const int defaultDpi = 72;

  /// Standard presets widely used across Indian Govt exam portals and passport standards
  static const List<int> standardDpiPresets = [72, 150, 200, 300, 600];

  /// Reads current DPI from [bytes].
  /// Returns null if format is unsupported or density units are unspecified.
  static int? readDpi(Uint8List bytes) {
    if (bytes.length < 4) return null;

    // 1. JPEG Detection (0xFF 0xD8)
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return _readJpegDpi(bytes);
    }

    // 2. PNG Detection (137 80 78 71 13 10 26 10)
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return _readPngDpi(bytes);
    }

    return null;
  }

  /// Losslessly sets the DPI metadata in [bytes] to [targetDpi].
  /// Does NOT re-encode or compress image pixels, guaranteeing 0% quality loss.
  static Uint8List setDpi(Uint8List bytes, int targetDpi, {String? format}) {
    if (targetDpi <= 0 || bytes.length < 4) return bytes;

    final fmt = format?.toLowerCase();

    // Check JPEG
    if (fmt == 'jpg' ||
        fmt == 'jpeg' ||
        (bytes[0] == 0xFF && bytes[1] == 0xD8)) {
      return _setJpegDpi(bytes, targetDpi);
    }

    // Check PNG
    if (fmt == 'png' ||
        (bytes.length > 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47)) {
      return _setPngDpi(bytes, targetDpi);
    }

    return bytes;
  }

  /// Calculates exact pixel dimensions from physical print size based on target DPI.
  /// Supported units: 'cm', 'mm', 'inch'.
  static ({int width, int height}) calculatePixelsFromPhysicalSize({
    required double width,
    required double height,
    required String unit,
    required int dpi,
  }) {
    double factor;
    switch (unit.toLowerCase()) {
      case 'cm':
        factor = dpi / 2.54;
        break;
      case 'mm':
        factor = dpi / 25.4;
        break;
      case 'inch':
      case 'in':
        factor = dpi.toDouble();
        break;
      default:
        factor = dpi / 2.54;
    }

    final int pxW = math.max(1, (width * factor).round());
    final int pxH = math.max(1, (height * factor).round());
    return (width: pxW, height: pxH);
  }

  // ==========================================
  // JPEG JFIF DPI Implementation
  // ==========================================

  static int? _readJpegDpi(Uint8List bytes) {
    int offset = 2;
    final len = bytes.length;

    while (offset < len - 4) {
      if (bytes[offset] != 0xFF) {
        offset++;
        continue;
      }

      final marker = bytes[offset + 1];

      // Stop on Start of Scan (SOS) or Image End (EOI)
      if (marker == 0xDA || marker == 0xD9) break;

      // Variable length marker
      if (offset + 3 >= len) break;
      final markerLength = (bytes[offset + 2] << 8) | bytes[offset + 3];

      // Check for APP0 (0xFF 0xE0) - JFIF
      if (marker == 0xE0 && markerLength >= 16 && offset + 18 <= len) {
        // Verify 'JFIF\0' signature
        if (bytes[offset + 4] == 0x4A &&
            bytes[offset + 5] == 0x46 &&
            bytes[offset + 6] == 0x49 &&
            bytes[offset + 7] == 0x46 &&
            bytes[offset + 8] == 0x00) {
          final units = bytes[offset + 11];
          final xDensity = (bytes[offset + 12] << 8) | bytes[offset + 13];

          if (units == 1 && xDensity > 0) {
            return xDensity; // Dots per inch
          } else if (units == 2 && xDensity > 0) {
            return (xDensity * 2.54).round(); // Dots per cm to DPI
          }
        }
      }

      offset += 2 + markerLength;
    }

    return null;
  }

  static Uint8List _setJpegDpi(Uint8List bytes, int dpi) {
    // Check for existing APP0 JFIF marker right after SOI (0xFF 0xD8)
    if (bytes.length > 20 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF &&
        bytes[3] == 0xE0) {
      // Check if it's JFIF
      if (bytes[6] == 0x4A &&
          bytes[7] == 0x46 &&
          bytes[8] == 0x49 &&
          bytes[9] == 0x46 &&
          bytes[10] == 0x00) {
        // Fast in-place patch
        final result = Uint8List.fromList(bytes);
        result[13] = 1; // 1 = Dots per inch
        result[14] = (dpi >> 8) & 0xFF; // Xdensity high
        result[15] = dpi & 0xFF; // Xdensity low
        result[16] = (dpi >> 8) & 0xFF; // Ydensity high
        result[17] = dpi & 0xFF; // Ydensity low
        return result;
      }
    }

    // If no APP0 JFIF exists or it's further down, inject an 18-byte JFIF APP0 header
    final jfifHeader = Uint8List(18);
    jfifHeader[0] = 0xFF;
    jfifHeader[1] = 0xE0; // APP0
    jfifHeader[2] = 0x00;
    jfifHeader[3] = 0x10; // Length = 16
    jfifHeader[4] = 0x4A; // 'J'
    jfifHeader[5] = 0x46; // 'F'
    jfifHeader[6] = 0x49; // 'I'
    jfifHeader[7] = 0x46; // 'F'
    jfifHeader[8] = 0x00; // '\0'
    jfifHeader[9] = 0x01; // Version Major 1
    jfifHeader[10] = 0x01; // Version Minor 1
    jfifHeader[11] = 0x01; // Units: 1 = Dots per inch
    jfifHeader[12] = (dpi >> 8) & 0xFF;
    jfifHeader[13] = dpi & 0xFF;
    jfifHeader[14] = (dpi >> 8) & 0xFF;
    jfifHeader[15] = dpi & 0xFF;
    jfifHeader[16] = 0x00; // Thumbnail width
    jfifHeader[17] = 0x00; // Thumbnail height

    // Build output: [0xFF, 0xD8] + [jfifHeader] + [rest of JPEG]
    final builder = BytesBuilder(copy: false);
    builder.add(bytes.sublist(0, 2)); // SOI
    builder.add(jfifHeader);
    builder.add(bytes.sublist(2));
    return builder.takeBytes();
  }

  // ==========================================
  // PNG pHYs Chunk DPI Implementation
  // ==========================================

  static int? _readPngDpi(Uint8List bytes) {
    int offset = 8; // Skip 8-byte PNG signature
    final len = bytes.length;

    while (offset + 8 <= len) {
      final chunkLength = _readUint32BigEndian(bytes, offset);
      final chunkType = String.fromCharCodes(
        bytes.sublist(offset + 4, offset + 8),
      );

      if (chunkType == 'pHYs' && chunkLength >= 9 && offset + 8 + 9 <= len) {
        final dataOffset = offset + 8;
        final xPixelsPerMeter = _readUint32BigEndian(bytes, dataOffset);
        final unitSpecifier = bytes[dataOffset + 8];

        if (unitSpecifier == 1 && xPixelsPerMeter > 0) {
          // 1 meter = 0.0254 inches
          return (xPixelsPerMeter * 0.0254).round();
        }
      }

      if (chunkType == 'IEND') break;

      // 4 bytes length + 4 bytes type + data + 4 bytes CRC
      offset += 12 + chunkLength;
    }

    return null;
  }

  static Uint8List _setPngDpi(Uint8List bytes, int dpi) {
    if (bytes.length < 33) return bytes;

    // Convert DPI to pixels per meter (1 inch = 0.0254 m)
    final ppm = (dpi / 0.0254).round();

    // Prepare 9-byte pHYs chunk data
    final physData = Uint8List(9);
    _writeUint32BigEndian(physData, 0, ppm); // X pixels per meter
    _writeUint32BigEndian(physData, 4, ppm); // Y pixels per meter
    physData[8] = 1; // 1 = meter

    // Chunk type ASCII bytes: 'pHYs'
    final physType = Uint8List.fromList([0x70, 0x48, 0x59, 0x73]);

    // Calculate CRC32 of Type + Data
    final crcBytes = Uint8List(4 + 9);
    crcBytes.setRange(0, 4, physType);
    crcBytes.setRange(4, 13, physData);
    final crc = _crc32(crcBytes);

    // Full pHYs chunk = 4 bytes length (9) + 4 bytes 'pHYs' + 9 bytes data + 4 bytes CRC = 21 bytes
    final fullPhysChunk = Uint8List(21);
    _writeUint32BigEndian(fullPhysChunk, 0, 9);
    fullPhysChunk.setRange(4, 8, physType);
    fullPhysChunk.setRange(8, 17, physData);
    _writeUint32BigEndian(fullPhysChunk, 17, crc);

    // Check if a pHYs chunk already exists
    int offset = 8;
    int? existingPhysOffset;
    int? existingPhysLength;
    final len = bytes.length;

    while (offset + 8 <= len) {
      final chunkLen = _readUint32BigEndian(bytes, offset);
      final chunkType = String.fromCharCodes(
        bytes.sublist(offset + 4, offset + 8),
      );

      if (chunkType == 'pHYs') {
        existingPhysOffset = offset;
        existingPhysLength = 12 + chunkLen;
        break;
      }
      if (chunkType == 'IEND' || chunkType == 'IDAT') break;
      offset += 12 + chunkLen;
    }

    final builder = BytesBuilder(copy: false);

    if (existingPhysOffset != null && existingPhysLength != null) {
      // Replace existing pHYs chunk
      builder.add(bytes.sublist(0, existingPhysOffset));
      builder.add(fullPhysChunk);
      builder.add(bytes.sublist(existingPhysOffset + existingPhysLength));
    } else {
      // Insert right after IHDR chunk (Offset 33 = 8 sig + 4 len + 4 type + 13 data + 4 crc)
      final ihdrEnd = 33;
      if (bytes.length >= ihdrEnd) {
        builder.add(bytes.sublist(0, ihdrEnd));
        builder.add(fullPhysChunk);
        builder.add(bytes.sublist(ihdrEnd));
      } else {
        return bytes;
      }
    }

    return builder.takeBytes();
  }

  // ==========================================
  // Binary & CRC32 Utilities
  // ==========================================

  static int _readUint32BigEndian(Uint8List bytes, int offset) {
    return (bytes[offset] << 24) |
        (bytes[offset + 1] << 16) |
        (bytes[offset + 2] << 8) |
        bytes[offset + 3];
  }

  static void _writeUint32BigEndian(Uint8List bytes, int offset, int value) {
    bytes[offset] = (value >> 24) & 0xFF;
    bytes[offset + 1] = (value >> 16) & 0xFF;
    bytes[offset + 2] = (value >> 8) & 0xFF;
    bytes[offset + 3] = value & 0xFF;
  }

  /// IEEE 802.3 standard CRC32 calculation required for PNG chunks
  static int _crc32(Uint8List data) {
    int crc = 0xFFFFFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= data[i];
      for (int j = 0; j < 8; j++) {
        if ((crc & 1) != 0) {
          crc = (crc >>> 1) ^ 0xEDB88320;
        } else {
          crc = crc >>> 1;
        }
      }
    }
    return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
  }
}
