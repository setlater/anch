import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'attachment_encrypted_file_writer.dart';
import 'attachment_thumbnail_cache.dart';
import 'attachment_thumbnail_service.dart';
import 'save_attachment_input.dart';

/// 将已在本地取得并处理的附件写入加密私有存储。
///
/// 不负责系统文件选择、裁剪或压缩；调用方只在用户确认导入后传入字节。
/// 失败时会删除本次生成的加密文件，避免留下孤儿附件。
class AttachmentPersistenceService {
  AttachmentPersistenceService({
    required this.getDocumentsDirectory,
    required this.saveMetadata,
    String Function()? idFactory,
    AttachmentThumbnailSaver? saveThumbnail,
  }) : _idFactory = idFactory ?? _generateId,
       _saveThumbnail =
           saveThumbnail ?? AttachmentThumbnailService.generateAndStore;

  final Future<Directory> Function() getDocumentsDirectory;
  final Future<String> Function(SaveAttachmentInput input) saveMetadata;
  final String Function() _idFactory;
  final AttachmentThumbnailSaver _saveThumbnail;

  Future<String> save({
    required String itemId,
    required Uint8List bytes,
    required String originalName,
    required String mimeType,
    required int sortOrder,
    String attachmentRole = 'proof',
  }) async {
    final fileName = '${_idFactory()}.enc';
    final documentsDirectory = await getDocumentsDirectory();
    final encryptedFile = File(
      p.join(documentsDirectory.path, 'attachments', fileName),
    );

    try {
      final encryptedSize = await AttachmentEncryptedFileWriter.encryptAndWrite(
        plaintext: bytes,
        outputPath: encryptedFile.path,
      );
      try {
        await _saveThumbnail(
          attachmentFileName: fileName,
          sourceBytes: bytes,
          mimeType: mimeType,
          documentsDirectoryProvider: getDocumentsDirectory,
        );
      } catch (_) {
        // 缩略图是派生缓存，不影响原附件与元数据保存。
      }

      return await saveMetadata(
        SaveAttachmentInput(
          itemId: itemId,
          fileName: fileName,
          originalName: originalName,
          mimeType: mimeType,
          plainSize: bytes.length,
          encryptedSize: encryptedSize,
          sortOrder: sortOrder,
          attachmentRole: attachmentRole,
        ),
      );
    } catch (_) {
      try {
        await encryptedFile.delete();
      } catch (_) {}
      try {
        await AttachmentThumbnailCache.deleteForFileName(
          fileName,
          documentsDirectoryProvider: getDocumentsDirectory,
        );
      } catch (_) {}
      rethrow;
    }
  }

  static String _generateId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return values
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
