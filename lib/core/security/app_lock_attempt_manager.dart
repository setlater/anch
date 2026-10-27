import 'dart:convert';

import 'app_key_manager.dart';

class AppLockAttemptStorageException implements Exception {
  const AppLockAttemptStorageException();

  @override
  String toString() => 'AppLockAttemptStorageException';
}

class AppLockAttemptState {
  const AppLockAttemptState({this.failedAttempts = 0, this.lockedUntilMillis});

  final int failedAttempts;
  final int? lockedUntilMillis;
}

class AppLockAttemptManager {
  AppLockAttemptManager(this._store);

  static const settingsKey = 'anch.app_lock.attempts.v1';
  final SecureKeyValueStore _store;

  Future<AppLockAttemptState> load() async {
    try {
      final raw = await _store.read(settingsKey);
      if (raw == null) return const AppLockAttemptState();
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 1) {
        throw const AppLockAttemptStorageException();
      }
      final attempts = data['failedAttempts'];
      final lockedUntil = data['lockedUntilMillis'];
      if (!data.containsKey('lockedUntilMillis') ||
          attempts is! int ||
          attempts < 0 ||
          (lockedUntil != null && (lockedUntil is! int || lockedUntil <= 0))) {
        throw const AppLockAttemptStorageException();
      }
      return AppLockAttemptState(
        failedAttempts: attempts,
        lockedUntilMillis: lockedUntil as int?,
      );
    } catch (_) {
      throw const AppLockAttemptStorageException();
    }
  }

  Future<void> save(AppLockAttemptState state) {
    return _store.write(
      settingsKey,
      jsonEncode({
        'version': 1,
        'failedAttempts': state.failedAttempts,
        'lockedUntilMillis': state.lockedUntilMillis,
      }),
    );
  }

  Future<void> clear() => _store.delete(settingsKey);
}
