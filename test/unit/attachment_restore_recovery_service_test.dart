@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:anch/core/backup/attachment_restore_recovery_service.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase database;
  late Directory documentsDirectory;
  late AttachmentRestoreRecoveryService service;

  setUp(() async {
    database = AppDatabase.fromOpener(NativeAppDatabaseOpener(inMemory: true));
    documentsDirectory = await Directory.systemTemp.createTemp('anch-restore-');
    service = AttachmentRestoreRecoveryService(
      database: database,
      documentsDirectoryProvider: () async => documentsDirectory,
    );
  });

  tearDown(() async {
    await database.close();
    await documentsDirectory.delete(recursive: true);
  });

  Future<void> writeInterruptedDirectories(String token) async {
    final live = Directory(p.join(documentsDirectory.path, 'attachments'));
    final rollback = Directory(
      p.join(documentsDirectory.path, '.attachments-restore-rollback-$token'),
    );
    await live.create();
    await rollback.create();
    await File(p.join(live.path, 'new.enc')).writeAsBytes([1, 2, 3]);
    await File(p.join(rollback.path, 'old.enc')).writeAsBytes([9, 8, 7]);
    await File(
      p.join(documentsDirectory.path, attachmentRestoreJournalFileName),
    ).writeAsString(jsonEncode({'version': 1, 'token': token}), flush: true);
  }

  test('数据库事务未提交时恢复旧附件目录', () async {
    const token = '101';
    await writeInterruptedDirectories(token);

    await service.recoverPendingRestore();

    final live = Directory(p.join(documentsDirectory.path, 'attachments'));
    expect(await File(p.join(live.path, 'old.enc')).readAsBytes(), [9, 8, 7]);
    expect(await File(p.join(live.path, 'new.enc')).exists(), isFalse);
    expect(
      await File(
        p.join(documentsDirectory.path, attachmentRestoreJournalFileName),
      ).exists(),
      isFalse,
    );
  });

  test('数据库事务已提交时保留新附件并清理回滚副本', () async {
    const token = '102';
    await writeInterruptedDirectories(token);
    await database
        .into(database.appSettings)
        .insert(
          AppSettingsCompanion.insert(
            key: attachmentRestoreOperationSettingKey,
            value: const Value(token),
            valueType: 'internal',
            updatedAt: 1,
          ),
        );

    await service.recoverPendingRestore();

    final live = Directory(p.join(documentsDirectory.path, 'attachments'));
    expect(await File(p.join(live.path, 'new.enc')).readAsBytes(), [1, 2, 3]);
    expect(await File(p.join(live.path, 'old.enc')).exists(), isFalse);
    expect(
      await (database.select(database.appSettings)..where(
            (table) => table.key.equals(attachmentRestoreOperationSettingKey),
          ))
          .getSingleOrNull(),
      isA<Null>(),
    );
  });

  test('无效恢复日志保持现场并阻断启动', () async {
    final journal = File(
      p.join(documentsDirectory.path, attachmentRestoreJournalFileName),
    );
    await journal.writeAsString('{invalid', flush: true);

    await expectLater(
      service.recoverPendingRestore(),
      throwsA(isA<AttachmentRestoreRecoveryException>()),
    );

    expect(await journal.exists(), isTrue);
  });
}
