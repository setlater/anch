@Tags(['platform'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';
import 'package:anch/core/backup/android_saf_backup_file_read_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidSafBackupFileReadService Channel 读文件测试', () {
    const channel = MethodChannel('anch/backup_file_read');
    final service = AndroidSafBackupFileReadService();

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('1. 验证成功读取场景，返回正确的元数据预览，且不泄露路径与 Uri', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'openBackupDocumentAndRead') {
          return <Object?, Object?>{
            'success': true,
            'bytes': Uint8List.fromList([10, 20, 30]),
            'readAt': 1718035200000,
          };
        }
        return null;
      });

      final result = await service.readBackupFile();

      expect(result.sizeBytes, 3);
      expect(result.sizeLabel, '3 B');
      expect(result.readAt, 1718035200000);
      expect(result.displaySource, '系统选择的文件'); // ⚠️ 固定脱敏
      expect(result.bytes, [10, 20, 30]);

      final str = result.toString().toLowerCase();
      expect(str, isNot(contains('[10, 20')));
      expect(str, isNot(contains('content://')));
      expect(str, isNot(contains('/sdcard')));
      expect(str, isNot(contains('/storage')));
    });

    test('2. 验证 PlatformException 错误代码能被正确安全地转换映射并脱敏', () async {
      final errorCodes = <String, BackupFileReadErrorType>{
        'userCancelled': BackupFileReadErrorType.userCancelled,
        'permissionDenied': BackupFileReadErrorType.permissionDenied,
        'fileUnavailable': BackupFileReadErrorType.fileUnavailable,
        'fileTooLarge': BackupFileReadErrorType.fileTooLarge,
        'systemPickerUnavailable': BackupFileReadErrorType.systemPickerUnavailable,
        'readFailed': BackupFileReadErrorType.readFailed,
        'invalidFile': BackupFileReadErrorType.invalidFile,
        'unknown_code': BackupFileReadErrorType.unknown,
      };

      for (final entry in errorCodes.entries) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          throw PlatformException(code: entry.key, message: 'Platform level error context');
        });

        try {
          await service.readBackupFile();
          fail('Should have failed for error code: ${entry.key}');
        } on BackupFileReadException catch (e) {
          expect(e.type, entry.value);

          final errStr = e.toString().toLowerCase();
          // ⚠️ 【安全红线】不得在异常 toString 中暴露 PlatformException 底层字段或路径
          expect(errStr, isNot(contains('platformexception')));
          expect(errStr, isNot(contains('platform level error')));
          expect(errStr, isNot(contains('content://')));
          expect(errStr, isNot(contains('/storage')));
          expect(errStr, isNot(contains('/sdcard')));
        }
      }
    });

    test('3. 验证参数边界校验（空字节数组、超过 50MB 大小限制拦截）', () async {
      // A. 空字节
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return <Object?, Object?>{
          'success': true,
          'bytes': Uint8List.fromList([]),
          'readAt': 1718035200000,
        };
      });

      expect(
        () => service.readBackupFile(),
        throwsA(
          isA<BackupFileReadException>().having(
            (e) => e.type,
            'type',
            BackupFileReadErrorType.invalidFile,
          ),
        ),
      );

      // B. 超过 50MB
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return <Object?, Object?>{
          'success': true,
          'bytes': Uint8List(BackupFileCodec.maxBackupFileBytes + 1),
          'readAt': 1718035200000,
        };
      });

      expect(
        () => service.readBackupFile(),
        throwsA(
          isA<BackupFileReadException>().having(
            (e) => e.type,
            'type',
            BackupFileReadErrorType.fileTooLarge,
          ),
        ),
      );
    });
  });
}
