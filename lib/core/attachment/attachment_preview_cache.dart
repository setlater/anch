import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_encrypted_file_writer.dart';
import 'attachment_model.dart';
import 'attachment_payload_reader.dart';

/// 仅保存大图的加密显示预览，不属于用户资料，也不会写入备份。
///
/// 预览以附件密文文件名派生，便于附件删除、覆盖恢复和本机重置时一起清理。
abstract final class AttachmentPreviewCache {
  static const directoryName = 'attachment_previews';

  static Future<Uint8List?> read(
    AttachmentModel attachment, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final file = await _fileFor(
      attachment.fileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    if (!await file.exists()) return null;

    try {
      return await AttachmentPayloadReader.readPathInBackground(file.path);
    } catch (_) {
      // 缓存损坏、密钥已重建或旧版本遗留时，回退原图并移除不可用缓存。
      try {
        await _deleteFileIfExists(file);
      } catch (_) {
        // 私有缓存清理失败时仍必须让调用方回退原图。
      }
      return null;
    }
  }

  static Future<void> write(
    AttachmentModel attachment,
    Uint8List previewBytes, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final file = await _fileFor(
      attachment.fileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    final copy = Uint8List.fromList(previewBytes);
    try {
      await AttachmentEncryptedFileWriter.encryptAndWrite(
        plaintext: copy,
        outputPath: file.path,
      );
    } finally {
      clearAttachmentPlaintext(copy);
    }
  }

  static Future<void> deleteForFileName(
    String attachmentFileName, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final file = await _fileFor(
      attachmentFileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    await _deleteFileIfExists(file);
  }

  static Future<void> clearAll({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final documentsDirectory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final directory = Directory(p.join(documentsDirectory.path, directoryName));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<File> _fileFor(
    String attachmentFileName, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    if (!_isSafeAttachmentFileName(attachmentFileName)) {
      throw const FormatException('附件文件名无效');
    }
    final documentsDirectory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    return File(
      p.join(
        documentsDirectory.path,
        directoryName,
        '$attachmentFileName.preview.enc',
      ),
    );
  }

  static bool _isSafeAttachmentFileName(String fileName) =>
      fileName.isNotEmpty &&
      fileName != '.' &&
      fileName != '..' &&
      !fileName.contains('/') &&
      !fileName.contains('\\');

  static Future<void> _deleteFileIfExists(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
