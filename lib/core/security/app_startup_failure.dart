/// 描述安册应用启动时的安全或底层服务故障分类
enum AppStartupFailureType {
  /// 安全存储（Secure Storage）无法加载或发生读写异常
  secureStorageUnavailable,

  /// 数据库成功找到文件，但打开失败（底层如连接锁等错误）
  databaseOpenFailed,

  /// 密钥不匹配（PRAGMA key 报错或文件内容疑似不是当前密钥创建的）
  databaseKeyMismatch,

  /// 加密数据库文件损坏
  databaseCorrupted,

  /// 安全存储中的密钥格式非法（非有效 base64url 格式，或解码后非 32 字节）
  invalidStoredKey,

  /// 平台未能确认屏幕内容保护生效
  screenProtectionUnavailable,

  /// 未知分类的错误
  unknown,

  /// 正式安全模式在此构建阶段未启用而被阻断
  formalSecurityModeBlocked,
}

/// 统一的启动异常类，对敏感信息（如密钥原始字串、敏感绝对路径等）进行拦截隐藏
class AppStartupException implements Exception {
  final AppStartupFailureType type;
  final String message;
  final dynamic originalError;

  AppStartupException(this.type, this.message, [this.originalError]);

  @override
  String toString() {
    // ⚠️ 严禁输出原始的 originalError 细节，如果其可能带有密钥等敏感信息
    // ⚠️ toString() 必须脱敏，因此使用映射后的脱敏类型名称，不暴露 databaseKey 等敏感名词
    final cleanType = getSanitizedTypeName(type);
    return 'AppStartupException($cleanType): $message';
  }
}

/// 将高敏或包含敏感词的启动失败类型名称安全地映射转换为脱敏代号，避免在 toString 或 UI 文案中泄露敏感术语
String getSanitizedTypeName(AppStartupFailureType type) {
  switch (type) {
    case AppStartupFailureType.secureStorageUnavailable:
      return 'storage_unavailable';
    case AppStartupFailureType.databaseOpenFailed:
      return 'db_open_failed';
    case AppStartupFailureType.databaseKeyMismatch:
      return 'db_credential_mismatch';
    case AppStartupFailureType.databaseCorrupted:
      return 'db_corrupted';
    case AppStartupFailureType.invalidStoredKey:
      return 'invalid_credential';
    case AppStartupFailureType.formalSecurityModeBlocked:
      return 'formal_blocked';
    case AppStartupFailureType.screenProtectionUnavailable:
      return 'screen_protection_unavailable';
    case AppStartupFailureType.unknown:
      return 'unknown';
  }
}
