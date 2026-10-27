import 'package:flutter/material.dart';
import '../../core/security/app_lock_bootstrap_policy.dart';
import '../../core/security/app_lock_controller.dart';
import 'app_lock_gate.dart';
import 'app_lock_recovery_page.dart';
import '../privacy/screen_protection_scope.dart';
import '../../core/security/app_biometric_authenticator.dart';

/// 应用根节点的启动门禁。
/// 配置异常或缺少 PIN 时展示恢复入口；需要解锁时由 [AppLockGate] 监听运行状态。
/// 本组件只消费已完成的启动决策，不读取存储、不修改凭据或重置资料。
class AppLockBootstrapGate extends StatelessWidget {
  const AppLockBootstrapGate({
    required this.decision,
    required this.child,
    required this.appLockController,
    this.onOpenPinSetup,
    this.onBackToSettings,
    this.onForgotPin,
    this.biometricAuthenticator,
    this.biometricEnabled = false,
    this.onResetPinWithBiometric,
    super.key,
  });

  /// 由 [AppLockBootstrapPolicy] 产生的启动决策。
  final AppLockBootstrapDecision decision;

  /// 决策通过时展示的子组件（即 App 正常内容）。
  final Widget child;

  /// 用于 [requireUnlock] 决策场景下，传给 [AppLockGate] 的控制器。
  ///
  /// **重要**：当 [decision] 为 [AppLockBootstrapDecision.requireUnlock] 时，
  /// 必须确保此 controller 的初始状态为 locked，否则 child 会被直接展示。
  final AppLockController appLockController;

  /// [AppLockRecoveryReason.pinMissingButEnabled] 场景中，
  /// 点击"重新设置 App PIN 原型"按钮的回调。
  final VoidCallback? onOpenPinSetup;

  /// 任意修复场景中，点击"返回应用锁设置"按钮的回调。
  final VoidCallback? onBackToSettings;
  final ValueChanged<BuildContext>? onForgotPin;
  final AppBiometricAuthenticator? biometricAuthenticator;
  final bool biometricEnabled;
  final Future<bool> Function(BuildContext)? onResetPinWithBiometric;

  @override
  Widget build(BuildContext context) {
    switch (decision) {
      // 开发验证阶段网关未显式开启，直接透传 child。
      case AppLockBootstrapDecision.disabledForDev:
        return child;

      // 启动已放行或要求解锁时，统一监听后续的锁定状态。
      case AppLockBootstrapDecision.unlockedForPrototype:
      case AppLockBootstrapDecision.requireUnlock:
        return AppLockGate(
          controller: appLockController,
          onOpenPinSetup: onOpenPinSetup,
          onForgotPin: onForgotPin,
          biometricAuthenticator: biometricAuthenticator,
          biometricEnabled: biometricEnabled,
          onResetPinWithBiometric: onResetPinWithBiometric,
          child: child,
        );

      // 应用锁已启用但 PIN 缺失，展示修复引导页，不直接进入锁屏。
      case AppLockBootstrapDecision.requireSetup:
        return ScreenProtectionScope(
          child: AppLockRecoveryPage(
            reason: AppLockRecoveryReason.pinMissingButEnabled,
            onOpenPinSetup: onOpenPinSetup,
            onBackToSettings: onBackToSettings,
          ),
        );

      // 配置读取异常（预留状态），展示安全阻断页，不执行任何修复操作。
      case AppLockBootstrapDecision.configurationError:
        return ScreenProtectionScope(
          child: AppLockRecoveryPage(
            reason: AppLockRecoveryReason.configurationError,
            onBackToSettings: onBackToSettings,
          ),
        );
    }
  }
}
