import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../attachment/attachment_encrypted_file_writer.dart';
import '../attachment/attachment_payload_reader.dart';
import 'backup_payload.dart';
import 'backup_v2_format.dart';

/// V2 恢复期间的附件目录 staging。
///
/// 目录位于应用私有 documents 区，直到所有分帧、顺序、长度和最终提交帧通过才可移交给恢复事务；它不保存外部
/// URI、真实路径或资料内容到日志、UI 或异常。
class BackupV2AttachmentDirectoryStaging implements BackupV2AttachmentStaging {
  final BackupPayloadV1 payload;
  final BackupV2AttachmentEncoding attachmentEncoding;
  final Directory _directory;
  RandomAccessFile? _currentFile;
  BytesBuilder? _currentPlaintext;
  var _currentIndex = -1;
  var _completed = false;
  var _taken = false;

  BackupV2AttachmentDirectoryStaging._({
    required this.payload,
    required this.attachmentEncoding,
    required this._directory,
  });

  static Future<BackupV2AttachmentDirectoryStaging> create(
    BackupPayloadV1 payload, {
    BackupV2AttachmentEncoding attachmentEncoding =
        BackupV2AttachmentEncoding.sourceEncrypted,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) async {
    final documentsDirectory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final token =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final directory = Directory(
      p.join(documentsDirectory.path, '.backup-v2-restore-stage-$token'),
    );
    try {
      await directory.create();
      return BackupV2AttachmentDirectoryStaging._(
        payload: payload,
        attachmentEncoding: attachmentEncoding,
        directory: directory,
      );
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
  }

  @override
  Future<void> writeChunk({
    required int attachmentIndex,
    required Uint8List bytes,
  }) async {
    if (_completed ||
        _taken ||
        attachmentIndex < 0 ||
        attachmentIndex >= payload.data.attachments.length) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
    try {
      if (attachmentIndex != _currentIndex) {
        if (attachmentIndex != _currentIndex + 1) {
          throw const FormatException();
        }
        await _finishCurrentAttachment();
        await _startAttachment(attachmentIndex);
      }
      final attachment = payload.data.attachments[attachmentIndex];
      if (attachmentEncoding == BackupV2AttachmentEncoding.portablePlaintext) {
        final plaintext = _currentPlaintext;
        if (plaintext == null ||
            plaintext.length + bytes.length > attachment.plainSize) {
          throw const FormatException();
        }
        plaintext.add(bytes);
      } else {
        await _currentFile!.writeFrom(bytes);
      }
    } on BackupV2FormatException {
      rethrow;
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
  }

  @override
  Future<void> complete() async {
    if (_completed || _taken) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
    try {
      await _finishCurrentAttachment();
      final names = <String>{};
      for (var index = 0; index < payload.data.attachments.length; index++) {
        final attachment = payload.data.attachments[index];
        if (!_isSafeAttachmentFileName(attachment.fileName) ||
            !names.add(attachment.fileName)) {
          throw const FormatException();
        }
        if (attachmentEncoding ==
                BackupV2AttachmentEncoding.portablePlaintext &&
            index > _currentIndex) {
          if (attachment.plainSize != 0) throw const FormatException();
          await _writePortableAttachment(attachment, Uint8List(0));
          _currentIndex = index;
        }
        final file = File(p.join(_directory.path, attachment.fileName));
        if (attachmentEncoding == BackupV2AttachmentEncoding.sourceEncrypted &&
            attachment.encryptedSize == 0 &&
            !await file.exists()) {
          await file.create();
        }
        if (!await file.exists() ||
            await file.length() != attachment.encryptedSize) {
          throw const FormatException();
        }
        if (attachmentEncoding == BackupV2AttachmentEncoding.sourceEncrypted) {
          try {
            await AttachmentPayloadReader.validatePathInBackground(
              file.path,
              expectedPlainSize: attachment.plainSize,
            );
          } catch (_) {
            throw const BackupV2FormatException(
              BackupV2FormatErrorType.attachmentNotRecoverable,
              '此历史备份中的附件无法在当前设备恢复，原数据未改动。',
            );
          }
        }
      }
      _completed = true;
    } on BackupV2FormatException {
      rethrow;
    } catch (_) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
  }

  /// 仅供 [BackupImportService] 在通过所有认证后移交到它的原子切换流程。
  Future<Directory> takeDirectoryForRestore() async {
    if (!_completed || _taken) {
      throw const BackupV2FormatException(
        BackupV2FormatErrorType.stagingFailed,
        '备份附件暂存失败，原数据未改动。',
      );
    }
    _taken = true;
    return _directory;
  }

  @override
  Future<void> abort() async {
    try {
      await _currentFile?.close();
      _currentFile = null;
      final plaintext = _currentPlaintext?.takeBytes();
      _currentPlaintext = null;
      if (plaintext != null) clearAttachmentPlaintext(plaintext);
      if (!_taken && await _directory.exists()) {
        await _directory.delete(recursive: true);
      }
    } catch (_) {
      // 新建 staging 的清理失败不影响当前资料；下次应用启动可安全清理无引用目录。
    }
  }

  static bool _isSafeAttachmentFileName(String fileName) {
    return fileName.isNotEmpty &&
        fileName != '.' &&
        fileName != '..' &&
        !fileName.contains('/') &&
        !fileName.contains('\\');
  }

  Future<void> _startAttachment(int attachmentIndex) async {
    final attachment = payload.data.attachments[attachmentIndex];
    if (!_isSafeAttachmentFileName(attachment.fileName)) {
      throw const FormatException();
    }
    if (attachmentEncoding == BackupV2AttachmentEncoding.portablePlaintext) {
      _currentPlaintext = BytesBuilder(copy: false);
    } else {
      _currentFile = await File(
        p.join(_directory.path, attachment.fileName),
      ).open(mode: FileMode.write);
    }
    _currentIndex = attachmentIndex;
  }

  Future<void> _finishCurrentAttachment() async {
    if (_currentIndex < 0) return;
    if (attachmentEncoding != BackupV2AttachmentEncoding.portablePlaintext) {
      await _currentFile?.close();
      _currentFile = null;
      return;
    }
    final attachment = payload.data.attachments[_currentIndex];
    final plaintext = _currentPlaintext?.takeBytes() ?? Uint8List(0);
    _currentPlaintext = null;
    if (plaintext.length != attachment.plainSize) {
      clearAttachmentPlaintext(plaintext);
      throw const FormatException();
    }
    await _writePortableAttachment(attachment, plaintext);
  }

  Future<void> _writePortableAttachment(
    BackupAttachmentV1 attachment,
    Uint8List plaintext,
  ) async {
    try {
      final encryptedSize = await AttachmentEncryptedFileWriter.encryptAndWrite(
        plaintext: plaintext,
        outputPath: p.join(_directory.path, attachment.fileName),
      );
      if (encryptedSize != attachment.encryptedSize) {
        throw const FormatException();
      }
    } finally {
      clearAttachmentPlaintext(plaintext);
    }
  }
}
