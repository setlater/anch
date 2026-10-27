import 'dart:typed_data';

class ImagePixelSize {
  const ImagePixelSize({required this.width, required this.height});

  final int width;
  final int height;

  int get longSide => width > height ? width : height;
}

/// 仅解析常见图片文件头的像素尺寸，不提前完整解码大图。
abstract final class ImageDimensionReader {
  static ImagePixelSize? read(Uint8List bytes) =>
      _readPng(bytes) ?? _readJpeg(bytes) ?? _readWebp(bytes);

  static ImagePixelSize? _readPng(Uint8List bytes) {
    const signature = <int>[137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length < 24 ||
        !List.generate(
          signature.length,
          (index) => index,
        ).every((index) => bytes[index] == signature[index])) {
      return null;
    }
    return _validSize(
      _readUint32BigEndian(bytes, 16),
      _readUint32BigEndian(bytes, 20),
    );
  }

  static ImagePixelSize? _readJpeg(Uint8List bytes) {
    if (bytes.length < 4 || bytes[0] != 0xff || bytes[1] != 0xd8) {
      return null;
    }
    var offset = 2;
    while (offset + 8 < bytes.length) {
      if (bytes[offset] != 0xff) {
        offset++;
        continue;
      }
      while (offset < bytes.length && bytes[offset] == 0xff) {
        offset++;
      }
      if (offset >= bytes.length) return null;
      final marker = bytes[offset++];
      if (marker == 0xd8 || marker == 0xd9 || marker == 0x01) continue;
      if (offset + 1 >= bytes.length) return null;
      final segmentLength = _readUint16BigEndian(bytes, offset);
      if (segmentLength < 2 || offset + segmentLength > bytes.length) {
        return null;
      }
      if (_isStartOfFrame(marker) && segmentLength >= 7) {
        return _validSize(
          _readUint16BigEndian(bytes, offset + 5),
          _readUint16BigEndian(bytes, offset + 3),
        );
      }
      offset += segmentLength;
    }
    return null;
  }

  static ImagePixelSize? _readWebp(Uint8List bytes) {
    if (bytes.length < 30 ||
        !_matchesAscii(bytes, 0, 'RIFF') ||
        !_matchesAscii(bytes, 8, 'WEBP')) {
      return null;
    }
    if (_matchesAscii(bytes, 12, 'VP8X')) {
      return _validSize(
        1 + _readUint24LittleEndian(bytes, 24),
        1 + _readUint24LittleEndian(bytes, 27),
      );
    }
    if (_matchesAscii(bytes, 12, 'VP8 ')) {
      if (bytes[23] != 0x9d || bytes[24] != 0x01 || bytes[25] != 0x2a) {
        return null;
      }
      return _validSize(
        _readUint16LittleEndian(bytes, 26) & 0x3fff,
        _readUint16LittleEndian(bytes, 28) & 0x3fff,
      );
    }
    if (_matchesAscii(bytes, 12, 'VP8L')) {
      if (bytes[20] != 0x2f) return null;
      final bits =
          bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
      return _validSize((bits & 0x3fff) + 1, ((bits >> 14) & 0x3fff) + 1);
    }
    return null;
  }

  static bool _isStartOfFrame(int marker) =>
      (marker >= 0xc0 && marker <= 0xc3) ||
      (marker >= 0xc5 && marker <= 0xc7) ||
      (marker >= 0xc9 && marker <= 0xcb) ||
      (marker >= 0xcd && marker <= 0xcf);

  static bool _matchesAscii(Uint8List bytes, int offset, String value) {
    if (offset + value.length > bytes.length) return false;
    for (var index = 0; index < value.length; index++) {
      if (bytes[offset + index] != value.codeUnitAt(index)) return false;
    }
    return true;
  }

  static int _readUint16BigEndian(Uint8List bytes, int offset) =>
      (bytes[offset] << 8) | bytes[offset + 1];

  static int _readUint16LittleEndian(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8);

  static int _readUint24LittleEndian(Uint8List bytes, int offset) =>
      bytes[offset] | (bytes[offset + 1] << 8) | (bytes[offset + 2] << 16);

  static int _readUint32BigEndian(Uint8List bytes, int offset) =>
      (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];

  static ImagePixelSize? _validSize(int width, int height) {
    if (width <= 0 || height <= 0) return null;
    return ImagePixelSize(width: width, height: height);
  }
}
