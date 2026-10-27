@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_encrypted_file_writer.dart';
import 'package:anch/core/attachment/attachment_persistence_service.dart';
import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 9)));
  });

  test('加密附件持久化保存元数据，且不写入明文字节', () async {
    final directory = await Directory.systemTemp.createTemp('anch-attachment-');
    addTearDown(() => directory.delete(recursive: true));
    SaveAttachmentInput? savedInput;
    final service = AttachmentPersistenceService(
      getDocumentsDirectory: () async => directory,
      saveMetadata: (input) async {
        savedInput = input;
        return 'attachment-id';
      },
      idFactory: () => 'test-file-id',
    );

    final plaintext = Uint8List.fromList([1, 2, 3, 4]);
    final attachmentId = await service.save(
      itemId: 'item-id',
      bytes: plaintext,
      originalName: 'document.jpg',
      mimeType: 'image/jpeg',
      sortOrder: 0,
    );

    expect(attachmentId, 'attachment-id');
    expect(savedInput?.fileName, 'test-file-id.enc');
    expect(savedInput?.plainSize, 4);
    final encrypted = await File(
      '${directory.path}/attachments/test-file-id.enc',
    ).readAsBytes();
    expect(encrypted, isNot(plaintext));
    expect(savedInput?.encryptedSize, encrypted.length);
    expect(await AttachmentCryptoService.decryptData(encrypted), plaintext);
  });

  test('清除附件明文不会阻断后续页面收尾', () {
    final plaintext = Uint8List.fromList([1, 2, 3, 4]);

    clearAttachmentPlaintext(plaintext);

    expect(plaintext, Uint8List(4));
  });

  test('保存后的图片附件可解密且可由图片编解码器读取', () async {
    final directory = await Directory.systemTemp.createTemp('anch-attachment-');
    addTearDown(() => directory.delete(recursive: true));
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff008080), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final sourceImage = await picture.toImage(2, 2);
    picture.dispose();
    final encoded = await sourceImage.toByteData(
      format: ui.ImageByteFormat.png,
    );
    sourceImage.dispose();
    final originalImage = Uint8List.fromList(encoded!.buffer.asUint8List());
    var thumbnailRequested = false;
    final service = AttachmentPersistenceService(
      getDocumentsDirectory: () async => directory,
      saveMetadata: (_) async => 'attachment-id',
      idFactory: () => 'test-image-id',
      saveThumbnail:
          ({
            required attachmentFileName,
            required sourceBytes,
            required mimeType,
            required documentsDirectoryProvider,
          }) async {
            thumbnailRequested = true;
            expect(attachmentFileName, 'test-image-id.enc');
            expect(mimeType, 'image/png');
            expect(sourceBytes, originalImage);
          },
    );

    await service.save(
      itemId: 'item-id',
      bytes: originalImage,
      originalName: 'fictional-image.png',
      mimeType: 'image/png',
      sortOrder: 0,
    );

    final encrypted = await File(
      '${directory.path}/attachments/test-image-id.enc',
    ).readAsBytes();
    final restoredImage = await AttachmentCryptoService.decryptData(encrypted);
    final codec = await ui.instantiateImageCodec(restoredImage);
    final frame = await codec.getNextFrame();
    try {
      expect(frame.image.width, 2);
      expect(frame.image.height, 2);
      expect(thumbnailRequested, isTrue);
    } finally {
      frame.image.dispose();
      codec.dispose();
      restoredImage.fillRange(0, restoredImage.length, 0);
    }
  });
}
