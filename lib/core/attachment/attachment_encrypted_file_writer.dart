import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'attachment_crypto_service.dart';

/// 在临时 isolate 中加密附件；密文落盘沿用调用方的异步文件 I/O 路径。
abstract final class AttachmentEncryptedFileWriter {
  static Future<int> encryptAndWrite({
    required Uint8List plaintext,
    required String outputPath,
  }) async {
    final databaseKey = AttachmentCryptoService.cachedDbKey;
    final transferablePlaintext = TransferableTypedData.fromList([plaintext]);
    final encryptedPayload = await Isolate.run(
      () => _encryptInBackground(transferablePlaintext, databaseKey),
    );
    final encryptedBytes = encryptedPayload.materialize().asUint8List();
    try {
      final outputFile = File(outputPath);
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(encryptedBytes, flush: true);
      return encryptedBytes.length;
    } finally {
      encryptedBytes.fillRange(0, encryptedBytes.length, 0);
    }
  }
}

/// 尽力清除调用方持有的附件明文。
///
/// 传给临时 isolate 的缓冲区可能已转移所有权；无论清除是否可执行，页面都
/// 不应因此停留在导入遮罩。
void clearAttachmentPlaintext(Uint8List bytes) {
  try {
    bytes.fillRange(0, bytes.length, 0);
  } catch (_) {
    // 已转移的缓冲区由临时 isolate 负责清除。
  }
}

Future<TransferableTypedData> _encryptInBackground(
  TransferableTypedData transferablePlaintext,
  String databaseKey,
) async {
  final plaintext = transferablePlaintext.materialize().asUint8List();
  try {
    final encryptedBytes = await AttachmentCryptoService.encryptData(
      plaintext,
      databaseKey,
    );
    return TransferableTypedData.fromList([encryptedBytes]);
  } finally {
    plaintext.fillRange(0, plaintext.length, 0);
  }
}
