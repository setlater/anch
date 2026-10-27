@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_thumbnail_cache.dart';
import 'package:anch/core/attachment/attachment_thumbnail_service.dart';
import 'package:anch/core/attachment/image_dimension_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 62)));
  });

  test('导入图片生成独立加密小缩略图，不保留原图字节', () async {
    final directory = await Directory.systemTemp.createTemp('anch-thumb-');
    addTearDown(() => directory.delete(recursive: true));
    final source = _jpegHeader(width: 4032, height: 3024);

    await AttachmentThumbnailService.generateAndStore(
      attachmentFileName: 'fictional.enc',
      sourceBytes: source,
      mimeType: 'image/jpeg',
      documentsDirectoryProvider: () async => directory,
      encode: (_, size, _) async {
        expect(size.width, 4032);
        expect(size.height, 3024);
        return Uint8List.fromList(<int>[6, 2, 6]);
      },
    );

    final encrypted = File(
      p.join(
        directory.path,
        AttachmentThumbnailCache.directoryName,
        'fictional.enc.thumbnail.enc',
      ),
    );
    expect(await encrypted.exists(), isTrue);
    expect(await encrypted.readAsBytes(), isNot(<int>[6, 2, 6]));
    expect(
      await AttachmentThumbnailCache.read(
        'fictional.enc',
        documentsDirectoryProvider: () async => directory,
      ),
      <int>[6, 2, 6],
    );
  });

  test('未知图片文件头仍会由原生编解码器生成并收口缩略图', () async {
    final directory = await Directory.systemTemp.createTemp('anch-thumb-');
    addTearDown(() => directory.delete(recursive: true));
    final requestedSizes = <ImagePixelSize>[];

    await AttachmentThumbnailService.generateAndStore(
      attachmentFileName: 'fictional-heic.enc',
      sourceBytes: Uint8List.fromList(<int>[1, 2, 3]),
      mimeType: 'image/heic',
      documentsDirectoryProvider: () async => directory,
      encode: (_, size, _) async {
        requestedSizes.add(size);
        if (requestedSizes.length == 1) {
          return _jpegHeader(width: 512, height: 256);
        }
        return Uint8List.fromList(<int>[9, 8, 7]);
      },
    );

    expect(requestedSizes, hasLength(2));
    expect(requestedSizes.first.width, 256);
    expect(requestedSizes.first.height, 256);
    expect(requestedSizes.last.width, 512);
    expect(requestedSizes.last.height, 256);
    expect(
      await AttachmentThumbnailCache.read(
        'fictional-heic.enc',
        documentsDirectoryProvider: () async => directory,
      ),
      <int>[9, 8, 7],
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
