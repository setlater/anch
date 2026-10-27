import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../../../core/attachment/attachment_encrypted_file_writer.dart';
import '../../../core/attachment/attachment_model.dart';
import '../../../core/attachment/attachment_thumbnail_cache.dart';
import '../../../core/attachment/attachment_thumbnail_service.dart';

/// 录入流程附件草稿的加密暂存与删除。
///
/// 仅处理文件和附件元数据，不持有页面状态或展示错误提示。
class ItemEntryAttachmentDraftController {
  ItemEntryAttachmentDraftController({
    required this._getDocumentsDirectory,
    required this._createId,
    DateTime Function()? now,
    AttachmentThumbnailSaver? saveThumbnail,
  }) : _now = now ?? DateTime.now,
       _saveThumbnail =
           saveThumbnail ?? AttachmentThumbnailService.generateAndStore;

  final Future<Directory> Function() _getDocumentsDirectory;
  final String Function() _createId;
  final DateTime Function() _now;
  final AttachmentThumbnailSaver _saveThumbnail;

  Future<AttachmentModel> createFromPickedImage({
    required XFile pickedFile,
    required String itemId,
    required String role,
    required int sortOrder,
  }) async {
    final bytes = await pickedFile.readAsBytes();
    await _deletePickedFile(pickedFile.path);
    return createFromBytes(
      bytes: bytes,
      originalName: pickedFile.name,
      mimeType: pickedFile.mimeType ?? 'image/jpeg',
      itemId: itemId,
      role: role,
      sortOrder: sortOrder,
    );
  }

  Future<AttachmentModel> createFromBytes({
    required Uint8List bytes,
    required String originalName,
    required String mimeType,
    required String itemId,
    required String role,
    required int sortOrder,
  }) async {
    final fileName = '${_createId()}.enc';
    final documentsDirectory = await _getDocumentsDirectory();
    final encryptedFile = File(
      p.join(documentsDirectory.path, 'attachments', fileName),
    );
    final encryptedSize = await AttachmentEncryptedFileWriter.encryptAndWrite(
      plaintext: bytes,
      outputPath: encryptedFile.path,
    );
    try {
      await _saveThumbnail(
        attachmentFileName: fileName,
        sourceBytes: bytes,
        mimeType: mimeType,
        documentsDirectoryProvider: _getDocumentsDirectory,
      );
    } catch (_) {
      // 缩略图是派生缓存，不影响草稿附件保存。
    }

    final now = _now().millisecondsSinceEpoch;
    return AttachmentModel(
      id: _createId(),
      itemId: itemId,
      linkedFieldKey: null,
      attachmentRole: role,
      fileName: fileName,
      originalName: originalName,
      mimeType: mimeType,
      plainSize: bytes.length,
      encryptedSize: encryptedSize,
      sha256: null,
      sortOrder: sortOrder,
      status: 'active',
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 从页面草稿移除附件时，只有本次编辑中新建且确认放弃的附件才能立即删除密文。
  ///
  /// 已有附件须等资料保存后，由仓储在数据库提交成功后统一删除；否则用户放弃
  /// 编辑会留下数据库记录指向不存在的文件。
  Future<void> delete(
    AttachmentModel attachment, {
    bool deletePhysicalFile = false,
  }) async {
    if (!deletePhysicalFile) return;
    try {
      final documentsDirectory = await _getDocumentsDirectory();
      final file = File(
        p.join(documentsDirectory.path, 'attachments', attachment.fileName),
      );
      if (await file.exists()) {
        await file.delete();
      }
      await AttachmentThumbnailCache.deleteForFileName(
        attachment.fileName,
        documentsDirectoryProvider: _getDocumentsDirectory,
      );
    } catch (_) {
      // 删除失败不应阻断草稿列表移除；文件仅位于应用私有草稿目录。
    }
  }

  Future<void> _deletePickedFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // 系统相册或相机提供的临时文件可能不允许应用删除。
    }
  }
}
