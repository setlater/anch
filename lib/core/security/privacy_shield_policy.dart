/// 防窥保护等级。
///
/// 本枚举仅用于决策建议，不直接执行任何防窥操作。
/// 实际防窥能力（FLAG_SECURE、Flutter 遮罩）由调用方根据决策自行实现。
///
/// 等级说明：
/// - [none]：当前状态无需特殊防护。
/// - [softShield]：建议启用 Flutter 层后台遮罩，阻止最近任务卡片明文预览。
/// - [secureFlagRecommended]：建议启用 Android FLAG_SECURE，提供系统级截图阻断。
enum PrivacyShieldLevel {
  /// 无需特殊防护。
  /// 页面内容不含高敏信息，或高敏字段已处于隐藏状态。
  none,

  /// 建议启用 Flutter 层后台遮罩。
  /// 适用于 App 锁定状态等中等敏感场景。
  softShield,

  /// 建议启用 Android FLAG_SECURE（系统级截图阻断）。
  /// 适用于 PIN 输入、备份密码输入、高敏字段展开等高风险场景。
  secureFlagRecommended,
}

/// 防窥保护策略纯 Dart 类原型。
///
/// 根据当前 App 状态决定建议的防窥保护等级。
///
/// **重要**：
/// - 本类只负责计算决策，不执行任何实际防窥操作。
/// - 不调用任何 Android API。
/// - 不依赖 Flutter 框架（可在纯 Dart 环境测试）。
/// - 不接入任何主流程。
///
/// **使用方式**：
/// ```dart
/// const policy = PrivacyShieldPolicy();
/// final level = policy.decide(
///   hasVisibleSensitiveField: true,
///   isEnteringPin: false,
///   isEnteringBackupPassword: false,
///   isAppLocked: false,
/// );
/// // level == PrivacyShieldLevel.secureFlagRecommended
/// ```
///
/// **本阶段禁止录入真实敏感资料。**
class PrivacyShieldPolicy {
  const PrivacyShieldPolicy();

  /// 依据当前 App 的安全状态评估防窥保护等级。
  ///
  /// 优先级（从高到低）：
  /// 1. 正在输入 PIN → [PrivacyShieldLevel.secureFlagRecommended]
  /// 2. 正在输入备份密码 → [PrivacyShieldLevel.secureFlagRecommended]
  /// 3. 高敏字段已展开可见 → [PrivacyShieldLevel.secureFlagRecommended]
  /// 4. 覆盖恢复确认流程活跃 → [PrivacyShieldLevel.secureFlagRecommended]
  /// 5. App 处于锁定状态 → [PrivacyShieldLevel.secureFlagRecommended]
  /// 6. 其他 → [PrivacyShieldLevel.none]
  ///
  /// 参数说明：
  /// - [hasVisibleSensitiveField]：当前页面是否有高敏字段处于明文可见状态。
  /// - [isEnteringPin]：用户是否正在输入 App PIN（PIN 设置页或锁屏解锁页）。
  /// - [isEnteringBackupPassword]：用户是否正在输入备份导出/恢复密码。
  /// - [isAppLocked]：App 是否处于锁定状态。
  /// - [isRestoreConfirming]：是否正在显示覆盖恢复确认流程。
  PrivacyShieldLevel evaluate({
    required bool hasVisibleSensitiveField,
    required bool isEnteringPin,
    required bool isEnteringBackupPassword,
    required bool isAppLocked,
    bool isRestoreConfirming = false,
  }) {
    // 优先级 1：PIN 输入中
    if (isEnteringPin) {
      return PrivacyShieldLevel.secureFlagRecommended;
    }

    // 优先级 2：备份密码输入中
    if (isEnteringBackupPassword) {
      return PrivacyShieldLevel.secureFlagRecommended;
    }

    // 优先级 3：高敏字段明文可见
    if (hasVisibleSensitiveField) {
      return PrivacyShieldLevel.secureFlagRecommended;
    }

    // 优先级 4：覆盖恢复确认流程活跃
    if (isRestoreConfirming) {
      return PrivacyShieldLevel.secureFlagRecommended;
    }

    // 优先级 5：App 处于锁定状态
    if (isAppLocked) {
      return PrivacyShieldLevel.secureFlagRecommended;
    }

    // 其他状态：无需特殊防护
    return PrivacyShieldLevel.none;
  }

  /// 向后兼容的决策方法，供旧版本或旧测试使用。
  PrivacyShieldLevel decide({
    required bool hasVisibleSensitiveField,
    required bool isEnteringPin,
    required bool isEnteringBackupPassword,
    required bool isAppLocked,
    bool isRestoreConfirming = false,
  }) {
    return evaluate(
      hasVisibleSensitiveField: hasVisibleSensitiveField,
      isEnteringPin: isEnteringPin,
      isEnteringBackupPassword: isEnteringBackupPassword,
      isAppLocked: isAppLocked,
      isRestoreConfirming: isRestoreConfirming,
    );
  }
}
