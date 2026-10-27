import 'dart:convert';

import 'security/app_key_manager.dart';

class AppGuidanceState {
  const AppGuidanceState({
    required this.firstUseAcknowledged,
    this.lastBackupReminderAt,
  });

  const AppGuidanceState.silent()
    : firstUseAcknowledged = true,
      lastBackupReminderAt = null;

  final bool firstUseAcknowledged;
  final int? lastBackupReminderAt;
}

class AppGuidanceManager {
  AppGuidanceManager(this._store) : _enabled = true;

  const AppGuidanceManager.silent() : _store = null, _enabled = false;

  static const storageKey = 'anch.app_guidance.v1';

  final SecureKeyValueStore? _store;
  final bool _enabled;

  Future<AppGuidanceState> load() async {
    if (!_enabled) return const AppGuidanceState.silent();
    try {
      final raw = await _store!.read(storageKey);
      if (raw == null || raw.isEmpty) {
        return const AppGuidanceState(firstUseAcknowledged: false);
      }
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 1) {
        return const AppGuidanceState(firstUseAcknowledged: false);
      }
      final acknowledged = data['firstUseAcknowledged'];
      final lastReminderAt = data['lastBackupReminderAt'];
      return AppGuidanceState(
        firstUseAcknowledged: acknowledged == true,
        lastBackupReminderAt: lastReminderAt is int && lastReminderAt > 0
            ? lastReminderAt
            : null,
      );
    } catch (_) {
      return const AppGuidanceState.silent();
    }
  }

  Future<void> acknowledgeFirstUse() async {
    if (!_enabled) return;
    final current = await load();
    await _write(
      AppGuidanceState(
        firstUseAcknowledged: true,
        lastBackupReminderAt: current.lastBackupReminderAt,
      ),
    );
  }

  Future<void> recordBackupReminderShown(int timestamp) async {
    if (!_enabled || timestamp <= 0) return;
    final current = await load();
    await _write(
      AppGuidanceState(
        firstUseAcknowledged: current.firstUseAcknowledged,
        lastBackupReminderAt: timestamp,
      ),
    );
  }

  Future<void> _write(AppGuidanceState state) async {
    try {
      await _store!.write(
        storageKey,
        jsonEncode({
          'version': 1,
          'firstUseAcknowledged': state.firstUseAcknowledged,
          'lastBackupReminderAt': state.lastBackupReminderAt,
        }),
      );
    } catch (_) {
      // 引导状态不是业务资料；写入失败不得阻断应用使用。
    }
  }
}

enum BackupReminderKind { none, neverBackedUp, stale }

class BackupReminderPolicy {
  const BackupReminderPolicy({
    this.minimumInterval = const Duration(days: 14),
    this.staleAfter = const Duration(days: 30),
  });

  final Duration minimumInterval;
  final Duration staleAfter;

  BackupReminderKind evaluate({
    required DateTime now,
    required bool hasSavedItems,
    required AppGuidanceState guidance,
    required int? lastBackupAt,
  }) {
    if (!hasSavedItems || !guidance.firstUseAcknowledged) {
      return BackupReminderKind.none;
    }
    final lastReminderAt = guidance.lastBackupReminderAt;
    if (lastReminderAt != null &&
        now.millisecondsSinceEpoch - lastReminderAt <
            minimumInterval.inMilliseconds) {
      return BackupReminderKind.none;
    }
    if (lastBackupAt == null) return BackupReminderKind.neverBackedUp;
    if (now.millisecondsSinceEpoch - lastBackupAt >=
        staleAfter.inMilliseconds) {
      return BackupReminderKind.stale;
    }
    return BackupReminderKind.none;
  }
}
