@Tags(['security'])
library;

import 'dart:async';

import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_attempt_manager.dart';
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';
import 'package:anch/core/security/app_lock_bootstrap_service.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fakes.dart';

void main() {
  for (final raw in [
    '',
    '{}',
    '{',
    '{"version":1,"failedAttempts":-1}',
    '{"version":1,"failedAttempts":5}',
    '{"version":1,"failedAttempts":5,"lockedUntilMillis":"invalid"}',
  ]) {
    test('损坏的冷却记录阻断启动，不回退为零次失败（${raw.length}）', () async {
      final store = MemorySecureKeyValueStore();
      await store.write(AppLockAttemptManager.settingsKey, raw);
      final result = await AppLockBootstrapService(
        appPinManager: FakeAppPinManager(hasPinOverride: true),
        appLockSettingsManager: FakeAppLockSettingsManager(enabled: true),
        attemptManager: AppLockAttemptManager(store),
      ).bootstrap(appLockGateExplicitlyEnabled: true);
      expect(result.decision, AppLockBootstrapDecision.configurationError);
      expect(result.initialState.canShowProtectedContent, isFalse);
    });
  }

  test('写入失败时不执行 PIN 校验，保持锁定', () async {
    final pin = _CountingPinManager();
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      attemptManager: AppLockAttemptManager(_FailingStore()),
      appPinManager: pin,
    );
    addTearDown(controller.dispose);
    expect(await controller.unlockWithPin('123456'), isFalse);
    expect(pin.calls, 0);
    expect(controller.value.canShowProtectedContent, isFalse);
    expect(controller.pinStorageUnavailable, isTrue);
    expect(await controller.unlockWithPin('123456'), isFalse);
    expect(pin.calls, 0);
    expect(
      await controller.unlockWithBiometric(_SuccessfulBiometric()),
      AppBiometricResult.success,
    );
    expect(controller.value.canShowProtectedContent, isTrue);
  });

  test('冷却记录读取失败时阻断启动和 PIN 校验', () async {
    final manager = AppLockAttemptManager(_ReadFailingStore());
    final pin = _CountingPinManager();
    final result = await AppLockBootstrapService(
      appPinManager: FakeAppPinManager(hasPinOverride: true),
      appLockSettingsManager: FakeAppLockSettingsManager(enabled: true),
      attemptManager: manager,
    ).bootstrap(appLockGateExplicitlyEnabled: true);
    expect(result.decision, AppLockBootstrapDecision.configurationError);
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      attemptManager: manager,
      appPinManager: pin,
    );
    addTearDown(controller.dispose);
    expect(await controller.unlockWithPin('123456'), isFalse);
    expect(pin.calls, 0);
    expect(controller.pinStorageUnavailable, isTrue);
  });

  test('PIN 校验尚未完成时，重建控制器仍保留本次尝试', () async {
    final store = MemorySecureKeyValueStore();
    final manager = AppLockAttemptManager(store);
    final pin = _CountingPinManager()..pending = Completer<bool>();
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      attemptManager: manager,
      appPinManager: pin,
    );
    addTearDown(controller.dispose);
    final unlock = controller.unlockWithPin('000000', nowMillis: 1000);
    await pin.started.future;
    expect(await controller.unlockWithPin('000000', nowMillis: 1000), isFalse);
    final reserved = await AppLockAttemptManager(store).load();
    pin.pending!.complete(false);
    expect(await unlock, isFalse);
    expect(reserved.failedAttempts, 1);
  });
}

class _ReadFailingStore extends MemorySecureKeyValueStore {
  @override
  Future<String?> read(String key) async {
    throw StateError('TEST storage unavailable');
  }
}

class _SuccessfulBiometric implements AppBiometricAuthenticator {
  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  @override
  Future<AppBiometricResult> authenticate() async => AppBiometricResult.success;

  @override
  Future<void> cancel() async {}
}

class _FailingStore extends MemorySecureKeyValueStore {
  @override
  Future<void> write(String key, String value) async {
    throw StateError('TEST storage unavailable');
  }
}

class _CountingPinManager extends FakeAppPinManager {
  int calls = 0;
  Completer<bool>? pending;
  final started = Completer<void>();

  @override
  Future<bool> verifyPin(String pin) async {
    calls++;
    started.complete();
    return pending?.future ?? true;
  }
}
