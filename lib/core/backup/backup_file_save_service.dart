import 'backup_unavailable_attachment.dart';

/// 备份文件保存层异常。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类实例的 [toString] 或是抛出的 [message]，**绝对严禁**包含待保存的二进制 bytes、
///    JSON 文本、密文密件、用户密码、密钥、以及任何真实的平台路径、Uri 或 Document ID，防日志溢出泄露。
class BackupFileSaveException implements Exception {
  final BackupFileSaveErrorType type;
  final String message;
  final List<BackupUnavailableAttachment> unavailableAttachments;

  BackupFileSaveException(
    this.type,
    this.message, {
    List<BackupUnavailableAttachment> unavailableAttachments = const [],
  }) : unavailableAttachments = List.unmodifiable(unavailableAttachments);

  @override
  String toString() => 'BackupFileSaveException[${type.name}]: $message';
}

/// 备份文件保存层错误分类。
enum BackupFileSaveErrorType {
  userCancelled,
  permissionDenied,
  storageUnavailable,
  insufficientSpace,
  preparationFailed,
  targetWriteFailed,
  operationInProgress,
  writeInterrupted,
  systemPickerUnavailable,
  writeFailed,
  finalizationFailed,
  sourceUnavailable,
  invalidPackage,
  unknown,
}

/// 备份文件保存层结果模型。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类仅限于反馈内存导出的状态和脱敏元信息。
/// 2. [displayLocation] 字段在未来实现中必须是完全泛化脱敏的文案（例如 `"系统选择的位置"`），
///    **绝对禁止**返回和携带任何真实的 Uri 字符串、物理目录路径或 Document ID，以防敏感路径泄露。
/// 3. 重写 [toString] 时，**绝对禁止**输出 bytes、JSON、密码、密钥或平台物理路径。
class BackupFileSaveResult {
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int savedAt;
  final String displayLocation;
  final bool isSuccess;

  BackupFileSaveResult({
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.savedAt,
    required this.displayLocation,
    required this.isSuccess,
  });

  @override
  String toString() {
    // 严格安全脱敏，屏蔽所有可能泄露的物理信息或内存负荷
    return 'BackupFileSaveResult('
        'fileName: $fileName, '
        'mimeType: $mimeType, '
        'sizeBytes: $sizeBytes, '
        'savedAt: $savedAt, '
        'displayLocation: $displayLocation, '
        'isSuccess: $isSuccess'
        ')';
  }
}
