import 'dart:convert';

import 'app_key_manager.dart';

enum AppLockAutoLockMode { everyForeground, nextLaunch }

class AppLockPreferences {
  const AppLockPreferences({
    this.biometricEnabled = false,
    this.autoLockMode = AppLockAutoLockMode.everyForeground,
  });

  final bool biometricEnabled;
  final AppLockAutoLockMode autoLockMode;

  AppLockPreferences copyWith({
    bool? biometricEnabled,
    AppLockAutoLockMode? autoLockMode,
  }) {
    return AppLockPreferences(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      autoLockMode: autoLockMode ?? this.autoLockMode,
    );
  }
}

class AppLockPreferencesManager {
  AppLockPreferencesManager(this._store);

  static const settingsKey = 'anch.app_lock.preferences.v1';
  final SecureKeyValueStore _store;

  Future<AppLockPreferences> load() async {
    try {
      final raw = await _store.read(settingsKey);
      if (raw == null || raw.isEmpty) return const AppLockPreferences();
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) {
        return const AppLockPreferences();
      }
      final biometricEnabled = data['biometricEnabled'];
      if (data['version'] == 1) {
        return AppLockPreferences(
          biometricEnabled: biometricEnabled is bool && biometricEnabled,
        );
      }
      final rawMode = data['autoLockMode'];
      return AppLockPreferences(
        biometricEnabled: biometricEnabled is bool && biometricEnabled,
        autoLockMode: switch (rawMode) {
          'nextLaunch' => AppLockAutoLockMode.nextLaunch,
          _ => AppLockAutoLockMode.everyForeground,
        },
      );
    } catch (_) {
      return const AppLockPreferences();
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _save((await load()).copyWith(biometricEnabled: enabled));
  }

  Future<void> setAutoLockMode(AppLockAutoLockMode mode) async {
    await _save((await load()).copyWith(autoLockMode: mode));
  }

  Future<void> clear() => _store.delete(settingsKey);

  Future<void> _save(AppLockPreferences preferences) {
    return _store.write(
      settingsKey,
      jsonEncode({
        'version': 2,
        'biometricEnabled': preferences.biometricEnabled,
        'autoLockMode': preferences.autoLockMode.name,
      }),
    );
  }
}
