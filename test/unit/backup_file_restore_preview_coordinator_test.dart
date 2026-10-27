@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_envelope.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';
import 'package:anch/core/backup/backup_file_restore_preview_coordinator.dart';

class FakeBackupFileReadService implements BackupFileReadService {
  List<int> mockBytes = [];
  BackupFileReadException? mockException;

  @override
  Future<BackupFileReadResult> readBackupFile() async {
    if (mockException != null) {
      throw mockException!;
    }
    return BackupFileReadResult(
      bytes: mockBytes,
      sizeBytes: mockBytes.length,
      sizeLabel: '${mockBytes.length} B',
      readAt: 1234567,
      displaySource: '系统选择的文件',
    );
  }
}

void main() {
  group('BackupFileRestorePreviewCoordinator 预检协调器测试', () {
    late FakeBackupFileReadService readService;
    late BackupFileRestorePreviewCoordinator coordinator;

    setUp(() {
      readService = FakeBackupFileReadService();
      coordinator = BackupFileRestorePreviewCoordinator(readService: readService);
    });

    test('1. 验证合规包字节流入时，协调器成功解析还原 Envelope 并返回脱敏预览模型', () async {
      final envelope = BackupEnvelopeV1(
        createdAt: 1718035200000,
        kdf: BackupKdfInfo(name: 'pbkdf2', iterations: 1000, salt: 'c2FsdA==', keyLength: 32),
        cipher: BackupCipherInfo(name: 'aes-gcm', nonce: 'bm9uY2U=', tagLength: 16),
        ciphertext: 'Y2lwaGVydGV4dA==',
        mac: 'bWFj',
      );

      final package = BackupFileCodec.encodeEnvelope(envelope: envelope, nowMillis: 1718035200000);
      readService.mockBytes = package.bytes;

      final preview = await coordinator.readAndPreviewEnvelope();

      expect(preview.sizeBytes, package.bytes.length);
      expect(preview.readAt, 1234567);
      expect(preview.displaySource, '系统选择的文件');
      expect(preview.envelopeVersion, 1);
      expect(preview.payloadVersion, 1);
      expect(preview.kdfName, 'pbkdf2');
      expect(preview.cipherName, 'aes-gcm');

      // ⚠️ 【安全红线】校验 PreviewResult.toString() 彻底过滤高敏字段
      final previewStr = preview.toString().toLowerCase();
      expect(previewStr, isNot(contains('ciphertext')));
      expect(previewStr, isNot(contains('mac')));
      expect(previewStr, isNot(contains('salt')));
      expect(previewStr, isNot(contains('nonce')));
      expect(previewStr, isNot(contains('{"')));
      expect(previewStr, isNot(contains('content://')));
    });

    test('2. 验证非合法 JSON、坏包数据传入时，协调器能够捕获并正确抛出脱敏异常', () async {
      final badDataList = [
        utf8.encode('not-a-json-string'), // 非 JSON
        utf8.encode('{"magic": "BAD_MAGIC", "version": 1}'), // 坏包
        utf8.encode(''), // 空
      ];

      for (final badBytes in badDataList) {
        readService.mockBytes = badBytes;

        try {
          await coordinator.readAndPreviewEnvelope();
          fail('Should have failed for invalid bytes data');
        } on BackupFileReadException catch (e) {
          expect(e.type, BackupFileReadErrorType.invalidFile);
          
          final errStr = e.toString().toLowerCase();
          expect(errStr, isNot(contains('not-a-json-string')));
          expect(errStr, isNot(contains('bad_magic')));
          expect(errStr, isNot(contains('content://')));
          expect(errStr, isNot(contains('/storage')));
        }
      }
    });

    test('3. 验证底层读取服务抛出读取异常时，协调器直接向上抛出不作二次篡改', () async {
      readService.mockException = BackupFileReadException(
        BackupFileReadErrorType.userCancelled,
        '已取消选择备份文件',
      );

      expect(
        () => coordinator.readAndPreviewEnvelope(),
        throwsA(
          isA<BackupFileReadException>().having(
            (e) => e.type,
            'type',
            BackupFileReadErrorType.userCancelled,
          ),
        ),
      );
    });
  });
}
