import 'dart:convert';
import 'app_key_manager.dart';

abstract class AppLockSettingsManager {
  Future<bool> isAppLockEnabled();
  Future<void> setAppLockEnabled(bool enabled);
  Future<void> clear();
}

class AppLockSettingsException implements Exception {
  final String message;
  final dynamic details;

  AppLockSettingsException(this.message, [this.details]);

  @override
  String toString() {
    // 严格脱敏，仅返回类型说明，决不包含任何内部 details 或 message 细节
    return 'AppLockSettingsException';
  }
}

class SecureStorageAppLockSettingsManager implements AppLockSettingsManager {
  final SecureKeyValueStore store;

  static const String _settingsKey = 'anch.app_lock.enabled.v1';

  SecureStorageAppLockSettingsManager({required this.store});

  @override
  Future<bool> isAppLockEnabled() async {
    try {
      final dataStr = await store.read(_settingsKey);
      if (dataStr == null) {
        return false;
      }

      final dynamic data = json.decode(dataStr);
      if (data is! Map<String, dynamic> ||
          data['version'] != 1 ||
          data['enabled'] is! bool) {
        throw const FormatException();
      }

      return data['enabled'] as bool;
    } catch (_) {
      throw AppLockSettingsException('应用锁配置读取失败。');
    }
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {
    try {
      final dataJson = json.encode({
        'version': 1,
        'enabled': enabled,
        'updatedAtMillis': DateTime.now().millisecondsSinceEpoch,
      });
      await store.write(_settingsKey, dataJson);
    } catch (e) {
      throw AppLockSettingsException('无法写入应用锁设置状态。', e);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await store.delete(_settingsKey);
    } catch (e) {
      throw AppLockSettingsException('无法清空应用锁设置状态。', e);
    }
  }
}
