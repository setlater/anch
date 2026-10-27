import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';

void main() {
  group('BackupFileReadService 基础模型脱敏校验测试', () {
    test('1. 验证 BackupFileReadResult.toString() 满足高敏字节脱敏过滤', () {
      final result = BackupFileReadResult(
        bytes: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        sizeBytes: 10,
        sizeLabel: '10 B',
        readAt: 12345678,
        displaySource: '系统选择的文件',
      );

      final str = result.toString().toLowerCase();

      // ⚠️ 【安全边界】确保排除字节数组本身
      expect(str, isNot(contains('[1, 2, 3')));
      expect(str, isNot(contains('1, 2, 3, 4, 5')));
      expect(str, isNot(contains('content://')));
      expect(str, isNot(contains('/sdcard')));
      expect(str, isNot(contains('/storage')));
      expect(str, isNot(contains('password')));
      expect(str, isNot(contains('ciphertext')));
      expect(str, isNot(contains('mac')));
      expect(str, isNot(contains('{"')));

      // 验证必要元数据可见
      expect(str, contains('10'));
      expect(str, contains('10 b'));
      expect(str, contains('12345678'));
      expect(str, contains('系统选择的文件'));
    });

    test('2. 验证 BackupFileReadException.toString() 满足脱敏安全要求', () {
      final exception = BackupFileReadException(
        BackupFileReadErrorType.fileTooLarge,
        '备份文件体积超出限制',
      );

      final str = exception.toString().toLowerCase();

      expect(str, isNot(contains('content://')));
      expect(str, isNot(contains('/sdcard')));
      expect(str, isNot(contains('/storage')));
      expect(str, isNot(contains('ciphertext')));
      expect(str, isNot(contains('mac')));
      expect(str, isNot(contains('password')));
      expect(str, isNot(contains('{"')));

      expect(str, contains('backupfilereadexception'));
      expect(str, contains('filetoolarge'));
      expect(str, contains('备份文件体积超出限制'));
    });
  });
}
