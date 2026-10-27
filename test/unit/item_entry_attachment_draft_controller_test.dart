import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_thumbnail_cache.dart';
import 'package:anch/features/item_entry/controllers/item_entry_attachment_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  setUpAll(() {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 5)));
  });

  test('录入附件草稿加密暂存并可删除私有文件', () async {
    final directory = await Directory.systemTemp.createTemp('anch-entry-');
    addTearDown(() => directory.delete(recursive: true));
    final ids = <String>['file-id', 'attachment-id'];
    final controller = ItemEntryAttachmentDraftController(
      getDocumentsDirectory: () async => directory,
      createId: () => ids.removeAt(0),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
      saveThumbnail:
          ({
            required attachmentFileName,
            required sourceBytes,
            required mimeType,
            required documentsDirectoryProvider,
          }) => AttachmentThumbnailCache.write(
            attachmentFileName,
            Uint8List.fromList(<int>[6, 2, 6]),
            documentsDirectoryProvider: documentsDirectoryProvider,
          ),
    );

    final attachment = await controller.createFromPickedImage(
      pickedFile: XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
        name: 'sample.jpg',
        mimeType: 'image/jpeg',
      ),
      itemId: 'item-id',
      role: 'other',
      sortOrder: 2,
    );

    expect(attachment.id, 'attachment-id');
    expect(attachment.fileName, 'file-id.enc');
    expect(attachment.plainSize, 4);
    expect(attachment.sortOrder, 2);

    final encryptedFile = File('${directory.path}/attachments/file-id.enc');
    final thumbnailFile = File(
      '${directory.path}/attachment_thumbnails/file-id.enc.thumbnail.enc',
    );
    expect(await encryptedFile.exists(), isTrue);
    expect(await thumbnailFile.exists(), isTrue);
    final plainBytes = await AttachmentCryptoService.decryptData(
      await encryptedFile.readAsBytes(),
    );
    expect(plainBytes, Uint8List.fromList(<int>[1, 2, 3, 4]));

    await controller.delete(attachment, deletePhysicalFile: true);

    expect(await encryptedFile.exists(), isFalse);
    expect(await thumbnailFile.exists(), isFalse);
  });

  test('移除已有附件的编辑草稿不会提前删除私有密文', () async {
    final directory = await Directory.systemTemp.createTemp('anch-entry-');
    addTearDown(() => directory.delete(recursive: true));
    final ids = <String>['file-id', 'attachment-id'];
    final controller = ItemEntryAttachmentDraftController(
      getDocumentsDirectory: () async => directory,
      createId: () => ids.removeAt(0),
      now: () => DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final attachment = await controller.createFromPickedImage(
      pickedFile: XFile.fromData(
        Uint8List.fromList(<int>[1, 2, 3, 4]),
        name: 'sample.jpg',
        mimeType: 'image/jpeg',
      ),
      itemId: 'item-id',
      role: 'other',
      sortOrder: 2,
    );
    final encryptedFile = File('${directory.path}/attachments/file-id.enc');

    await controller.delete(attachment);

    expect(await encryptedFile.exists(), isTrue);
  });
}
