@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';

void main() {
  group('AppLockBootstrapPolicy 纯计算单元测试', () {
    const policy = AppLockBootstrapPolicy();

    test('验证 1. 当 gate 未被显式开启时，无论 hasPin 与 enabled 状态如何，都直接返回 disabledForDev', () {
      final res1 = policy.decide(appLockGateExplicitlyEnabled: false, enabled: false, hasPin: false);
      expect(res1, AppLockBootstrapDecision.disabledForDev);

      final res2 = policy.decide(appLockGateExplicitlyEnabled: false, enabled: true, hasPin: false);
      expect(res2, AppLockBootstrapDecision.disabledForDev);

      final res3 = policy.decide(appLockGateExplicitlyEnabled: false, enabled: true, hasPin: true);
      expect(res3, AppLockBootstrapDecision.disabledForDev);
    });

    test('验证 2. 当 gate 已开启但 enabled 为 false 时，返回 unlockedForPrototype', () {
      final res1 = policy.decide(appLockGateExplicitlyEnabled: true, enabled: false, hasPin: false);
      expect(res1, AppLockBootstrapDecision.unlockedForPrototype);

      final res2 = policy.decide(appLockGateExplicitlyEnabled: true, enabled: false, hasPin: true);
      expect(res2, AppLockBootstrapDecision.unlockedForPrototype);
    });

    test('验证 3. 当 gate 已开启、enabled 为 true，但 hasPin 为 false，属于配置缺失异常，返回 requireSetup', () {
      final res = policy.decide(appLockGateExplicitlyEnabled: true, enabled: true, hasPin: false);
      expect(res, AppLockBootstrapDecision.requireSetup);
    });

    test('验证 4. 当 gate 已开启、enabled 为 true 且 hasPin 为 true，返回 requireUnlock 引导正常锁屏', () {
      final res = policy.decide(appLockGateExplicitlyEnabled: true, enabled: true, hasPin: true);
      expect(res, AppLockBootstrapDecision.requireUnlock);
    });

    test('验证 5. configurationError 枚举值的预留校验与文档对齐', () {
      // 确认配置错误枚举值存在且能够正常打印
      const errDecision = AppLockBootstrapDecision.configurationError;
      expect(errDecision.toString(), contains('configurationError'));
    });

    test(
      '验证 6. [预留状态确认] configurationError 目前不由布尔策略返回，'
      '策略只处理 hasPin/enabled/appLockGateExplicitlyEnabled 三个布尔值；'
      '如需测试 configurationError 场景，应直接构造 AppLockBootstrapDecision.configurationError，'
      '不应修改本策略类来返回该状态',
      () {
        // 策略所有可能的布尔组合均不返回 configurationError
        final allCombinations = [
          (gate: false, enabled: false, hasPin: false),
          (gate: false, enabled: false, hasPin: true),
          (gate: false, enabled: true, hasPin: false),
          (gate: false, enabled: true, hasPin: true),
          (gate: true, enabled: false, hasPin: false),
          (gate: true, enabled: false, hasPin: true),
          (gate: true, enabled: true, hasPin: false),
          (gate: true, enabled: true, hasPin: true),
        ];

        for (final combo in allCombinations) {
          final result = policy.decide(
            appLockGateExplicitlyEnabled: combo.gate,
            enabled: combo.enabled,
            hasPin: combo.hasPin,
          );
          expect(
            result,
            isNot(AppLockBootstrapDecision.configurationError),
            reason: 'gate=${combo.gate}, enabled=${combo.enabled}, hasPin=${combo.hasPin} '
                '不应返回 configurationError（预留状态，本批策略不主动返回）',
          );
        }
      },
    );
  });
}
