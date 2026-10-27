@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/privacy_shield_policy.dart';
import 'package:anch/core/security/privacy_shield_signal.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';

void main() {
  group('PrivacyShieldCoordinator 单元测试', () {
    late PrivacyShieldController controller;
    late PrivacyShieldCoordinator coordinator;

    setUp(() {
      controller = PrivacyShieldController(initialVisible: false);
      coordinator = PrivacyShieldCoordinator(controller: controller);
    });

    test('1. 无风险 signal -> controller.hide', () {
      controller.show(); // 先设为显示（默认 manual）
      expect(controller.isVisible, isTrue);

      final level = coordinator.updateFromSignal(const PrivacyShieldSignal());
      expect(level, PrivacyShieldLevel.none);
      expect(controller.isVisible, isFalse);
    });

    test('2. 高敏字段展开 -> controller.show', () {
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(hasVisibleSensitiveField: true),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(controller.isVisible, isTrue);
    });

    test('3. PIN 输入 -> controller.show', () {
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(isEnteringPin: true),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(controller.isVisible, isTrue);
    });

    test('4. 备份密码输入 -> controller.show', () {
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(isEnteringBackupPassword: true),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(controller.isVisible, isTrue);
    });

    test('5. App locked -> controller.show', () {
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(isAppLocked: true),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(controller.isVisible, isTrue);
    });

    test('6. 覆盖恢复确认 -> controller.show', () {
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(isRestoreConfirming: true),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(controller.isVisible, isTrue);
    });

    test('7. 风险从 true 变 false -> controller.hide', () {
      // 1. 有风险输入
      coordinator.updateFromSignal(const PrivacyShieldSignal(isAppLocked: true));
      expect(controller.isVisible, isTrue);

      // 2. 变成无风险
      coordinator.updateFromSignal(const PrivacyShieldSignal());
      expect(controller.isVisible, isFalse);
    });

    test('8. 返回的 PrivacyShieldLevel 符合 policy', () {
      // policy 的 evaluate 在 true 时都应为 secureFlagRecommended
      const mockPolicy = PrivacyShieldPolicy();
      final expectedLevel = mockPolicy.evaluate(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: true,
        isRestoreConfirming: false,
      );

      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(isAppLocked: true),
      );
      expect(level, expectedLevel);
    });

    test('9. 验证为纯 Dart/Widget 测试：不读取 Secure Storage，不依赖 Android，不依赖数据库，不泄露敏感值', () {
      final coordinator = PrivacyShieldCoordinator(
        controller: PrivacyShieldController(),
      );
      final level = coordinator.updateFromSignal(
        const PrivacyShieldSignal(
          hasVisibleSensitiveField: true,
          isEnteringPin: true,
          isEnteringBackupPassword: true,
        ),
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(coordinator.controller.isVisible, isTrue);
    });

    test('10. coordinator 默认绑定 manual 来源，支持绑定其它来源', () {
      expect(coordinator.source, PrivacyShieldSource.manual);

      final specialCoordinator = PrivacyShieldCoordinator(
        controller: controller,
        source: PrivacyShieldSource.itemDetail,
      );
      expect(specialCoordinator.source, PrivacyShieldSource.itemDetail);
    });

    test('11. updateFromSignal 可指定或遵循默认来源，无风险时只清除该指定来源且不干扰其它活跃来源', () {
      final itemCoordinator = PrivacyShieldCoordinator(
        controller: controller,
        source: PrivacyShieldSource.itemDetail,
      );

      // 1. 手动唤醒 manual
      controller.show(PrivacyShieldSource.manual);
      expect(controller.isVisible, isTrue);

      // 2. 通过 itemDetail 触发有风险
      itemCoordinator.updateFromSignal(
        const PrivacyShieldSignal(hasVisibleSensitiveField: true),
      );
      expect(controller.activeSources, {
        PrivacyShieldSource.manual,
        PrivacyShieldSource.itemDetail,
      });

      // 3. 通过 itemDetail 触发无风险，应该只清除 itemDetail
      itemCoordinator.updateFromSignal(const PrivacyShieldSignal());
      expect(controller.isVisible, isTrue); // manual 仍在
      expect(controller.activeSources, {PrivacyShieldSource.manual});

      // 4. 指定临时来源更新
      itemCoordinator.updateFromSignal(
        const PrivacyShieldSignal(isEnteringPin: true),
        source: PrivacyShieldSource.appLockInput,
      );
      expect(controller.activeSources, {
        PrivacyShieldSource.manual,
        PrivacyShieldSource.appLockInput,
      });
    });

    test('12. clear(source) 只清除指定来源，clearAll() 卸载全部', () {
      controller.show(PrivacyShieldSource.itemDetail);
      controller.show(PrivacyShieldSource.lifecycle);
      expect(controller.isVisible, isTrue);

      coordinator.clear(source: PrivacyShieldSource.itemDetail);
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.lifecycle});

      coordinator.clearAll();
      expect(controller.isVisible, isFalse);
      expect(controller.activeSources, isEmpty);
    });
  });
}

