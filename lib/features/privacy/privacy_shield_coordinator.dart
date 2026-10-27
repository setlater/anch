import 'package:anch/core/security/privacy_shield_policy.dart';
import 'package:anch/core/security/privacy_shield_signal.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';

/// 页面级防窥策略协调器。
///
/// 职责：
/// 接收来自页面的 [PrivacyShieldSignal]，使用 [PrivacyShieldPolicy] 进行策略计算，
/// 并驱动 [PrivacyShieldController] 展现或隐藏 Flutter 遮罩。
class PrivacyShieldCoordinator {
  PrivacyShieldCoordinator({
    required this.controller,
    this.policy = const PrivacyShieldPolicy(),
    this.source = PrivacyShieldSource.manual,
  });

  /// 防窥遮罩控制器
  final PrivacyShieldController controller;

  /// 防窥策略评估器
  final PrivacyShieldPolicy policy;

  /// 防窥协调器默认的来源标识
  final PrivacyShieldSource source;

  /// 根据最新的页面信号更新防窥状态。
  ///
  /// 调用 [policy.evaluate] 评估当前的防窥等级。如果是 [PrivacyShieldLevel.none]，
  /// 则清除指定来源的防窥状态（[controller.clearSource]）；否则展现遮罩并标记指定来源为活动（[controller.show]）。
  /// 可通过 [source] 覆盖协调器默认绑定的来源。
  /// 返回计算得出的 [PrivacyShieldLevel]。
  PrivacyShieldLevel updateFromSignal(
    PrivacyShieldSignal signal, {
    PrivacyShieldSource? source,
  }) {
    final actualSource = source ?? this.source;
    final level = policy.evaluate(
      hasVisibleSensitiveField: signal.hasVisibleSensitiveField,
      isEnteringPin: signal.isEnteringPin,
      isEnteringBackupPassword: signal.isEnteringBackupPassword,
      isAppLocked: signal.isAppLocked,
      isRestoreConfirming: signal.isRestoreConfirming,
    );

    if (level == PrivacyShieldLevel.none) {
      controller.clearSource(actualSource);
    } else {
      controller.show(actualSource);
    }

    return level;
  }

  /// 清除指定来源的防窥状态，默认为绑定来源。
  void clear({PrivacyShieldSource? source}) {
    controller.clearSource(source ?? this.source);
  }

  /// 清空所有来源的防窥状态。
  void clearAll() {
    controller.clearAll();
  }
}
