import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'attachment_crypto_service.dart';
import 'attachment_model.dart';

/// 仅在用户主动预览或导出时读取并解密附件负荷。
abstract final class AttachmentPayloadReader {
  static const int encryptedEnvelopeSize = 28;

  static Future<int> resolvePlainSize(AttachmentModel attachment) async {
    final file = await _fileFor(attachment);
    final encryptedSize = await file.length();
    if (encryptedSize < encryptedEnvelopeSize) {
      throw const FormatException('附件加密封装长度无效');
    }
    return encryptedSize - encryptedEnvelopeSize;
  }

  static Future<Uint8List> read(AttachmentModel attachment) async {
    final file = await _fileFor(attachment);
    final encryptedBytes = await file.readAsBytes();
    try {
      return await AttachmentCryptoService.decryptData(encryptedBytes);
    } finally {
      encryptedBytes.fillRange(0, encryptedBytes.length, 0);
    }
  }

  /// 供大附件预览或外部打开路径使用，避免完整读取和解密阻塞 UI isolate。
  static Future<Uint8List> readInBackground(AttachmentModel attachment) async {
    final file = await _fileFor(attachment);
    return readPathInBackground(file.path);
  }

  /// 仅供备份导出读取应用私有附件；调用方不得记录 [filePath]。
  static Future<Uint8List> readPathInBackground(String filePath) async {
    final databaseKey = AttachmentCryptoService.cachedDbKey;
    final encryptedPayload = await Isolate.run(
      () => _readAndDecryptInBackground(filePath, databaseKey),
    );
    return encryptedPayload.materialize().asUint8List();
  }

  /// 确认既有私有附件可由当前设备密钥解密；仅用于历史备份恢复的前置保护。
  static Future<void> validatePathInBackground(
    String filePath, {
    required int expectedPlainSize,
  }) async {
    final databaseKey = AttachmentCryptoService.cachedDbKey;
    await Isolate.run(
      () => _validateEncryptedFileInBackground(
        filePath,
        databaseKey,
        expectedPlainSize,
      ),
    );
  }

  static Future<File> _fileFor(AttachmentModel attachment) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    return File(
      p.join(documentsDirectory.path, 'attachments', attachment.fileName),
    );
  }
}

Future<TransferableTypedData> _readAndDecryptInBackground(
  String filePath,
  String databaseKey,
) async {
  final encryptedBytes = await File(filePath).readAsBytes();
  try {
    final plaintext = await AttachmentCryptoService.decryptData(
      encryptedBytes,
      databaseKey,
    );
    return TransferableTypedData.fromList(<Uint8List>[plaintext]);
  } finally {
    encryptedBytes.fillRange(0, encryptedBytes.length, 0);
  }
}

Future<void> _validateEncryptedFileInBackground(
  String filePath,
  String databaseKey,
  int expectedPlainSize,
) async {
  final encryptedBytes = await File(filePath).readAsBytes();
  try {
    final plaintext = await AttachmentCryptoService.decryptData(
      encryptedBytes,
      databaseKey,
    );
    try {
      if (plaintext.length != expectedPlainSize) throw const FormatException();
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  } finally {
    encryptedBytes.fillRange(0, encryptedBytes.length, 0);
  }
}
