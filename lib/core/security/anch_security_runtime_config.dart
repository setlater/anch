import 'package:flutter/foundation.dart';

enum AnchSecurityMode { dev, encryptedValidation, securityValidation, formal }

/// 安全运行模式统一配置模型。
/// 收口散落在应用各处的 dart-define 开关读取，维护统一的安全校验状态。
class AnchSecurityRuntimeConfig {
  final AnchSecurityMode mode;
  final bool useEncryptedDatabase;
  final bool enableAppLockGate;
  final bool enableSecureWindow;
  final bool enablePrivacyShieldOverlay;
  final bool isFormalBlocked;
  final String? blockedReason;
  final bool enableAutoFillScaffold;

  const AnchSecurityRuntimeConfig({
    required this.mode,
    required this.useEncryptedDatabase,
    required this.enableAppLockGate,
    required this.enableSecureWindow,
    required this.enablePrivacyShieldOverlay,
    required this.isFormalBlocked,
    this.blockedReason,
    this.enableAutoFillScaffold = true,
  });

  /// 从 Dart 编译期环境变量中提取配置。
  factory AnchSecurityRuntimeConfig.fromEnvironment() {
    const modeStr = String.fromEnvironment(
      'ANCH_SECURITY_MODE',
      defaultValue: '',
    );
    const useEncDb = bool.fromEnvironment(
      'ANCH_USE_ENCRYPTED_DB',
      defaultValue: false,
    );
    const enableLock = bool.fromEnvironment(
      'ANCH_ENABLE_APP_LOCK_GATE',
      defaultValue: false,
    );
    const enableSecure = bool.fromEnvironment(
      'ANCH_ENABLE_SECURE_WINDOW',
      defaultValue: false,
    );
    const enablePrivacy = bool.fromEnvironment(
      'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY',
      defaultValue: false,
    );
    const enableAutoFill = bool.fromEnvironment(
      'ANCH_ENABLE_AUTO_FILL',
      defaultValue: true,
    );

    return AnchSecurityRuntimeConfig.fromRawEnvironment({
      'ANCH_SECURITY_MODE': modeStr,
      'ANCH_USE_ENCRYPTED_DB': useEncDb ? 'true' : 'false',
      'ANCH_ENABLE_APP_LOCK_GATE': enableLock ? 'true' : 'false',
      'ANCH_ENABLE_SECURE_WINDOW': enableSecure ? 'true' : 'false',
      'ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY': enablePrivacy ? 'true' : 'false',
      'ANCH_ENABLE_AUTO_FILL': enableAutoFill ? 'true' : 'false',
    }, isReleaseBuild: kReleaseMode);
  }

  /// 纯解析函数，为测试和 fromEnvironment 共享逻辑，排除对 fromEnvironment 的直接依赖。
  factory AnchSecurityRuntimeConfig.fromRawEnvironment(
    Map<String, String> env, {
    bool isReleaseBuild = false,
  }) {
    final requestedModeStr = env['ANCH_SECURITY_MODE']?.trim() ?? '';
    // Release 始终进入正式安全模式，不能因遗漏或拼错 dart-define 而降级。
    final modeStr = isReleaseBuild ? 'formal' : requestedModeStr;
    final rawUseEncryptedDb = env['ANCH_USE_ENCRYPTED_DB'] == 'true';
    final rawEnableAppLockGate = env['ANCH_ENABLE_APP_LOCK_GATE'] == 'true';
    final rawEnableSecureWindow = env['ANCH_ENABLE_SECURE_WINDOW'] == 'true';
    final rawEnablePrivacyShieldOverlay =
        env['ANCH_ENABLE_PRIVACY_SHIELD_OVERLAY'] == 'true';
    final rawEnableAutoFill = env['ANCH_ENABLE_AUTO_FILL'] != 'false';

    AnchSecurityMode mode;
    bool useEncryptedDatabase = false;
    bool enableAppLockGate = false;
    bool enableSecureWindow = false;
    bool enablePrivacyShieldOverlay = false;
    bool isFormalBlocked = false;
    String? blockedReason;
    bool enableAutoFillScaffold = false;

    switch (modeStr) {
      case 'formal':
        mode = AnchSecurityMode.formal;
        useEncryptedDatabase = true;
        enableAppLockGate = true;
        enableSecureWindow = true;
        enablePrivacyShieldOverlay = true;
        enableAutoFillScaffold = false;
        break;
      case 'securityValidation':
        mode = AnchSecurityMode.securityValidation;
        useEncryptedDatabase = true;
        enableAppLockGate = true;
        enableSecureWindow = true;
        enablePrivacyShieldOverlay = true;
        enableAutoFillScaffold = false;
        break;
      case 'encryptedValidation':
        mode = AnchSecurityMode.encryptedValidation;
        useEncryptedDatabase = true;
        enableAppLockGate = rawEnableAppLockGate;
        enableSecureWindow = rawEnableSecureWindow;
        enablePrivacyShieldOverlay = rawEnablePrivacyShieldOverlay;
        enableAutoFillScaffold = rawEnableAutoFill;
        break;
      case 'dev':
        mode = AnchSecurityMode.dev;
        useEncryptedDatabase = rawUseEncryptedDb;
        enableAppLockGate = rawEnableAppLockGate;
        enableSecureWindow = rawEnableSecureWindow;
        enablePrivacyShieldOverlay = rawEnablePrivacyShieldOverlay;
        enableAutoFillScaffold = rawEnableAutoFill;
        break;
      case '':
        mode = AnchSecurityMode.dev;
        useEncryptedDatabase = rawUseEncryptedDb;
        enableAppLockGate = rawEnableAppLockGate;
        enableSecureWindow = rawEnableSecureWindow;
        enablePrivacyShieldOverlay = rawEnablePrivacyShieldOverlay;
        enableAutoFillScaffold = rawEnableAutoFill;
        break;
      default:
        mode = AnchSecurityMode.dev;
        useEncryptedDatabase = rawUseEncryptedDb;
        enableAppLockGate = rawEnableAppLockGate;
        enableSecureWindow = rawEnableSecureWindow;
        enablePrivacyShieldOverlay = rawEnablePrivacyShieldOverlay;
        enableAutoFillScaffold = rawEnableAutoFill;
        isFormalBlocked = true;
        blockedReason = 'unknown security mode';
        break;
    }

    return AnchSecurityRuntimeConfig(
      mode: mode,
      useEncryptedDatabase: useEncryptedDatabase,
      enableAppLockGate: enableAppLockGate,
      enableSecureWindow: enableSecureWindow,
      enablePrivacyShieldOverlay: enablePrivacyShieldOverlay,
      isFormalBlocked: isFormalBlocked,
      blockedReason: blockedReason,
      enableAutoFillScaffold: enableAutoFillScaffold,
    );
  }

  @override
  String toString() {
    // 严格脱敏，不输出 databaseKey、backupPassword、PIN、salt、verifier 等敏感值，也不含真实路径
    return 'AnchSecurityRuntimeConfig('
        'mode: ${mode.name}, '
        'useEncryptedDatabase: $useEncryptedDatabase, '
        'enableAppLockGate: $enableAppLockGate, '
        'enableSecureWindow: $enableSecureWindow, '
        'enablePrivacyShieldOverlay: $enablePrivacyShieldOverlay, '
        'isFormalBlocked: $isFormalBlocked, '
        'blockedReason: $blockedReason, '
        'enableAutoFillScaffold: $enableAutoFillScaffold'
        ')';
  }
}
