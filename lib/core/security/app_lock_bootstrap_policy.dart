enum AppLockBootstrapDecision {
  /// 开发验证或测试下不启用应用锁网关，默认绕过。
  disabledForDev,

  /// 应用锁网关已被显式开启，但用户尚未在设置中启用应用锁。
  unlockedForPrototype,

  /// 用户已在设置中开启应用锁，但底层 PIN 校验材料损坏或不存在，必须引导修复配置。
  requireSetup,

  /// 用户开启应用锁且 PIN 配置完整，要求显示锁屏拦截。
  requireUnlock,

  /// [预留状态]
  ///
  /// 预留给后续真实冷启动初始化阶段使用。
  /// 例如 Secure Storage 读取崩溃、enabled 状态损坏、PIN 校验材料内部密码学解密失败等未知场景。
  /// 本批纯策略类只处理 hasPin / enabled / appLockGateExplicitlyEnabled 三个已知布尔值，
  /// 因此目前在规则中不主动返回该状态。
  configurationError,
}

class AppLockBootstrapPolicy {
  const AppLockBootstrapPolicy();

  /// 依据冷启动读取的三个必要状态决定应用锁初始流转态
  AppLockBootstrapDecision decide({
    required bool hasPin,
    required bool enabled,
    required bool appLockGateExplicitlyEnabled,
  }) {
    // 1. 若应用锁网关未被显式启用（默认开发/测试路径）
    if (!appLockGateExplicitlyEnabled) {
      return AppLockBootstrapDecision.disabledForDev;
    }

    // 2. 若显式启用了网关，但用户关闭了应用锁设置
    if (!enabled) {
      return AppLockBootstrapDecision.unlockedForPrototype;
    }

    // 3. 若用户启用了应用锁设置，但底层 PIN 不存在或损坏
    if (!hasPin) {
      return AppLockBootstrapDecision.requireSetup;
    }

    // 4. 若用户启用了应用锁设置，且底层 PIN 完整
    return AppLockBootstrapDecision.requireUnlock;
  }
}
