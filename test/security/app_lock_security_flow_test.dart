@Tags(['security'])
library;

import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_attempt_manager.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'dart:convert';

import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('应用锁模式安全持久化，旧超时偏好安全收紧为每次回到安册', () async {
    final store = MemorySecureKeyValueStore();
    final manager = AppLockPreferencesManager(store);
    await manager.setBiometricEnabled(true);
    await manager.setAutoLockMode(AppLockAutoLockMode.nextLaunch);

    final preferences = await manager.load();
    expect(preferences.biometricEnabled, isTrue);
    expect(preferences.autoLockMode, AppLockAutoLockMode.nextLaunch);

    await store.write(
      AppLockPreferencesManager.settingsKey,
      jsonEncode({
        'version': 1,
        'biometricEnabled': true,
        'backgroundTimeoutMillis': 300000,
      }),
    );
    final migrated = await manager.load();
    expect(migrated.biometricEnabled, isTrue);
    expect(migrated.autoLockMode, AppLockAutoLockMode.everyForeground);
  });

  test('PIN 连续失败的冷却状态跨控制器持久化', () async {
    final attempts = AppLockAttemptManager(MemorySecureKeyValueStore());
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      attemptManager: attempts,
      prototypePin: '123456',
    );

    for (var index = 0; index < 5; index++) {
      await controller.unlockWithPin('000000', nowMillis: 1000);
    }

    final persisted = await attempts.load();
    expect(persisted.failedAttempts, 5);
    expect(persisted.lockedUntilMillis, 31000);
  });

  test('PIN 冷却期间仍允许强生物识别解锁', () async {
    final controller = AppLockController(
      initialState: const AppLockState(
        status: AppLockStatus.temporarilyLocked,
        failedAttempts: 5,
        lockedUntilMillis: 999999,
      ),
    );

    final result = await controller.unlockWithBiometric(
      _FakeBiometricAuthenticator(AppBiometricResult.success),
      nowMillis: 2000,
    );

    expect(result, AppBiometricResult.success);
    expect(controller.value.status, AppLockStatus.unlocked);
    expect(controller.value.failedAttempts, 0);
  });
}

class _FakeBiometricAuthenticator implements AppBiometricAuthenticator {
  _FakeBiometricAuthenticator(this.result);

  final AppBiometricResult result;

  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  @override
  Future<AppBiometricResult> authenticate() async => result;

  @override
  Future<void> cancel() async {}
}
