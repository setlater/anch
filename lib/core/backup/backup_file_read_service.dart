/// 备份文件读取层错误分类。
enum BackupFileReadErrorType {
  userCancelled,
  permissionDenied,
  fileUnavailable,
  fileTooLarge,
  systemPickerUnavailable,
  readFailed,
  invalidFile,
  streamingV2Selected,
  unknown,
}

/// 备份文件读取层异常。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类实例的 [toString] 或是抛出的 [message]，**绝对严禁**包含读取到的二进制 bytes、
///    JSON 文本、密文、解密认证标签、用户密码、密钥、以及任何真实的平台路径、Uri 或 Document ID，防日志溢出泄露。
class BackupFileReadException implements Exception {
  final BackupFileReadErrorType type;
  final String message;

  BackupFileReadException(this.type, this.message);

  @override
  String toString() => 'BackupFileReadException[${type.name}]: $message';
}

/// 备份文件读取层结果模型。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类仅限于反馈内存读取的状态和脱敏元信息。
/// 2. [displaySource] 字段在未来实现中必须是完全预定义或泛化脱敏的文案（例如 `"系统选择的文件"`），
///    **绝对禁止**返回和携带任何真实的 Uri 字符串、物理目录路径或 Document ID，以防敏感路径泄露。
/// 3. 重写 [toString] 时，**绝对验证禁止**输出 bytes 负荷内容。
class BackupFileReadResult {
  final List<int> bytes;
  final int sizeBytes;
  final String sizeLabel;
  final int readAt;
  final String displaySource;

  BackupFileReadResult({
    required this.bytes,
    required this.sizeBytes,
    required this.sizeLabel,
    required this.readAt,
    required this.displaySource,
  });

  @override
  String toString() {
    // 严格安全脱敏，屏蔽所有二进制字节数组，避免在控制台日志溢出
    return 'BackupFileReadResult('
        'sizeBytes: $sizeBytes, '
        'sizeLabel: $sizeLabel, '
        'readAt: $readAt, '
        'displaySource: $displaySource'
        ')';
  }
}

/// 平台备份文件读取抽象接口类。
abstract class BackupFileReadService {
  /// 拉起文件选择器并读取备份文件字节。
  ///
  /// 读取失败或用户取消时，会抛出对应的 [BackupFileReadException]。
  Future<BackupFileReadResult> readBackupFile();
}
