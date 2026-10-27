@Tags(['security'])
library;

import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/attachment/image_dimension_reader.dart';
import 'package:anch/features/item_detail/image_preview_payload_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const attachment = AttachmentModel(
    id: 'fictional-image',
    itemId: 'fictional-item',
    attachmentRole: 'proof',
    fileName: 'fictional-image.enc',
    mimeType: 'image/jpeg',
    plainSize: 1,
    encryptedSize: 29,
    sortOrder: 0,
    status: 'active',
    createdAt: 1,
    updatedAt: 1,
  );

  test('大图首次生成加密预览，后续直接使用缓存', () async {
    Uint8List? storedPreview;
    var originalReadCount = 0;
    var encodeCount = 0;
    final loader = ImagePreviewPayloadLoader(
      readOriginal: (_) async {
        originalReadCount++;
        return _jpegHeader(width: 4032, height: 3024);
      },
      readCachedPreview: (_) async => storedPreview,
      writeCachedPreview: (_, preview) async {
        storedPreview = Uint8List.fromList(preview);
      },
      saveThumbnail: (_, _) async {},
      encodePreview: (_, size, _) async {
        encodeCount++;
        expect(size.width, 4032);
        expect(size.height, 3024);
        return Uint8List.fromList(<int>[7, 8, 9]);
      },
    );

    final first = await loader.load(attachment, forceOriginal: false);
    final second = await loader.load(attachment, forceOriginal: false);

    expect(first.usesPreview, isTrue);
    expect(first.bytes, <int>[7, 8, 9]);
    expect(second.usesPreview, isTrue);
    expect(second.bytes, <int>[7, 8, 9]);
    expect(originalReadCount, 1);
    expect(encodeCount, 1);
  });

  test('预览失效后新会话重新生成缓存，原图保持可读', () async {
    Uint8List? storedPreview = Uint8List.fromList([1, 2, 3]);
    final original = _jpegHeader(width: 4032, height: 3024);
    var readCount = 0;
    var invalidations = 0;
    ImagePreviewPayloadLoader newSession() => ImagePreviewPayloadLoader(
      readOriginal: (_) async {
        readCount++;
        return Uint8List.fromList(original);
      },
      readCachedPreview: (_) async =>
          storedPreview == null ? null : Uint8List.fromList(storedPreview!),
      invalidateCachedPreview: (_) async {
        invalidations++;
        storedPreview = null;
      },
      writeCachedPreview: (_, bytes) async =>
          storedPreview = Uint8List.fromList(bytes),
      encodePreview: (_, _, _) async => Uint8List.fromList([7, 8, 9]),
      saveThumbnail: (_, _) async {},
    );
    final failed = await newSession().load(attachment, forceOriginal: false);
    expect(failed.invalidatePreview, isNotNull);
    await failed.invalidatePreview!();
    failed.bytes.fillRange(0, failed.bytes.length, 0);
    final rebuilt = await newSession().load(attachment, forceOriginal: false);
    final reopened = await newSession().load(attachment, forceOriginal: false);
    expect(invalidations, 1);
    expect(readCount, 1);
    expect(rebuilt.bytes, [7, 8, 9]);
    expect(reopened.bytes, [7, 8, 9]);
    expect(original, _jpegHeader(width: 4032, height: 3024));
  });

  test('小图和预览生成失败均直接回退原图', () async {
    var smallEncodeCount = 0;
    final smallSource = _pngHeader(width: 2560, height: 1440);
    final smallLoader = ImagePreviewPayloadLoader(
      readOriginal: (_) async => Uint8List.fromList(smallSource),
      readCachedPreview: (_) async => null,
      writeCachedPreview: (_, _) async {},
      saveThumbnail: (_, _) async {},
      encodePreview: (_, _, _) async {
        smallEncodeCount++;
        return Uint8List(0);
      },
    );
    final small = await smallLoader.load(attachment, forceOriginal: false);
    expect(small.usesPreview, isFalse);
    expect(small.bytes, smallSource);
    expect(smallEncodeCount, 0);

    var writeCount = 0;
    final largeSource = _pngHeader(width: 3000, height: 2800);
    final failingLoader = ImagePreviewPayloadLoader(
      readOriginal: (_) async => Uint8List.fromList(largeSource),
      readCachedPreview: (_) async => null,
      writeCachedPreview: (_, _) async => writeCount++,
      saveThumbnail: (_, _) async {},
      encodePreview: (_, _, _) async => throw StateError('fictional'),
    );
    final fallback = await failingLoader.load(attachment, forceOriginal: false);
    expect(fallback.usesPreview, isFalse);
    expect(fallback.bytes, largeSource);
    expect(writeCount, 0);
  });

  test('图片尺寸只解析文件头，支持 JPEG、PNG 与 WebP', () {
    expect(
      ImageDimensionReader.read(
        _jpegHeader(width: 4032, height: 3024),
      )?.longSide,
      4032,
    );
    expect(
      ImageDimensionReader.read(_pngHeader(width: 3000, height: 2000))?.height,
      2000,
    );
    expect(
      ImageDimensionReader.read(_webpHeader(width: 4096, height: 3072))?.width,
      4096,
    );
  });
}

Uint8List _jpegHeader({required int width, required int height}) {
  final bytes = Uint8List(21);
  bytes.setRange(0, 4, const <int>[0xff, 0xd8, 0xff, 0xc0]);
  bytes.setRange(4, 11, <int>[
    0,
    17,
    8,
    height >> 8,
    height & 0xff,
    width >> 8,
    width & 0xff,
  ]);
  return bytes;
}

Uint8List _pngHeader({required int width, required int height}) {
  final bytes = Uint8List(24);
  bytes.setRange(0, 8, const <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  bytes.setRange(12, 16, const <int>[73, 72, 68, 82]);
  bytes.setRange(16, 24, <int>[
    width >> 24,
    (width >> 16) & 0xff,
    (width >> 8) & 0xff,
    width & 0xff,
    height >> 24,
    (height >> 16) & 0xff,
    (height >> 8) & 0xff,
    height & 0xff,
  ]);
  return bytes;
}

Uint8List _webpHeader({required int width, required int height}) {
  final bytes = Uint8List(30);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  bytes.setRange(8, 12, 'WEBP'.codeUnits);
  bytes.setRange(12, 16, 'VP8X'.codeUnits);
  final storedWidth = width - 1;
  final storedHeight = height - 1;
  bytes.setRange(24, 30, <int>[
    storedWidth & 0xff,
    (storedWidth >> 8) & 0xff,
    (storedWidth >> 16) & 0xff,
    storedHeight & 0xff,
    (storedHeight >> 8) & 0xff,
    (storedHeight >> 16) & 0xff,
  ]);
  return bytes;
}
