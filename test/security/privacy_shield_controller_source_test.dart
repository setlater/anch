@Tags(['security'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';

void main() {
  group('PrivacyShieldController 多来源状态控制测试', () {
    test('1. 初始状态下无活动来源，isVisible 为 false', () {
      final controller = PrivacyShieldController();
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });

    test('2. 初始 state initialVisible=true 时应默认为 manual 来源', () {
      final controller = PrivacyShieldController(initialVisible: true);
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, contains(PrivacyShieldSource.manual));
    });

    test('3. show() 和 hide() 默认以 manual 来源工作且能正确流转', () {
      final controller = PrivacyShieldController();
      controller.show();
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.manual});

      controller.hide();
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });

    test('4. 多来源 show() 累加，activeSources 包含全部，isVisible 为 true', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.itemDetail);
      controller.show(PrivacyShieldSource.lifecycle);

      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {
        PrivacyShieldSource.itemDetail,
        PrivacyShieldSource.lifecycle,
      });
    });

    test('5. 移除部分活跃来源后，其余仍活跃的来源应保持 isVisible 为 true', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.itemDetail);
      controller.show(PrivacyShieldSource.lifecycle);

      controller.hide(PrivacyShieldSource.itemDetail);
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.lifecycle});
    });

    test('6. 移除全部来源后，isVisible 变为 false', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.itemDetail);
      controller.show(PrivacyShieldSource.lifecycle);

      controller.hide(PrivacyShieldSource.itemDetail);
      controller.hide(PrivacyShieldSource.lifecycle);
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });

    test('系统文件选择器往返期间不展示生命周期遮罩，结束后恢复', () async {
      final controller = PrivacyShieldController();
      final pendingResult = Completer<void>();
      final guarded = controller.runWhileLifecycleShieldSuppressed(() async {
        await pendingResult.future;
      });

      controller.showForLifecycle();
      expect(controller.isVisible, isFalse);
      expect(controller.isLifecycleShieldSuppressed, isTrue);

      pendingResult.complete();
      await guarded;
      expect(controller.isLifecycleShieldSuppressed, isFalse);

      controller.showForLifecycle();
      expect(controller.activeSources, {PrivacyShieldSource.lifecycle});
    });

    test('7. clearSource 可以精准清除对应来源', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.appLockInput);
      controller.show(PrivacyShieldSource.appPinSetup);

      controller.clearSource(PrivacyShieldSource.appLockInput);
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.appPinSetup});
    });

    test('8. clearAll() 可以清空所有活跃来源', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.backupExport);
      controller.show(PrivacyShieldSource.backupRestore);

      controller.clearAll();
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });

    test('9. clear() 能够向下兼容清除所有来源', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.restoreConfirming);

      controller.clear();
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });

    test('10. toString() 脱敏且不输出任何凭证和内容', () {
      final controller = PrivacyShieldController();
      controller.show(PrivacyShieldSource.itemDetail);

      final str = controller.toString();
      expect(str, contains('PrivacyShieldController'));
      expect(str, contains('isVisible: true'));
      expect(str, contains('activeSources: [itemDetail]'));

      // ⚠️ 【安全防线】绝不包含敏感字眼或密码标记
      expect(str, isNot(contains('PIN')));
      expect(str, isNot(contains('password')));
      expect(str, isNot(contains('databaseKey')));
    });
  });
}
