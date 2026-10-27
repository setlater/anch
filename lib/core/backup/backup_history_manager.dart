import 'dart:convert';

import '../security/app_key_manager.dart';

class BackupHistory {
  const BackupHistory({required this.fileName, required this.savedAt});

  final String fileName;
  final int savedAt;
}

class BackupHistoryManager {
  BackupHistoryManager(this._store);

  static const storageKey = 'anch.backup.history.v1';

  final SecureKeyValueStore _store;

  Future<BackupHistory?> load() async {
    try {
      final raw = await _store.read(storageKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 1) return null;

      final fileName = data['fileName'];
      final savedAt = data['savedAt'];
      if (fileName is! String ||
          fileName.isEmpty ||
          fileName.contains('/') ||
          fileName.contains('\\') ||
          savedAt is! int ||
          savedAt <= 0) {
        return null;
      }
      return BackupHistory(fileName: fileName, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> record({required String fileName, required int savedAt}) {
    if (fileName.isEmpty ||
        fileName.contains('/') ||
        fileName.contains('\\') ||
        savedAt <= 0) {
      throw ArgumentError('备份记录参数无效。');
    }
    return _store.write(
      storageKey,
      jsonEncode({'version': 1, 'fileName': fileName, 'savedAt': savedAt}),
    );
  }

  Future<void> clear() => _store.delete(storageKey);
}
