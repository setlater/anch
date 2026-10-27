/// 页面级防窥风险信号模型。
///
/// 用于在页面层收集高敏/安全状态，统一传递给 `PrivacyShieldCoordinator` 进行决策。
///
/// **安全合规要求**：
/// - 不包含任何真实的敏感数据（如 PIN、备份密码明文、加密密钥等）。
/// - 仅包含布尔类型的状态标志。
/// - [toString] 实现仅输出布尔状态，绝不泄露任何敏感 payload 内容。
class PrivacyShieldSignal {
  const PrivacyShieldSignal({
    this.hasVisibleSensitiveField = false,
    this.isEnteringPin = false,
    this.isEnteringBackupPassword = false,
    this.isAppLocked = false,
    this.isRestoreConfirming = false,
  });

  /// 当前页面是否有高敏字段处于明文可见状态。
  final bool hasVisibleSensitiveField;

  /// 用户是否正在输入 App PIN。
  final bool isEnteringPin;

  /// 用户是否正在输入备份导出/恢复密码。
  final bool isEnteringBackupPassword;

  /// App 当前是否处于锁定状态。
  final bool isAppLocked;

  /// 是否正在显示覆盖恢复确认流程。
  final bool isRestoreConfirming;

  /// 检查是否存在任何可能会引发数据泄露或被截屏的风险。
  bool get hasAnyRisk =>
      hasVisibleSensitiveField ||
      isEnteringPin ||
      isEnteringBackupPassword ||
      isAppLocked ||
      isRestoreConfirming;

  @override
  String toString() {
    return 'PrivacyShieldSignal('
        'hasVisibleSensitiveField: $hasVisibleSensitiveField, '
        'isEnteringPin: $isEnteringPin, '
        'isEnteringBackupPassword: $isEnteringBackupPassword, '
        'isAppLocked: $isAppLocked, '
        'isRestoreConfirming: $isRestoreConfirming'
        ')';
  }
}
