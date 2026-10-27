@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';

void main() {
  group('AnchSecurityRuntimeConfig 单元测试', () {
    test(
      '1. 默认环境 (无 ANCH_SECURITY_MODE 环境变量)：解析为 mode=dev，全部能力默认为 false，且非阻断',
      () {
        final config = AnchSecurityRuntimeConfig.fromRawEnvironment({});
        expect(config.mode, AnchSecurityMode.dev);
        expect(config.useEncryptedDatabase, isFalse);
        expect(config.enableAppLockGate, isFalse);
        expect(config.enableSecureWindow, isFalse);
        expect(config.enablePrivacyShieldOverlay, isFalse);
        expect(config.isFormalBlocked, isFalse);
        expect(config.blockedReason, isNull);
      },
    );

    test('2. 旧开关兼容：在未指定模式或指定 dev 模式下，旧环境变量开关能正常启用对应安全验证功能', () {
      final env = {
        'ANCH_USE_ENCRYPTED_DB': 'true',
        'ANCH_ENABLE_APP_LOCK_GATE': 'true',
        'ANCH_ENABLE_SECURE_WINDOW': 'true',
        'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': 'true',
      };
      final configDefault = AnchSecurityRuntimeConfig.fromRawEnvironment(env);
      expect(configDefault.mode, AnchSecurityMode.dev);
      expect(configDefault.useEncryptedDatabase, isTrue);
      expect(configDefault.enableAppLockGate, isTrue);
      expect(configDefault.enableSecureWindow, isTrue);
      expect(configDefault.enablePrivacyShieldOverlay, isTrue);

      final envDev = {
        'ANCH_SECURITY_MODE': 'dev',
        'ANCH_USE_ENCRYPTED_DB': 'true',
        'ANCH_ENABLE_APP_LOCK_GATE': 'true',
        'ANCH_ENABLE_SECURE_WINDOW': 'true',
        'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': 'true',
      };
      final configDev = AnchSecurityRuntimeConfig.fromRawEnvironment(envDev);
      expect(configDev.mode, AnchSecurityMode.dev);
      expect(configDev.useEncryptedDatabase, isTrue);
      expect(configDev.enableAppLockGate, isTrue);
      expect(configDev.enableSecureWindow, isTrue);
      expect(configDev.enablePrivacyShieldOverlay, isTrue);
    });

    test('3. encryptedValidation 模式：默认仅启用加密数据库，其他安全能力默认为 false，但允许旧开关开启', () {
      final env1 = {'ANCH_SECURITY_MODE': 'encryptedValidation'};
      final config1 = AnchSecurityRuntimeConfig.fromRawEnvironment(env1);
      expect(config1.mode, AnchSecurityMode.encryptedValidation);
      expect(config1.useEncryptedDatabase, isTrue);
      expect(config1.enableAppLockGate, isFalse);
      expect(config1.enableSecureWindow, isFalse);
      expect(config1.enablePrivacyShieldOverlay, isFalse);

      final env2 = {
        'ANCH_SECURITY_MODE': 'encryptedValidation',
        'ANCH_ENABLE_APP_LOCK_GATE': 'true',
        'ANCH_ENABLE_SECURE_WINDOW': 'true',
      };
      final config2 = AnchSecurityRuntimeConfig.fromRawEnvironment(env2);
      expect(config2.mode, AnchSecurityMode.encryptedValidation);
      expect(config2.useEncryptedDatabase, isTrue);
      expect(config2.enableAppLockGate, isTrue);
      expect(config2.enableSecureWindow, isTrue);
      expect(config2.enablePrivacyShieldOverlay, isFalse);
    });

    test('4. securityValidation 模式：全安全链路显式验证模式，强制所有开关为 true，且不受旧开关降级影响', () {
      final env = {
        'ANCH_SECURITY_MODE': 'securityValidation',
        'ANCH_USE_ENCRYPTED_DB': 'false',
        'ANCH_ENABLE_APP_LOCK_GATE': 'false',
        'ANCH_ENABLE_SECURE_WINDOW': 'false',
        'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': 'false',
      };
      final config = AnchSecurityRuntimeConfig.fromRawEnvironment(env);
      expect(config.mode, AnchSecurityMode.securityValidation);
      expect(config.useEncryptedDatabase, isTrue);
      expect(config.enableAppLockGate, isTrue);
      expect(config.enableSecureWindow, isTrue);
      expect(config.enablePrivacyShieldOverlay, isTrue);
    });

    test('5. formal 模式强制启用完整安全链路，且不能被旧开关降级', () {
      final env = {
        'ANCH_SECURITY_MODE': 'formal',
        'ANCH_USE_ENCRYPTED_DB': 'false',
        'ANCH_ENABLE_APP_LOCK_GATE': 'false',
        'ANCH_ENABLE_SECURE_WINDOW': 'false',
        'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': 'false',
        'ANCH_ENABLE_AUTO_FILL': 'true',
      };
      final config = AnchSecurityRuntimeConfig.fromRawEnvironment(env);
      expect(config.mode, AnchSecurityMode.formal);
      expect(config.useEncryptedDatabase, isTrue);
      expect(config.enableAppLockGate, isTrue);
      expect(config.enableSecureWindow, isTrue);
      expect(config.enablePrivacyShieldOverlay, isTrue);
      expect(config.enableAutoFillScaffold, isFalse);
      expect(config.isFormalBlocked, isFalse);
      expect(config.blockedReason, isNull);
    });

    test('6. 未识别 mode 必须阻断，不能静默降级进入开发路径', () {
      final env = {
        'ANCH_SECURITY_MODE': 'unknownMode123',
        'ANCH_USE_ENCRYPTED_DB': 'true',
      };
      final config = AnchSecurityRuntimeConfig.fromRawEnvironment(env);
      expect(config.mode, AnchSecurityMode.dev);
      expect(config.useEncryptedDatabase, isTrue);
      expect(config.isFormalBlocked, isTrue);
      expect(config.blockedReason, isNotNull);
      expect(config.blockedReason, contains('unknown security mode'));
      // 绝对不可泄露环境密钥或敏感细节
      expect(config.blockedReason, isNot(contains('databaseKey')));
      expect(config.blockedReason, isNot(contains('PIN')));
    });

    test('7. Release 无论是否遗漏或拼错编译参数，都只能进入完整正式安全模式', () {
      for (final mode in [
        '',
        'dev',
        'encryptedValidation',
        'securityValidation',
        'formal',
        'unknownMode123',
      ]) {
        final config = AnchSecurityRuntimeConfig.fromRawEnvironment({
          'ANCH_SECURITY_MODE': mode,
          'ANCH_USE_ENCRYPTED_DB': 'false',
          'ANCH_ENABLE_APP_LOCK_GATE': 'false',
          'ANCH_ENABLE_SECURE_WINDOW': 'false',
          'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': 'false',
          'ANCH_ENABLE_AUTO_FILL': 'true',
        }, isReleaseBuild: true);
        expect(config.mode, AnchSecurityMode.formal);
        expect(config.useEncryptedDatabase, isTrue);
        expect(config.enableAppLockGate, isTrue);
        expect(config.enableSecureWindow, isTrue);
        expect(config.enablePrivacyShieldOverlay, isTrue);
        expect(config.enableAutoFillScaffold, isFalse);
        expect(config.isFormalBlocked, isFalse);
        expect(config.blockedReason, isNull);
      }
    });

    test('8. toString 脱敏验证：确保其仅输出模式和布尔能力，绝不含密钥、PIN、salt、路径等敏感字段', () {
      final config = AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.securityValidation,
        useEncryptedDatabase: true,
        enableAppLockGate: true,
        enableSecureWindow: true,
        enablePrivacyShieldOverlay: true,
        isFormalBlocked: false,
        blockedReason: 'some-reason',
      );
      final logStr = config.toString();

      // 应当能够正确输出模式与能力状态
      expect(logStr, contains('securityValidation'));
      expect(logStr, contains('useEncryptedDatabase: true'));
      expect(logStr, contains('enableAppLockGate: true'));

      // 严禁包含高危敏感词汇或可能的实值
      final forbiddenWords = [
        'pin',
        'PIN',
        'salt',
        'verifier',
        'databaseKey',
        'dbKey',
        'key',
        'Key',
        'backupPassword',
        'secureStorage',
        'keystore',
        'keychain',
        'app_encrypted_dev.db',
        '/data/data',
        '/Users/',
        '/home/',
        'C:\\',
      ];
      for (final word in forbiddenWords) {
        expect(
          logStr.contains(word),
          isFalse,
          reason: 'toString 中包含敏感词汇: $word',
        );
      }
    });
  });
}
