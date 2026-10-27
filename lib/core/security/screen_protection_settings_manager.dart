import 'dart:convert';

import 'app_key_manager.dart';

enum ScreenProtectionMode { sensitiveOnly, always, unrestricted }

abstract interface class ScreenProtectionSettingsManager {
  Future<ScreenProtectionMode> loadMode();
  Future<void> saveMode(ScreenProtectionMode mode);
  Future<void> clear();
}

class ScreenProtectionSettingsException implements Exception {
  const ScreenProtectionSettingsException();

  @override
  String toString() => 'ScreenProtectionSettingsException';
}

class SecureStorageScreenProtectionSettingsManager
    implements ScreenProtectionSettingsManager {
  SecureStorageScreenProtectionSettingsManager({required this.store});

  static const String settingsKey = 'anch.screen_protection.mode.v1';

  final SecureKeyValueStore store;

  @override
  Future<ScreenProtectionMode> loadMode() async {
    try {
      final raw = await store.read(settingsKey);
      if (raw == null || raw.isEmpty) {
        return ScreenProtectionMode.sensitiveOnly;
      }
      final decoded = json.decode(raw);
      if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
        return ScreenProtectionMode.sensitiveOnly;
      }
      final name = decoded['mode'];
      return ScreenProtectionMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => ScreenProtectionMode.sensitiveOnly,
      );
    } catch (_) {
      return ScreenProtectionMode.sensitiveOnly;
    }
  }

  @override
  Future<void> saveMode(ScreenProtectionMode mode) async {
    try {
      await store.write(
        settingsKey,
        json.encode(<String, Object>{'version': 1, 'mode': mode.name}),
      );
    } catch (_) {
      throw const ScreenProtectionSettingsException();
    }
  }

  @override
  Future<void> clear() async {
    try {
      await store.delete(settingsKey);
    } catch (_) {
      throw const ScreenProtectionSettingsException();
    }
  }
}
