@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_lock_controller.dart';

void main() {
  group('AppLockController 单元测试 — Prototype 路径', () {
    test('验证 1. 默认状态为 disabledForDev', () {
      final controller = AppLockController();
      expect(controller.value.status, AppLockStatus.disabledForDev);
    });

    test('验证 2. lock 方法在 unlocked 状态下可以切回 locked', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      controller.lock();
      expect(controller.value.status, AppLockStatus.locked);
    });

    test('验证 3. unlockWithPrototypePin 同步校验正确与错误密码逻辑', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: 'TEST-1234',
      );

      // 错误密码
      final res1 = controller.unlockWithPrototypePin('WRONG');
      expect(res1, isFalse);
      expect(controller.value.status, AppLockStatus.locked);
      expect(controller.value.failedAttempts, 1);

      // 正确密码
      final res2 = controller.unlockWithPrototypePin('TEST-1234');
      expect(res2, isTrue);
      expect(controller.value.status, AppLockStatus.unlocked);
      expect(controller.value.failedAttempts, 0);
    });

    test('验证 4. 异步 unlockWithPin 在 prototype 模式下正常工作', () async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: 'TEST-1234',
      );

      final res1 = await controller.unlockWithPin('WRONG');
      expect(res1, isFalse);

      final res2 = await controller.unlockWithPin('TEST-1234');
      expect(res2, isTrue);
      expect(controller.value.status, AppLockStatus.unlocked);
    });

    test('验证 5. prototype 模式连续失败 5 次触发 temporarilyLocked 状态', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: 'TEST-1234',
        maxFailedAttempts: 5,
        temporaryLockMillis: 30000,
      );

      final now = 1000000;

      for (var i = 0; i < 4; i++) {
        expect(controller.unlockWithPrototypePin('WRONG', now), isFalse);
        expect(controller.value.status, AppLockStatus.locked);
      }

      // 第 5 次失败
      expect(controller.unlockWithPrototypePin('WRONG', now), isFalse);
      expect(controller.value.status, AppLockStatus.temporarilyLocked);
      expect(controller.value.failedAttempts, 5);
      expect(controller.value.lockedUntilMillis, now + 30000);
    });

    test('验证 6. disabledForDev 下 markForegrounded 不会锁定', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.disabledForDev),
      );
      controller.markBackgrounded(1000);
      controller.markForegrounded(40000, timeoutMillis: 30000);
      expect(controller.value.status, AppLockStatus.disabledForDev);
    });

    test('验证 7. unlocked 下后台超时锁定，未超时不锁定', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );

      // 未超时（后台停留 10 秒，超时阀值 30 秒）
      controller.markBackgrounded(100000);
      controller.markForegrounded(110000, timeoutMillis: 30000);
      expect(controller.value.status, AppLockStatus.unlocked);

      // 超时（后台停留 40 秒，超时阀值 30 秒）
      controller.markBackgrounded(200000);
      controller.markForegrounded(240000, timeoutMillis: 30000);
      expect(controller.value.status, AppLockStatus.locked);
    });

    test('验证 8. resetFailures 后 failedAttempts 归零', () {
      final controller = AppLockController(
        initialState: const AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: 3,
        ),
      );
      expect(controller.value.failedAttempts, 3);
      controller.resetFailures();
      expect(controller.value.failedAttempts, 0);
    });

    test('验证 9. configurePrototypeLockForTest 从 unconfigured 切到 locked', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unconfigured),
      );
      expect(controller.value.status, AppLockStatus.unconfigured);
      controller.configurePrototypeLockForTest();
      expect(controller.value.status, AppLockStatus.locked);
    });

    test(
      '验证 10. markConfiguredAndLocked 从 unconfigured 切到 locked 且重置 failedAttempts',
      () {
        final controller = AppLockController(
          initialState: const AppLockState(
            status: AppLockStatus.unconfigured,
            failedAttempts: 3,
          ),
        );
        expect(controller.value.status, AppLockStatus.unconfigured);
        expect(controller.value.failedAttempts, 3);
        controller.markConfiguredAndLocked();
        expect(controller.value.status, AppLockStatus.locked);
        expect(controller.value.failedAttempts, 0);
        expect(controller.value.lockedUntilMillis, isNull);
      },
    );
  });

  group('AppLockController 单元测试 — 真实 AppPinManager 路径', () {
    late MemorySecureKeyValueStore store;
    late SecureStorageAppPinManager pinManager;

    setUp(() async {
      store = MemorySecureKeyValueStore();
      pinManager = SecureStorageAppPinManager(store: store, iterations: 10);
      await pinManager.setPin('123456');
    });

    test('验证 1. 真实 PIN 校验解锁成功与失败计数流转', () async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: pinManager,
      );

      // 错误 PIN
      final res1 = await controller.unlockWithPin('wrong-pin');
      expect(res1, isFalse);
      expect(controller.value.status, AppLockStatus.locked);
      expect(controller.value.failedAttempts, 1);

      // 正确 PIN
      final res2 = await controller.unlockWithPin('123456');
      expect(res2, isTrue);
      expect(controller.value.status, AppLockStatus.unlocked);
      expect(controller.value.failedAttempts, 0);
    });

    test('验证 2. 真实路径下连续失败 5 次触发锁定且到期逻辑', () async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: pinManager,
        maxFailedAttempts: 5,
        temporaryLockMillis: 30000,
      );

      final now = 1000000;

      // 连续 5 次输错
      for (var i = 0; i < 5; i++) {
        final res = await controller.unlockWithPin('wrong-pin', nowMillis: now);
        expect(res, isFalse);
      }

      expect(controller.value.status, AppLockStatus.temporarilyLocked);
      expect(controller.value.failedAttempts, 5);
      expect(controller.value.lockedUntilMillis, now + 30000);

      // 锁定期间正确 PIN 不解锁
      final resCorrectDuringLock = await controller.unlockWithPin(
        '123456',
        nowMillis: now + 10000,
      );
      expect(resCorrectDuringLock, isFalse);
      expect(controller.value.status, AppLockStatus.temporarilyLocked);

      // 锁定到期，调用一次应该先返回 false 且切回 locked
      final resCorrectExpired = await controller.unlockWithPin(
        '123456',
        nowMillis: now + 35000,
      );
      expect(resCorrectExpired, isFalse);
      expect(controller.value.status, AppLockStatus.locked);
      expect(controller.value.failedAttempts, 0);

      // 再次输入正确 PIN 即可正常解锁
      final resFinal = await controller.unlockWithPin(
        '123456',
        nowMillis: now + 36000,
      );
      expect(resFinal, isTrue);
      expect(controller.value.status, AppLockStatus.unlocked);
    });

    test('验证 3. 存储异常发生时安全失败且不泄露信息', () async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: pinManager,
      );

      // 损坏 store 中的 verifier
      await store.write('anch.app_pin.verifier.v1', '!!!invalid-base64!!!');

      // 触发损坏校验
      final res = await controller.unlockWithPin('123456');
      expect(res, isFalse);
      expect(controller.value.status, AppLockStatus.locked);

      // 确保 toString 中不泄露任何测试密码信息
      final controllerStr = controller.toString();
      expect(controllerStr, isNot(contains('123456')));
    });

    test('验证 4. 真实路径下调用同步 unlockWithPrototypePin 直接返回 false', () {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: pinManager,
      );

      final res = controller.unlockWithPrototypePin('123456');
      expect(res, isFalse);
      expect(controller.value.status, AppLockStatus.locked);
    });
  });
}
