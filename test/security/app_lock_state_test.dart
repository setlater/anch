@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_state.dart';

void main() {
  group('AppLockState 单元测试', () {
    test('验证 1. disabledForDev 状态的属性表现', () {
      const state = AppLockState(status: AppLockStatus.disabledForDev);
      expect(state.canShowProtectedContent, isTrue);
      expect(state.isLockedLike, isFalse);
    });

    test('验证 2. unlocked 状态的属性表现', () {
      const state = AppLockState(status: AppLockStatus.unlocked);
      expect(state.canShowProtectedContent, isTrue);
      expect(state.isLockedLike, isFalse);
    });

    test('验证 3. locked 状态的属性表现', () {
      const state = AppLockState(status: AppLockStatus.locked);
      expect(state.canShowProtectedContent, isFalse);
      expect(state.isLockedLike, isTrue);
    });

    test('验证 4. temporarilyLocked 状态的属性表现', () {
      const state = AppLockState(status: AppLockStatus.temporarilyLocked);
      expect(state.canShowProtectedContent, isFalse);
      expect(state.isLockedLike, isTrue);
    });

    test('验证 5. unconfigured 状态的属性表现', () {
      const state = AppLockState(status: AppLockStatus.unconfigured);
      expect(state.canShowProtectedContent, isFalse);
      expect(state.isLockedLike, isTrue);
    });

    test('验证 6. toString 方法不应输出敏感密码', () {
      const state = AppLockState(status: AppLockStatus.locked);
      final str = state.toString();
      expect(str, contains('status: AppLockStatus.locked'));
      expect(str, isNot(contains('pin')));
      expect(str, isNot(contains('PIN')));
    });
  });
}
