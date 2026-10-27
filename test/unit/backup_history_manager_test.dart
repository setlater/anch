import 'package:anch/core/backup/backup_history_manager.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('成功记录并读取上次备份的脱敏元信息', () async {
    final manager = BackupHistoryManager(MemorySecureKeyValueStore());

    await manager.record(
      fileName: 'anch-backup-20260722-120102.abk',
      savedAt: 1784692862000,
    );

    final history = await manager.load();
    expect(history?.fileName, 'anch-backup-20260722-120102.abk');
    expect(history?.savedAt, 1784692862000);
  });

  test('拒绝记录包含路径的文件名', () async {
    final manager = BackupHistoryManager(MemorySecureKeyValueStore());

    expect(
      () => manager.record(fileName: '/private/backup.abk', savedAt: 1),
      throwsArgumentError,
    );
  });
}
