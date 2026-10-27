import 'app_lock_bootstrap_policy.dart';
import 'app_lock_state.dart';
import 'app_pin_manager.dart';
import 'app_lock_settings_manager.dart';
import 'app_lock_attempt_manager.dart';

/// App 锁启动初始化决策结果对象，进行了脱敏封装。
class AppLockBootstrapResult {
  const AppLockBootstrapResult({
    required this.hasPin,
    required this.enabled,
    required this.decision,
    required this.initialState,
  });

  final bool hasPin;
  final bool enabled;
  final AppLockBootstrapDecision decision;
  final AppLockState initialState;

  @override
  String toString() {
    // ⚠️ 【安全红线】toString 必须脱敏，绝对不能泄露 PIN、salt、verifier、databaseKey，也不输出底层异常细节
    return 'AppLockBootstrapResult(hasPin: $hasPin, enabled: $enabled, decision: $decision, initialStateStatus: ${initialState.status})';
  }
}

/// App 锁冷启动初始化引导服务原型。
class AppLockBootstrapService {
  final AppPinManager appPinManager;
  final AppLockSettingsManager appLockSettingsManager;
  final AppLockBootstrapPolicy policy;
  final AppLockAttemptManager? attemptManager;

  const AppLockBootstrapService({
    required this.appPinManager,
    required this.appLockSettingsManager,
    this.attemptManager,
    this.policy = const AppLockBootstrapPolicy(),
  });

  /// 执行应用冷启动应用锁初始化决策过程。
  /// 捕获并收敛任何底层存储（Secure Storage）的原始异常，防止异常详情与敏感信息外泄。
  Future<AppLockBootstrapResult> bootstrap({
    required bool appLockGateExplicitlyEnabled,
  }) async {
    bool hasPin = false;
    bool enabled = false;
    bool pinReadError = false;
    bool settingsReadError = false;

    // 1. 读取 hasPin，发生异常时记录错误标识
    try {
      hasPin = await appPinManager.hasPin();
    } catch (_) {
      pinReadError = true;
    }

    // 2. 读取 enabled，发生异常时记录错误标识
    try {
      enabled = await appLockSettingsManager.isAppLockEnabled();
    } catch (_) {
      settingsReadError = true;
    }

    AppLockBootstrapDecision decision;
    AppLockState initialState;

    // 3. 覆盖异常流：如果任一读取动作失败，将决策收敛至 configurationError，状态设为 unconfigured
    if (pinReadError || settingsReadError) {
      decision = AppLockBootstrapDecision.configurationError;
      initialState = const AppLockState(status: AppLockStatus.unconfigured);
      return AppLockBootstrapResult(
        hasPin: pinReadError ? false : hasPin,
        enabled: settingsReadError ? false : enabled,
        decision: decision,
        initialState: initialState,
      );
    }

    // 4. 调用策略决策
    decision = policy.decide(
      hasPin: hasPin,
      enabled: enabled,
      appLockGateExplicitlyEnabled: appLockGateExplicitlyEnabled,
    );

    // 5. 映射至 AppLockState
    switch (decision) {
      case AppLockBootstrapDecision.disabledForDev:
        initialState = const AppLockState(status: AppLockStatus.disabledForDev);
        break;
      case AppLockBootstrapDecision.unlockedForPrototype:
        initialState = const AppLockState(status: AppLockStatus.unlocked);
        break;
      case AppLockBootstrapDecision.requireSetup:
        initialState = const AppLockState(status: AppLockStatus.unconfigured);
        break;
      case AppLockBootstrapDecision.requireUnlock:
        AppLockAttemptState? attempts;
        try {
          attempts = await attemptManager?.load();
        } on AppLockAttemptStorageException {
          decision = AppLockBootstrapDecision.configurationError;
          initialState = const AppLockState(status: AppLockStatus.unconfigured);
          break;
        }
        final lockedUntil = attempts?.lockedUntilMillis;
        initialState = AppLockState(
          status:
              lockedUntil != null &&
                  lockedUntil > DateTime.now().millisecondsSinceEpoch
              ? AppLockStatus.temporarilyLocked
              : AppLockStatus.locked,
          failedAttempts: attempts?.failedAttempts ?? 0,
          lockedUntilMillis: lockedUntil,
        );
        break;
      case AppLockBootstrapDecision.configurationError:
        initialState = const AppLockState(status: AppLockStatus.unconfigured);
        break;
    }

    return AppLockBootstrapResult(
      hasPin: hasPin,
      enabled: enabled,
      decision: decision,
      initialState: initialState,
    );
  }
}
