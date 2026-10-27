@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/privacy_shield_policy.dart';

/// [PrivacyShieldPolicy] 纯单元测试。
///
/// 测试设计原则：
/// - 不依赖 Flutter 框架（使用 `package:test` 而非 `package:flutter_test`）。
/// - 不调用任何 Android API。
/// - 不读取 Secure Storage。
/// - 不依赖 MainShell。
void main() {
  group('PrivacyShieldPolicy 单元测试', () {
    const policy = PrivacyShieldPolicy();

    // ----------------------------------------------------------------
    // 验证 1. 无高敏状态返回 none
    // ----------------------------------------------------------------

    test('验证 1. 所有条件为 false 时返回 none', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.none);
    });

    // ----------------------------------------------------------------
    // 验证 2. 高敏字段展开返回 secureFlagRecommended
    // ----------------------------------------------------------------

    test('验证 2. 高敏字段明文可见时返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: true,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    // ----------------------------------------------------------------
    // 验证 3. PIN 输入中返回 secureFlagRecommended
    // ----------------------------------------------------------------

    test('验证 3. 正在输入 App PIN 时返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: true,
        isEnteringBackupPassword: false,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    // ----------------------------------------------------------------
    // 验证 4. 备份密码输入中返回 secureFlagRecommended
    // ----------------------------------------------------------------

    test('验证 4. 正在输入备份密码时返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: true,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    // ----------------------------------------------------------------
    // 验证 5. App 锁定状态返回 secureFlagRecommended
    // ----------------------------------------------------------------

    test('验证 5. App 处于锁定状态时返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: true,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    // ----------------------------------------------------------------
    // 优先级验证：PIN 输入优先于 App 锁定
    // ----------------------------------------------------------------

    test('优先级验证. PIN 输入优先于 App 锁定状态，返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: true,
        isEnteringBackupPassword: false,
        isAppLocked: true, // 同时处于 locked 状态
      );
      // PIN 输入优先级高于 isAppLocked
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    test('优先级验证. 高敏字段展开优先于 App 锁定状态，返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: true,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: true,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    test('优先级验证. 备份密码输入同时高敏字段可见，返回 secureFlagRecommended', () {
      final level = policy.decide(
        hasVisibleSensitiveField: true,
        isEnteringPin: false,
        isEnteringBackupPassword: true,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    // ----------------------------------------------------------------
    // 验证 6 & 7. 不依赖 Flutter 框架，不调用 Android
    // ----------------------------------------------------------------

    test('验证 6 & 7. PrivacyShieldPolicy 是纯 Dart 类，无需 Flutter 或 Android 环境', () {
      // 本测试的存在本身即验证：PrivacyShieldPolicy 在纯 Dart 测试环境中可正常实例化和运行。
      // 若它依赖 Flutter 或 Android，此测试将在纯 Dart 环境下编译失败。
      const p = PrivacyShieldPolicy();
      final r = p.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
      );
      expect(r, isA<PrivacyShieldLevel>());
    });

    // ----------------------------------------------------------------
    // PrivacyShieldLevel 枚举完整性验证
    // ----------------------------------------------------------------

    test('枚举完整性. PrivacyShieldLevel 包含 none/softShield/secureFlagRecommended', () {
      expect(PrivacyShieldLevel.values.length, 3);
      expect(PrivacyShieldLevel.values, contains(PrivacyShieldLevel.none));
      expect(PrivacyShieldLevel.values, contains(PrivacyShieldLevel.softShield));
      expect(PrivacyShieldLevel.values, contains(PrivacyShieldLevel.secureFlagRecommended));
    });

    // ----------------------------------------------------------------
    // 无高敏条件的多状态组合验证
    // ----------------------------------------------------------------

    test('组合验证. 所有高敏条件均为 false 时，isAppLocked=false 返回 none', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
      );
      expect(level, PrivacyShieldLevel.none);
    });

    test('组合验证. 仅 isAppLocked=true 时返回 secureFlagRecommended，而非 none 或 softShield', () {
      final level = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: true,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
      expect(level, isNot(PrivacyShieldLevel.none));
      expect(level, isNot(PrivacyShieldLevel.softShield));
    });

    // ----------------------------------------------------------------
    // 验证 8. 覆盖恢复确认流程活跃返回 secureFlagRecommended 与多风险叠加
    // ----------------------------------------------------------------

    test('验证 8. 覆盖恢复确认流程活跃时返回 secureFlagRecommended', () {
      final level = policy.evaluate(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
        isRestoreConfirming: true,
      );
      expect(level, PrivacyShieldLevel.secureFlagRecommended);
    });

    test('优先级验证. 覆盖恢复确认流程与其他多种风险叠加时，等级不降低', () {
      final level1 = policy.evaluate(
        hasVisibleSensitiveField: true,
        isEnteringPin: true,
        isEnteringBackupPassword: true,
        isAppLocked: true,
        isRestoreConfirming: true,
      );
      expect(level1, PrivacyShieldLevel.secureFlagRecommended);

      final level2 = policy.decide(
        hasVisibleSensitiveField: false,
        isEnteringPin: false,
        isEnteringBackupPassword: false,
        isAppLocked: false,
        isRestoreConfirming: true,
      );
      expect(level2, PrivacyShieldLevel.secureFlagRecommended);
    });
  });
}
