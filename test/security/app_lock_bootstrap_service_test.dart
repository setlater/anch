@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';
import 'package:anch/core/security/app_lock_bootstrap_service.dart';
import 'package:anch/core/security/app_lock_state.dart';
import '../support/test_fakes.dart';


void main() {
  group('安册 AppLockBootstrapService 冷启动初始化服务测试', () {
    test('1. explicitGate=false：即使 enabled=true、hasPin=true，决策也为 disabledForDev 且状态为 disabledForDev', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: true);
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      final result = await service.bootstrap(appLockGateExplicitlyEnabled: false);

      expect(result.decision, AppLockBootstrapDecision.disabledForDev);
      expect(result.initialState.status, AppLockStatus.disabledForDev);
      expect(result.hasPin, isTrue);
      expect(result.enabled, isTrue);
    });

    test('2. explicitGate=true + enabled=false + hasPin=false：决策为 unlockedForPrototype 且状态为 unlocked', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: false);
      final settingsManager = FakeAppLockSettingsManager(enabled: false);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      final result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.unlockedForPrototype);
      expect(result.initialState.status, AppLockStatus.unlocked);
    });

    test('3. explicitGate=true + enabled=false + hasPin=true：决策为 unlockedForPrototype 且状态为 unlocked', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: true);
      final settingsManager = FakeAppLockSettingsManager(enabled: false);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      final result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.unlockedForPrototype);
      expect(result.initialState.status, AppLockStatus.unlocked);
    });

    test('4. explicitGate=true + enabled=true + hasPin=false：决策为 requireSetup 且状态为 unconfigured', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: false);
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      final result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.requireSetup);
      expect(result.initialState.status, AppLockStatus.unconfigured);
    });

    test('5. explicitGate=true + enabled=true + hasPin=true：决策为 requireUnlock 且状态为 locked', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: true);
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      final result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.requireUnlock);
      expect(result.initialState.status, AppLockStatus.locked);
    });

    test('6. appPinManager.hasPin 抛出异常：决策收敛为 configurationError 且状态为 unconfigured，不抛出原始异常，toString 满足严格脱敏', () async {
      final pinManager = FakeAppPinManager(throwOnHasPin: true);
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      // 验证不抛出异常并正常返回结果对象
      late AppLockBootstrapResult result;
      expect(() async {
        result = await service.bootstrap(appLockGateExplicitlyEnabled: true);
      }, returnsNormally);

      // 显式等待 bootstrap 完成以测试其结果
      result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.configurationError);
      expect(result.initialState.status, AppLockStatus.unconfigured);
      expect(result.hasPin, isFalse); // 异常时降级为 false

      // 验证 toString 脱敏性，决不能包含敏感调试词和底层异常细节
      final resultStr = result.toString().toLowerCase();
      expect(resultStr, isNot(contains('test-pin')));
      expect(resultStr, isNot(contains('salt')));
      expect(resultStr, isNot(contains('verifier')));
      expect(resultStr, isNot(contains('databasekey')));
      expect(resultStr, isNot(contains('exception')));
    });

    test('7. appLockSettingsManager.isAppLockEnabled 抛出异常：决策收敛为 configurationError 且状态为 unconfigured，不抛出原始异常', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: true);
      final settingsManager = FakeAppLockSettingsManager(throwOnIsEnabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      late AppLockBootstrapResult result;
      expect(() async {
        result = await service.bootstrap(appLockGateExplicitlyEnabled: true);
      }, returnsNormally);

      result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.configurationError);
      expect(result.initialState.status, AppLockStatus.unconfigured);
      expect(result.enabled, isFalse); // 异常时降级为 false
    });

    test('8. 两者均抛出异常：决策收敛为 configurationError 且状态为 unconfigured，不抛出原始异常', () async {
      final pinManager = FakeAppPinManager(throwOnHasPin: true);
      final settingsManager = FakeAppLockSettingsManager(throwOnIsEnabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      late AppLockBootstrapResult result;
      expect(() async {
        result = await service.bootstrap(appLockGateExplicitlyEnabled: true);
      }, returnsNormally);

      result = await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(result.decision, AppLockBootstrapDecision.configurationError);
      expect(result.initialState.status, AppLockStatus.unconfigured);
      expect(result.hasPin, isFalse);
      expect(result.enabled, isFalse);
    });

    test('9. bootstrap 只读 hasPin / enabled，不写任何 Secure Storage (无写操作)', () async {
      final pinManager = FakeAppPinManager(hasPinOverride: true);
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final service = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );

      await service.bootstrap(appLockGateExplicitlyEnabled: true);

      expect(pinManager.readCount, 1);
      expect(pinManager.writeCount, 0);

      expect(settingsManager.readCount, 1);
      expect(settingsManager.writeCount, 0);
    });
  });
}
