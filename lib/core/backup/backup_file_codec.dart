import 'dart:convert';
import 'backup_envelope.dart';
import 'backup_file_policy.dart';

/// 备份文件编解码异常类。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类实例的 [toString] 或是抛出的 [message]，**绝对严禁**包含密文数据（`ciphertext`）、
///    解密认证标签（`mac`）、任何 `TEST-*` 测试明文或原始 JSON 串，以防敏感信息泄漏。
class BackupFileCodecException implements Exception {
  final BackupFileCodecErrorType type;
  final String message;

  BackupFileCodecException(this.type, this.message);

  @override
  String toString() => 'BackupFileCodecException[${type.name}]: $message';
}

/// 编解码异常错误类型。
enum BackupFileCodecErrorType {
  emptyBytes,
  fileTooLarge,
  invalidUtf8,
  invalidJson,
  invalidEnvelope,
  unknown,
}

/// 内存中的“待保存备份文件包”对象。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 重写 [toString] 时，**绝对禁止**输出 bytes 二进制数据、明文 JSON、密文（`ciphertext`）或认证标签（`mac`）。
class BackupFilePackage {
  final String fileName;
  final String mimeType;
  final List<int> bytes;
  final int sizeBytes;
  final String sizeLabel;
  final int createdAt;

  BackupFilePackage({
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.createdAt,
  });

  @override
  String toString() {
    // 严格安全脱敏，不输出敏感的数据负荷与密文字段
    return 'BackupFilePackage('
        'fileName: $fileName, '
        'mimeType: $mimeType, '
        'sizeBytes: $sizeBytes, '
        'sizeLabel: $sizeLabel, '
        'createdAt: $createdAt'
        ')';
  }
}

/// 备份物理层字节封装与解析工具（内存编解码）。
abstract final class BackupFileCodec {
  BackupFileCodec._();

  /// 备份文件大小软硬硬顶阈值上限：50MB
  static const int maxBackupFileBytes = 50 * 1024 * 1024;

  /// 将 [BackupEnvelopeV1] 编码为内存字节待保存包 [BackupFilePackage]。
  static BackupFilePackage encodeEnvelope({
    required BackupEnvelopeV1 envelope,
    required int nowMillis,
  }) {
    // 1. 转为 JSON Map 并编码
    final map = envelope.toJson();
    final jsonStr = jsonEncode(map);
    final bytes = utf8.encode(jsonStr);

    // 2. 双向大小检查
    if (bytes.length > maxBackupFileBytes) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.fileTooLarge,
        '生成的备份文件过大，超出最大文件大小限制',
      );
    }

    // 3. 构建默认包信息并返回
    final fileName = BackupFilePolicy.buildDefaultFileName(
      nowMillis: nowMillis,
    );
    final sizeLabel = BackupFilePolicy.formatBytes(bytes.length);

    return BackupFilePackage(
      fileName: fileName,
      mimeType: BackupFilePolicy.defaultMimeType,
      bytes: bytes,
      sizeBytes: bytes.length,
      sizeLabel: sizeLabel,
      createdAt: nowMillis,
    );
  }

  /// 将字节数组反序列化还原为 [BackupEnvelopeV1]。
  static BackupEnvelopeV1 decodeEnvelopeBytes(List<int> bytes) {
    // 1. 空数据检查
    if (bytes.isEmpty) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.emptyBytes,
        '备份文件数据为空',
      );
    }

    // 2. 双向大小检查
    if (bytes.length > maxBackupFileBytes) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.fileTooLarge,
        '备份文件过大，超出最大文件大小限制',
      );
    }

    // 3. 强校验的 UTF-8 解开
    final String jsonStr;
    try {
      jsonStr = utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.invalidUtf8,
        '备份文件编码非合法的 UTF-8 二进制流',
      );
    }

    // 4. 解析为 JSON 对象并校验 Map 类型后强转
    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonStr);
    } catch (_) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.invalidJson,
        '备份文件内容不是有效的 JSON 文本',
      );
    }

    if (decoded is! Map) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.invalidJson,
        '备份文件外壳必须是 JSON 对象结构',
      );
    }

    final Map<String, Object?> jsonMap = Map<String, Object?>.from(decoded);

    // 5. 反序列化还原 Envelope
    try {
      return BackupEnvelopeV1.fromJson(jsonMap);
    } catch (_) {
      throw BackupFileCodecException(
        BackupFileCodecErrorType.invalidEnvelope,
        '备份文件结构损坏或格式不正确',
      );
    }
  }
}
