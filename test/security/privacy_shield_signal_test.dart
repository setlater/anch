@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/privacy_shield_signal.dart';

void main() {
  group('PrivacyShieldSignal 单元测试', () {
    test('1. 默认状态下无风险且各项为 false', () {
      const signal = PrivacyShieldSignal();
      expect(signal.hasVisibleSensitiveField, isFalse);
      expect(signal.isEnteringPin, isFalse);
      expect(signal.isEnteringBackupPassword, isFalse);
      expect(signal.isAppLocked, isFalse);
      expect(signal.isRestoreConfirming, isFalse);
      expect(signal.hasAnyRisk, isFalse);
    });

    test('2. hasVisibleSensitiveField=true 时 hasAnyRisk=true', () {
      const signal = PrivacyShieldSignal(hasVisibleSensitiveField: true);
      expect(signal.hasAnyRisk, isTrue);
    });

    test('3. isEnteringPin=true 时 hasAnyRisk=true', () {
      const signal = PrivacyShieldSignal(isEnteringPin: true);
      expect(signal.hasAnyRisk, isTrue);
    });

    test('4. isEnteringBackupPassword=true 时 hasAnyRisk=true', () {
      const signal = PrivacyShieldSignal(isEnteringBackupPassword: true);
      expect(signal.hasAnyRisk, isTrue);
    });

    test('5. isAppLocked=true 时 hasAnyRisk=true', () {
      const signal = PrivacyShieldSignal(isAppLocked: true);
      expect(signal.hasAnyRisk, isTrue);
    });

    test('6. isRestoreConfirming=true 时 hasAnyRisk=true', () {
      const signal = PrivacyShieldSignal(isRestoreConfirming: true);
      expect(signal.hasAnyRisk, isTrue);
    });

    test('7. toString 不输出任何敏感载荷与字段（例如 PIN、salt、verifier、databaseKey、TEST-sensitive-value 等）', () {
      const signal = PrivacyShieldSignal(
        hasVisibleSensitiveField: true,
        isEnteringPin: true,
        isEnteringBackupPassword: true,
        isAppLocked: true,
        isRestoreConfirming: true,
      );
      final str = signal.toString();

      // 验证它仅仅显示状态，不包含敏感单词
      expect(str, contains('PrivacyShieldSignal'));
      expect(str, contains('hasVisibleSensitiveField: true'));
      expect(str, contains('isEnteringPin: true'));
      expect(str, contains('isEnteringBackupPassword: true'));
      expect(str, contains('isAppLocked: true'));
      expect(str, contains('isRestoreConfirming: true'));

      // 绝不包含敏感信息和明文相关的关键字
      expect(str, isNot(contains('TEST-sensitive-value')));
      expect(str, isNot(contains('PIN')));
      expect(str, isNot(contains('salt')));
      expect(str, isNot(contains('verifier')));
      expect(str, isNot(contains('databaseKey')));
      expect(str, isNot(contains('password'))); // 备份密码本身是 bool isEnteringBackupPassword，字符串中是该字段名，我们可以不输出实际密码
    });
  });
}
