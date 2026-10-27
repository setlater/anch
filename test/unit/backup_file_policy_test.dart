import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_policy.dart';

void main() {
  group('安册备份文件保存策略与边界 (BackupFilePolicy) 单元测试', () {
    test('1. 验证标准备份后缀、新导出 MIME 与历史兼容 MIME', () {
      expect(BackupFilePolicy.extension, 'abk');
      expect(BackupFilePolicy.defaultMimeType, 'application/vnd.icu.codealive.abk');
      expect(BackupFilePolicy.legacyMimeType, 'application/octet-stream');
    });

    test('2. 验证 buildDefaultFileName 采用本地时间构造，且时区稳定', () {
      // 通过当前系统时区的本地 DateTime 构造固定时间点，获取其毫秒数
      final testLocalDateTime = DateTime(2026, 6, 11, 15, 30, 20);
      final millis = testLocalDateTime.millisecondsSinceEpoch;

      // 生成文件名，因为 isUtc = false 读取的是本地时刻，必定能保证格式化还原一致
      final fileName = BackupFilePolicy.buildDefaultFileName(nowMillis: millis);
      expect(fileName, 'anch-20260611-153020.abk');
    });

    test('3. 验证生成的文件名符合安全防线，不含大写字母、路径字符或隐私特征', () {
      final testLocalDateTime = DateTime(2026, 6, 11, 15, 30, 20);
      final millis = testLocalDateTime.millisecondsSinceEpoch;
      final fileName = BackupFilePolicy.buildDefaultFileName(nowMillis: millis);

      // A. 文件名必须全小写
      expect(fileName.toLowerCase(), fileName);

      // B. 排除敏感排除词与潜在特异信息
      final fileNameLower = fileName.toLowerCase();
      expect(fileNameLower, isNot(contains('backuppassword')));
      expect(fileNameLower, isNot(contains('databasekey')));
      expect(fileNameLower, isNot(contains('imei')));
      expect(fileNameLower, isNot(contains('mac')));
      
      // C. 确保不包含路径穿越字符
      expect(fileName, isNot(contains('/')));
      expect(fileName, isNot(contains(r'\')));
      expect(fileName, isNot(contains('..')));
    });

    test('4. 验证 isLikelyBackupFileName 严格匹配/拒绝文件名及其完整格式', () {
      // 当前与历史导出文件名均可识别。
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-20260611-153020.abk'), isTrue);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-153020.abk'), isTrue);

      // 拒绝：非 .abk 后缀
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-153020.txt'), isFalse);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-153020.abk.zip'), isFalse);

      // 拒绝：大写字母
      expect(BackupFilePolicy.isLikelyBackupFileName('ANCH-BACKUP-20260611-153020.abk'), isFalse);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-153020.ABK'), isFalse);

      // 拒绝：包含路径字符与穿越
      expect(BackupFilePolicy.isLikelyBackupFileName('../anch-backup-20260611-153020.abk'), isFalse);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-153020.abk/../'), isFalse);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup/20260611-153020.abk'), isFalse);
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-20260611-153020.abk/../'), isFalse);

      // 拒绝：日期或时间数字位不合规
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-2026061-153020.abk'), isFalse); // 日期少1位
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-202606111-153020.abk'), isFalse); // 日期多1位
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-15302.abk'), isFalse); // 时间少1位
      expect(BackupFilePolicy.isLikelyBackupFileName('anch-backup-20260611-1530200.abk'), isFalse); // 时间多1位

      // 拒绝：非 anch-backup- 开头
      expect(BackupFilePolicy.isLikelyBackupFileName('backup-20260611-153020.abk'), isFalse);
    });

    test('5. 验证 formatBytes 能安全输出且处理负数边缘情况', () {
      // 负数与0安全输出 0 B
      expect(BackupFilePolicy.formatBytes(-500), '0 B');
      expect(BackupFilePolicy.formatBytes(0), '0 B');

      // Byte 级格式化
      expect(BackupFilePolicy.formatBytes(512), '512 B');
      expect(BackupFilePolicy.formatBytes(1023), '1023 B');

      // KB 级格式化
      expect(BackupFilePolicy.formatBytes(1024), '1.0 KB');
      expect(BackupFilePolicy.formatBytes(1536), '1.5 KB');
      expect(BackupFilePolicy.formatBytes(1024 * 100), '100.0 KB');

      // MB 级格式化
      expect(BackupFilePolicy.formatBytes(1024 * 1024), '1.0 MB');
      expect(BackupFilePolicy.formatBytes((1024 * 1024 * 3.5).toInt()), '3.5 MB');
    });
  });
}
