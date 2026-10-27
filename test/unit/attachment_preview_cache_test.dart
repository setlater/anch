@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/core/attachment/attachment_preview_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  setUpAll(() {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 61)));
  });

  test('图片预览缓存仅以加密文件保存在独立目录，可单独清理', () async {
    final directory = await Directory.systemTemp.createTemp('anch-preview-');
    addTearDown(() => directory.delete(recursive: true));
    const attachment = AttachmentModel(
      id: 'fictional-attachment',
      itemId: 'fictional-item',
      attachmentRole: 'proof',
      fileName: 'fictional.enc',
      mimeType: 'image/jpeg',
      plainSize: 1,
      encryptedSize: 29,
      sortOrder: 0,
      status: 'active',
      createdAt: 1,
      updatedAt: 1,
    );
    final preview = Uint8List.fromList(<int>[3, 1, 4, 1, 5]);

    await AttachmentPreviewCache.write(
      attachment,
      preview,
      documentsDirectoryProvider: () async => directory,
    );

    final encryptedFile = File(
      p.join(
        directory.path,
        AttachmentPreviewCache.directoryName,
        'fictional.enc.preview.enc',
      ),
    );
    expect(await encryptedFile.exists(), isTrue);
    expect(await encryptedFile.readAsBytes(), isNot(preview));
    expect(
      await AttachmentPreviewCache.read(
        attachment,
        documentsDirectoryProvider: () async => directory,
      ),
      preview,
    );

    await AttachmentPreviewCache.deleteForFileName(
      attachment.fileName,
      documentsDirectoryProvider: () async => directory,
    );
    expect(await encryptedFile.exists(), isFalse);

    await AttachmentPreviewCache.write(
      attachment,
      preview,
      documentsDirectoryProvider: () async => directory,
    );
    await AttachmentPreviewCache.clearAll(
      documentsDirectoryProvider: () async => directory,
    );
    expect(
      await Directory(
        p.join(directory.path, AttachmentPreviewCache.directoryName),
      ).exists(),
      isFalse,
    );
  });
}
