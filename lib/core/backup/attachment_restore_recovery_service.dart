import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart';

/// 覆盖恢复附件切换的持久化日志文件名。
const attachmentRestoreJournalFileName = '.attachments-restore-journal.json';

/// 数据库事务内的提交标记；不属于用户设置，也不会进入备份。
const attachmentRestoreOperationSettingKey =
    '__anch_internal_attachment_restore_operation';

class AttachmentRestoreRecoveryException implements Exception {
  final String message;

  const AttachmentRestoreRecoveryException(this.message);

  @override
  String toString() => 'AttachmentRestoreRecoveryException: $message';
}

/// 文件目录与数据库事务之间的恢复日志。
///
/// 文件日志仅记录随机操作标识，不保存附件名称、目录绝对路径或用户数据。数据库
/// 标记与覆盖恢复的数据写入同一事务提交，因此可在下次启动时可靠判断新附件是否
/// 已与新数据库一起提交。
class AttachmentRestoreRecoveryService {
  final AppDatabase database;
  final Future<Directory> Function()? documentsDirectoryProvider;

  AttachmentRestoreRecoveryService({
    required this.database,
    this.documentsDirectoryProvider,
  });

  Future<void> writePreparedJournal(String token) async {
    final file = await _journalFile();
    await file.writeAsString(
      jsonEncode({'version': 1, 'token': token}),
      flush: true,
    );
  }

  Future<void> deleteJournalIfExists() async {
    final journal = await _journalFile();
    if (await journal.exists()) {
      await journal.delete();
    }
  }

  Future<void> recoverPendingRestore() async {
    final journal = await _journalFile();
    if (!await journal.exists()) {
      await _clearOrphanedCommittedMarker();
      return;
    }

    final token = await _readToken(journal);
    final directories = await _directoriesFor(token);
    final committed = await _hasCommittedMarker(token);

    if (committed) {
      if (!await directories.live.exists()) {
        throw const AttachmentRestoreRecoveryException('附件恢复状态不完整');
      }
      await _deleteIfExists(directories.rollback);
      await _deleteIfExists(directories.staging);
    } else {
      if (await directories.rollback.exists()) {
        await _deleteIfExists(directories.live);
        await directories.rollback.rename(directories.live.path);
      }
      await _deleteIfExists(directories.staging);
    }

    await journal.delete();
    if (committed) {
      await _clearCommittedMarker(token);
    }
  }

  Future<File> _journalFile() async {
    final directory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    return File(p.join(directory.path, attachmentRestoreJournalFileName));
  }

  Future<String> _readToken(File journal) async {
    try {
      final value = jsonDecode(await journal.readAsString());
      if (value is! Map || value['version'] != 1 || value['token'] is! String) {
        throw const FormatException();
      }
      final token = value['token'] as String;
      if (!RegExp(r'^[0-9]+$').hasMatch(token)) {
        throw const FormatException();
      }
      return token;
    } catch (_) {
      throw const AttachmentRestoreRecoveryException('附件恢复日志无效');
    }
  }

  Future<_AttachmentRestoreDirectories> _directoriesFor(String token) async {
    final directory =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    return _AttachmentRestoreDirectories(
      live: Directory(p.join(directory.path, 'attachments')),
      staging: Directory(
        p.join(directory.path, '.attachments-restore-staging-$token'),
      ),
      rollback: Directory(
        p.join(directory.path, '.attachments-restore-rollback-$token'),
      ),
    );
  }

  Future<bool> _hasCommittedMarker(String token) async {
    final setting =
        await (database.select(database.appSettings)..where(
              (table) => table.key.equals(attachmentRestoreOperationSettingKey),
            ))
            .getSingleOrNull();
    return setting?.value == token;
  }

  Future<void> _clearCommittedMarker(String token) async {
    await (database.delete(database.appSettings)..where(
          (table) =>
              table.key.equals(attachmentRestoreOperationSettingKey) &
              table.value.equals(token),
        ))
        .go();
  }

  Future<void> _clearOrphanedCommittedMarker() async {
    await (database.delete(database.appSettings)..where(
          (table) => table.key.equals(attachmentRestoreOperationSettingKey),
        ))
        .go();
  }

  Future<void> _deleteIfExists(Directory directory) async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class _AttachmentRestoreDirectories {
  final Directory live;
  final Directory staging;
  final Directory rollback;

  const _AttachmentRestoreDirectories({
    required this.live,
    required this.staging,
    required this.rollback,
  });
}
