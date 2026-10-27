import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'migration_checkpoint.dart';
import 'migration_failure_log.dart';

/// Dedicated storage layer for migration checkpoints and failure logs.
/// Uses atomic file writes (write to .tmp and rename) to ensure resilience against crashes.
class MigrationStateStore {
  static const checkpointFileName = 'migration_checkpoint.json';
  static const failureLogFileName = 'migration_failures.json';

  final Directory? baseDirectory;

  MigrationStateStore({this.baseDirectory});

  Future<Directory> _getDir() async {
    if (baseDirectory != null) {
      return baseDirectory!;
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _getCheckpointFile() async {
    final dir = await _getDir();
    return File(p.join(dir.path, checkpointFileName));
  }

  Future<File> _getFailureLogFile() async {
    final dir = await _getDir();
    return File(p.join(dir.path, failureLogFileName));
  }

  /// Persist the migration checkpoint atomically.
  Future<void> saveMigrationCheckpoint(MigrationCheckpoint checkpoint) async {
    final file = await _getCheckpointFile();
    final tmpFile = File('${file.path}.tmp');
    final jsonStr = jsonEncode(checkpoint.toJson());
    await tmpFile.writeAsString(jsonStr, flush: true);
    await tmpFile.rename(file.path);
  }

  /// Retrieve the last saved migration checkpoint. Returns null if not exists.
  Future<MigrationCheckpoint?> getMigrationCheckpoint() async {
    try {
      final file = await _getCheckpointFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final map = jsonDecode(content) as Map<String, dynamic>;
      return MigrationCheckpoint.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Clear/delete the migration checkpoint file.
  Future<void> clearMigrationCheckpoint() async {
    try {
      final file = await _getCheckpointFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignored
    }
  }

  /// Append and save a migration failure log atomically.
  Future<void> saveFailureLog(MigrationFailureLog log) async {
    try {
      final file = await _getFailureLogFile();
      List<dynamic> logs = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        logs = jsonDecode(content) as List<dynamic>;
      }
      logs.add(log.toJson());
      final tmpFile = File('${file.path}.tmp');
      await tmpFile.writeAsString(jsonEncode(logs), flush: true);
      await tmpFile.rename(file.path);
    } catch (_) {
      // Ignored
    }
  }

  /// Retrieve all migration failure logs.
  Future<List<MigrationFailureLog>> getFailureLogs() async {
    try {
      final file = await _getFailureLogFile();
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map(
            (item) =>
                MigrationFailureLog.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear/delete all migration failure logs.
  Future<void> clearMigrationFailureLogs() async {
    try {
      final file = await _getFailureLogFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Ignored
    }
  }
}
