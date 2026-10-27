import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_save_service.dart';

void main() {
  test('备份保存结果只包含脱敏元信息', () {
    final result = BackupFileSaveResult(
      fileName: 'anch-20261026-120000.abk',
      mimeType: 'application/vnd.icu.codealive.abk',
      sizeBytes: 3,
      savedAt: 1718035200000,
      displayLocation: '系统选择的位置',
      isSuccess: true,
    );

    expect(result.isSuccess, isTrue);
    expect(result.sizeBytes, 3);
    expect(result.toString(), contains('系统选择的位置'));
    expect(result.toString(), isNot(contains('content://')));
    expect(result.toString(), isNot(contains('/storage/')));
  });

  test('备份保存异常保留错误分类与脱敏说明', () {
    final error = BackupFileSaveException(
      BackupFileSaveErrorType.insufficientSpace,
      '存储空间不足',
    );

    expect(error.type, BackupFileSaveErrorType.insufficientSpace);
    expect(error.toString(), contains('存储空间不足'));
    expect(error.toString(), isNot(contains('content://')));
    expect(error.toString(), isNot(contains('/storage/')));
  });
}
