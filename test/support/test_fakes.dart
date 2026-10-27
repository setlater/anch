import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';

/// A simple, clean, in-memory implementation of [AppPinManager] for testing.
class FakeAppPinManager implements AppPinManager {
  String? storedPin;
  final bool throwOnHasPin;
  final bool? hasPinOverride;
  int readCount = 0;
  int writeCount = 0;

  FakeAppPinManager({
    this.storedPin,
    this.throwOnHasPin = false,
    this.hasPinOverride,
  });

  @override
  Future<bool> hasPin() async {
    readCount++;
    if (throwOnHasPin) {
      throw Exception('TEST-pin-read-error: 底层 Keystore 损坏或 SecureStorage 异常。');
    }
    if (hasPinOverride != null) {
      return hasPinOverride!;
    }
    return storedPin != null;
  }

  @override
  Future<void> setPin(String pin) async {
    writeCount++;
    storedPin = pin;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    return storedPin == pin;
  }

  @override
  Future<void> clearPin() async {
    writeCount++;
    storedPin = null;
  }
}

/// A simple, clean, in-memory implementation of [AppLockSettingsManager] for testing.
class FakeAppLockSettingsManager implements AppLockSettingsManager {
  bool enabled = false;
  final bool throwOnIsEnabled;
  int readCount = 0;
  int writeCount = 0;

  FakeAppLockSettingsManager({
    this.enabled = false,
    this.throwOnIsEnabled = false,
  });

  @override
  Future<bool> isAppLockEnabled() async {
    readCount++;
    if (throwOnIsEnabled) {
      throw Exception('TEST-settings-read-error: 配置文件读写权限不足。');
    }
    return enabled;
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    writeCount++;
    this.enabled = enabled;
  }

  @override
  Future<void> clear() async {
    writeCount++;
    enabled = false;
  }
}
