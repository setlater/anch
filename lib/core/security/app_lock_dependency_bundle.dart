import 'app_lock_bootstrap_service.dart';
import 'app_lock_controller.dart';
import 'app_lock_settings_manager.dart';
import 'app_pin_manager.dart';
import 'app_lock_lifecycle_controller.dart';
import 'app_biometric_authenticator.dart';
import 'app_lock_attempt_manager.dart';
import 'app_lock_preferences_manager.dart';

/// 运行时应用锁参数与策略配置对象。
class AppLockRuntimeOptions {
  const AppLockRuntimeOptions({
    required this.appLockGateExplicitlyEnabled,
    this.disableForTests = false,
  });

  /// 应用锁网关是否显式启用。
  final bool appLockGateExplicitlyEnabled;

  /// 是否在测试中强制旁路（禁用锁屏与修复页阻断）。
  final bool disableForTests;

  /// 根据当前参数决定是否需要旁路应用锁。
  ///
  /// 如果 [disableForTests] 为 true，则强制旁路（将返回 true 告知外部测试环境下应放行）。
  bool get shouldBypass => disableForTests;
}

/// 统一管理并注入 App 锁相关核心服务与管理器的依赖包原型。
///
/// **职责边界**：
/// 1. 本类仅作为一个纯依赖组合实体（数据或引用容器）。
/// 2. 本类内部绝对不在创建或初始化时触发物理的 Secure Storage 读取。
/// 3. 本类内部绝对不在创建时调用任何 `bootstrap()` 执行初始决策。
/// 4. 本类的 `toString()` 方法已经过严格的敏感词与隐私脱敏过滤。
class AppLockDependencyBundle {
  const AppLockDependencyBundle({
    required this.appPinManager,
    required this.appLockSettingsManager,
    required this.appLockBootstrapService,
    required this.appLockController,
    required this.appLockBootstrapResult,
    this.appLockLifecycleController,
    this.appBiometricAuthenticator,
    this.appLockPreferencesManager,
    this.appLockAttemptManager,
    this.appLockPreferences = const AppLockPreferences(),
  });

  final AppPinManager appPinManager;
  final AppLockSettingsManager appLockSettingsManager;
  final AppLockBootstrapService appLockBootstrapService;
  final AppLockController appLockController;
  final AppLockBootstrapResult appLockBootstrapResult;
  final AppLockLifecycleController? appLockLifecycleController;
  final AppBiometricAuthenticator? appBiometricAuthenticator;
  final AppLockPreferencesManager? appLockPreferencesManager;
  final AppLockAttemptManager? appLockAttemptManager;
  final AppLockPreferences appLockPreferences;

  @override
  String toString() {
    // ⚠️ 【安全红线】toString 必须严格脱敏，绝不暴露 PIN、salt、verifier、databaseKey，也不暴露异常细节。
    return 'AppLockDependencyBundle('
        'appPinManager: ${appPinManager.runtimeType}, '
        'appLockSettingsManager: ${appLockSettingsManager.runtimeType}, '
        'appLockBootstrapService: ${appLockBootstrapService.runtimeType}, '
        'appLockControllerStatus: ${appLockController.value.status}, '
        'appLockBootstrapResult: $appLockBootstrapResult)';
  }
}
