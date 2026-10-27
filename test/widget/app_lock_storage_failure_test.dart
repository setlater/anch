@Tags(['security'])
library;

import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_attempt_manager.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('冷却期间数字键盘禁用，生物识别仍可点击', (tester) async {
    final controller = AppLockController(
      initialState: AppLockState(
        status: AppLockStatus.temporarilyLocked,
        failedAttempts: 5,
        lockedUntilMillis: DateTime.now().millisecondsSinceEpoch + 300000,
      ),
    );
    addTearDown(controller.dispose);
    final biometric = _Biometric();
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockPage(
          controller: controller,
          biometricEnabled: true,
          biometricAuthenticator: biometric,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 首次自动调起被取消后，冷却期间仍能主动再次验证。
    biometric.result = AppBiometricResult.success;
    await tester.tap(find.byKey(const Key('pin_biometric')));
    await tester.pumpAndSettle();
    expect(biometric.calls, 2);
    expect(controller.value.status, AppLockStatus.unlocked);
  });

  testWidgets('存储失败显示可理解反馈，不误报 PIN 错误', (tester) async {
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      attemptManager: AppLockAttemptManager(_FailingStore()),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: AppLockPage(controller: controller)),
    );
    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(const Key('pin_digit_1')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('安全存储暂时不可用，请重新打开安册后再试'), findsOneWidget);
    expect(find.text('PIN 不正确'), findsNothing);
    expect(controller.value.canShowProtectedContent, isFalse);
  });
}

class _FailingStore extends MemorySecureKeyValueStore {
  @override
  Future<void> write(String key, String value) async {
    throw StateError('TEST storage unavailable');
  }
}

class _Biometric implements AppBiometricAuthenticator {
  int calls = 0;
  AppBiometricResult result = AppBiometricResult.cancelled;

  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  @override
  Future<AppBiometricResult> authenticate() async {
    calls++;
    return result;
  }

  @override
  Future<void> cancel() async {}
}
