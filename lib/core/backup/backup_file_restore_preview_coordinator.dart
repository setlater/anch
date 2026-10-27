import 'backup_file_codec.dart';
import 'backup_file_read_service.dart';

/// 备份文件恢复预检元数据结果模型。
///
/// ⚠️ 【安全边界 - 必须遵守】
/// 1. 本类仅限于封装已成功反序列化但未解密的元数据。
/// 2. **绝对严禁**包含完整密文 (ciphertext)、认证标签 (mac)、盐值 (salt)、 nonce 计数器、
///    原始 JSON 字符串、密码、数据库主密钥，防日志泄露。
class BackupFileRestorePreviewResult {
  final int sizeBytes;
  final String sizeLabel;
  final int readAt;
  final String displaySource;
  final int envelopeVersion;
  final int payloadVersion;
  final String kdfName;
  final String cipherName;

  BackupFileRestorePreviewResult({
    required this.sizeBytes,
    required this.sizeLabel,
    required this.readAt,
    required this.displaySource,
    required this.envelopeVersion,
    required this.payloadVersion,
    required this.kdfName,
    required this.cipherName,
  });

  @override
  String toString() {
    // 严格安全脱敏
    return 'BackupFileRestorePreviewResult('
        'sizeBytes: $sizeBytes, '
        'sizeLabel: $sizeLabel, '
        'readAt: $readAt, '
        'displaySource: $displaySource, '
        'envelopeVersion: $envelopeVersion, '
        'payloadVersion: $payloadVersion, '
        'kdfName: $kdfName, '
        'cipherName: $cipherName'
        ')';
  }
}

/// 恢复备份文件预检协调器。
///
/// 职责：
/// 1. 串联文件选择读取与 Envelope 外壳解析格式预检。
/// 2. ⚠️ 【安全红线】本协调器不接触密码，不解密 payload，不执行写库逻辑，元数据严格脱敏。
class BackupFileRestorePreviewCoordinator {
  final BackupFileReadService readService;

  BackupFileRestorePreviewCoordinator({required this.readService});

  /// 读取外部文件字节流并验证 Envelope 外壳格式。
  ///
  /// 如果文件为空、包过大、非合法 JSON 或是结构损坏，抛出对应的异常并经过脱敏。
  Future<BackupFileRestorePreviewResult> readAndPreviewEnvelope() async {
    // 1. 调用底层的读取通道
    final readResult = await readService.readBackupFile();

    // 2. 调用 Codec 静态方法还原 Envelope 外壳并进行结构校验
    try {
      final envelope = BackupFileCodec.decodeEnvelopeBytes(readResult.bytes);

      // 3. 提取脱敏后的元数据模型并返回
      return BackupFileRestorePreviewResult(
        sizeBytes: readResult.sizeBytes,
        sizeLabel: readResult.sizeLabel,
        readAt: readResult.readAt,
        displaySource: readResult.displaySource,
        envelopeVersion: envelope.version,
        payloadVersion: envelope.payloadVersion,
        kdfName: envelope.kdf.name,
        cipherName: envelope.cipher.name,
      );
    } on BackupFileCodecException catch (e) {
      // 抛出转换为脱敏后易读的错误
      throw BackupFileReadException(
        BackupFileReadErrorType.invalidFile,
        e.message,
      );
    } catch (_) {
      throw BackupFileReadException(
        BackupFileReadErrorType.invalidFile,
        '备份文件结构损坏或格式不正确',
      );
    }
  }
}
