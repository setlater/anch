@Tags(['platform'])
library;

import 'package:anch/core/backup/android_saf_backup_v2_stream_service.dart';
import 'package:anch/core/backup/backup_file_policy.dart';
import 'package:anch/core/backup/backup_file_save_service.dart';
import 'package:anch/core/backup/backup_v2_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anch/backup_stream_v2');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('V2 SAF 会话按有限分块写入并仅在精确长度确认后报告成功', () async {
    var written = 0;
    final methods = <String>[];
    Map<Object?, Object?>? beginArguments;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'beginStreamingBackupDocument':
              beginArguments = call.arguments as Map<Object?, Object?>;
              return <Object?, Object?>{'success': true};
            case 'writeStreamingBackupChunk':
              written += (call.arguments['bytes'] as Uint8List).length;
              return <Object?, Object?>{'success': true};
            case 'finishStreamingBackupDocument':
              return <Object?, Object?>{
                'success': true,
                'savedAt': 1,
                'sizeBytes': written,
              };
            default:
              return null;
          }
        });

    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: 'anch-backup-20260717-120000.abk',
      mimeType: BackupFilePolicy.defaultMimeType,
    );
    await session.write(Uint8List.fromList(const [1, 2, 3]));
    final result = await session.finish(expectedSizeBytes: 3);

    expect(result.isSuccess, isTrue);
    expect(result.sizeBytes, 3);
    expect(beginArguments?['fileName'], 'anch-backup-20260717-120000.abk');
    expect(beginArguments?['mimeType'], BackupFilePolicy.defaultMimeType);
    expect(methods, [
      'beginStreamingBackupDocument',
      'writeStreamingBackupChunk',
      'finishStreamingBackupDocument',
    ]);
  });

  test('超出单帧限制时本地拒绝，避免将整包复制到平台通道', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'beginStreamingBackupDocument') {
            return <Object?, Object?>{'success': true};
          }
          return <Object?, Object?>{'success': true};
        });
    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: 'anch-backup-20260717-120000.abk',
      mimeType: BackupFilePolicy.defaultMimeType,
    );

    await expectLater(
      session.write(Uint8List(BackupV2Format.framePlaintextLimit + 1)),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.writeFailed,
        ),
      ),
    );
    await session.abort();
  });

  test('首个分块被系统拒绝时映射为保存位置无法写入', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'beginStreamingBackupDocument') {
            return <Object?, Object?>{'success': true};
          }
          if (call.method == 'writeStreamingBackupChunk') {
            throw PlatformException(code: 'writeFailed');
          }
          return null;
        });
    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: 'anch-backup-20260717-120000.abk',
      mimeType: BackupFilePolicy.defaultMimeType,
    );

    await expectLater(
      session.write(Uint8List.fromList(const [1, 2, 3])),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.targetWriteFailed,
        ),
      ),
    );
    await session.abort();
  });

  test('已有写入任务时保留为独立的未结束操作错误', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'beginStreamingBackupDocument') {
            throw PlatformException(code: 'operationInProgress');
          }
          return null;
        });

    await expectLater(
      AndroidSafBackupV2WriteSession.begin(
        fileName: 'anch-backup-20260717-120000.abk',
        mimeType: BackupFilePolicy.defaultMimeType,
      ),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.operationInProgress,
        ),
      ),
    );
  });

  test('系统写入中断时保留为独立错误类型', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'beginStreamingBackupDocument') {
            return <Object?, Object?>{'success': true};
          }
          if (call.method == 'writeStreamingBackupChunk') {
            throw PlatformException(code: 'writeInterrupted');
          }
          return null;
        });
    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: 'anch-backup-20260717-120000.abk',
      mimeType: BackupFilePolicy.defaultMimeType,
    );

    await expectLater(
      session.write(Uint8List.fromList(const [1, 2, 3])),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.writeInterrupted,
        ),
      ),
    );
    await session.abort();
  });

  test('完成确认被系统拒绝时映射为收尾失败', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'beginStreamingBackupDocument' ||
              call.method == 'writeStreamingBackupChunk') {
            return <Object?, Object?>{'success': true};
          }
          if (call.method == 'finishStreamingBackupDocument') {
            throw PlatformException(code: 'writeFailed');
          }
          return null;
        });
    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: 'anch-backup-20260717-120000.abk',
      mimeType: BackupFilePolicy.defaultMimeType,
    );
    await session.write(Uint8List.fromList(const [1, 2, 3]));

    await expectLater(
      session.finish(expectedSizeBytes: 3),
      throwsA(
        isA<BackupFileSaveException>().having(
          (error) => error.type,
          'type',
          BackupFileSaveErrorType.finalizationFailed,
        ),
      ),
    );
  });

  test('V2 密码重试重新打开同一前台选择的只读流', () async {
    final methods = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          switch (call.method) {
            case 'getSelectedStreamingBackupInfo':
            case 'restartSelectedStreamingBackupRead':
              return <Object?, Object?>{'success': true, 'sizeBytes': 1024};
            case 'readSelectedStreamingBackupChunk':
              return <Object?, Object?>{
                'success': true,
                'bytes': Uint8List.fromList(const [1, 2, 3]),
                'eof': false,
              };
            case 'closeSelectedStreamingBackupRead':
              return null;
          }
          return null;
        });

    final session = await AndroidSafBackupV2ReadSession.openSelected();
    expect(await session.readChunk(), Uint8List.fromList(const [1, 2, 3]));
    await session.restart();
    expect(await session.readChunk(), Uint8List.fromList(const [1, 2, 3]));
    await session.close();

    expect(methods, [
      'getSelectedStreamingBackupInfo',
      'readSelectedStreamingBackupChunk',
      'restartSelectedStreamingBackupRead',
      'readSelectedStreamingBackupChunk',
      'closeSelectedStreamingBackupRead',
    ]);
  });
}
