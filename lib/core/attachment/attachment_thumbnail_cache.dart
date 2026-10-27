import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_encrypted_file_writer.dart';
import 'attachment_payload_reader.dart';

/// 用于列表和详情的低分辨率加密缩略图，不属于备份资料。
abstract final class AttachmentThumbnailCache {
  static const directoryName = 'attachment_thumbnails';

  static Future<Uint8List?> read(
    String attachmentFileName, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final file = await _fileFor(
      attachmentFileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    if (!await file.exists()) return null;
    try {
      return await AttachmentPayloadReader.readPathInBackground(file.path);
    } catch (_) {
      try {
        await _deleteFileIfExists(file);
      } catch (_) {
        // 缓存清理失败仍让调用方显示占位，不回退读取大原图。
      }
      return null;
    }
  }

  static Future<void> write(
    String attachmentFileName,
    Uint8List thumbnailBytes, {
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final file = await _fileFor(
      attachmentFileName,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    final copy = Uint8List.fromList(thumbnailBytes);
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
    await _deleteFileIfExists(
      await _fileFor(
        attachmentFileName,
        documentsDirectoryProvider: documentsDirectoryProvider,
      ),
    );
  }

  static Future<void> clearAll({
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final documentsDirectory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final directory = Directory(p.join(documentsDirectory.path, directoryName));
    if (await directory.exists()) await directory.delete(recursive: true);
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
        '$attachmentFileName.thumbnail.enc',
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
    if (await file.exists()) await file.delete();
  }
}
