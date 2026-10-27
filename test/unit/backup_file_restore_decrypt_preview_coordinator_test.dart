@Tags(['security'])
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';
import 'package:anch/core/backup/backup_file_restore_decrypt_preview_coordinator.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/backup/backup_payload.dart';

class FakeBackupFileReadService implements BackupFileReadService {
  List<int> mockBytes = [];
  BackupFileReadException? mockException;
  int readCalls = 0;
  Completer<BackupFileReadResult>? pendingRead;

  @override
  Future<BackupFileReadResult> readBackupFile() async {
    readCalls++;
    if (pendingRead != null) return pendingRead!.future;
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
  group('BackupFileRestoreDecryptPreviewCoordinator 测试', () {
    late FakeBackupFileReadService readService;
    late BackupFileRestoreDecryptPreviewCoordinator coordinator;
    late BackupPayloadV1 testPayload;
    const String correctPassword = 'TEST-pass-123';

    setUp(() {
      readService = FakeBackupFileReadService();
      coordinator = BackupFileRestoreDecryptPreviewCoordinator(
        readService: readService,
        supportedSchemaVersion: 5,
      );

      testPayload = BackupPayloadV1(
        exportedAt: 1718035200000,
        appVersion: '1.0.0-test',
        schemaVersion: 1,
        source: BackupSourceInfo(
          appId: 'icu.codealive.anch',
          platform: 'android-test',
          locale: 'zh_CN',
          exportMode: 'manual',
          note: 'TEST-note',
        ),
        data: BackupDataV1(
          members: [
            BackupMemberV1(
              id: 'TEST-member-1',
              name: 'TEST-member-name',
              relationKey: 'self',
              isSystem: true,
              sortOrder: 1,
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
              isArchived: false,
              note: 'TEST-member-note',
            ),
          ],
          items: [
            BackupItemV1(
              id: 'TEST-item-1',
              memberId: 'TEST-member-1',
              categoryKey: 'personal',
              typeKey: 'identity',
              templateVersion: 1,
              title: 'TEST-item-title',
              primaryText: 'TEST-primary',
              secondaryText: 'TEST-secondary',
              summaryText: 'TEST-summary',
              searchText: 'TEST-search',
              note: 'TEST-item-note',
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
              isFavorite: false,
              isPinned: false,
              sortOrder: 1,
              status: 'active',
            ),
          ],
          itemFields: [
            BackupItemFieldV1(
              id: 'TEST-field-1',
              itemId: 'TEST-item-1',
              fieldKey: 'id_card',
              valueType: 'text',
              valueText: 'TEST-field-value',
              normalizedValue: 'TEST-field-value-norm',
              fieldNote: 'TEST-field-note',
              sortOrder: 1,
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
            ),
          ],
          appSettings: [
            BackupAppSettingV1(
              key: 'TEST-setting-key',
              value: 'TEST-setting-value',
              valueType: 'string',
              updatedAt: 1718035200000,
            ),
          ],
        ),
      );
    });

    test('1. 解密预检成功：断言数量与版本脱敏摘要无敏感信息', () async {
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      readService.mockBytes = package.bytes;

      final result = await coordinator.readAndDecryptPreview(
        backupPassword: correctPassword,
      );

      expect(result.sizeBytes, package.bytes.length);
      expect(result.membersCount, 1);
      expect(result.itemsCount, 1);
      expect(result.itemFieldsCount, 1);
      expect(result.appSettingsCount, 1);
      expect(result.schemaVersion, 1);
      expect(result.payloadVersion, 1);
      expect(result.contentPreview.members, hasLength(1));
      expect(
        result.contentPreview.members.single.displayName,
        'TEST-member-name',
      );
      expect(
        result.contentPreview.members.single.items.single.title,
        'TEST-item-title',
      );

      final resultStr = result.toString();
      // ⚠️ 【安全红线】断言脱敏
      expect(resultStr, isNot(contains('TEST-member-name')));
      expect(resultStr, isNot(contains('TEST-item-title')));
      expect(resultStr, isNot(contains('TEST-field-value')));
      expect(resultStr, isNot(contains('TEST-pass-123')));
      expect(resultStr, isNot(contains('ciphertext')));
      expect(resultStr, isNot(contains('mac')));
      expect(resultStr, isNot(contains('content://')));
      expect(resultStr, isNot(contains('/sdcard')));
      expect(resultStr, isNot(contains('/storage')));
      expect(resultStr, isNot(contains('{"'))); // 不包含 JSON
      expect(
        result.contentPreview.toString(),
        isNot(contains('TEST-member-name')),
      );
      expect(
        result.contentPreview.toString(),
        isNot(contains('TEST-item-title')),
      );
    });

    test('当前数据库 v5 导出的备份可通过解密预检', () async {
      final currentSchemaPayload = BackupPayloadV1(
        exportedAt: testPayload.exportedAt,
        appVersion: testPayload.appVersion,
        schemaVersion: 5,
        source: testPayload.source,
        data: testPayload.data,
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: currentSchemaPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      readService.mockBytes = package.bytes;

      final result = await coordinator.readAndDecryptPreview(
        backupPassword: correctPassword,
      );

      expect(result.schemaVersion, 5);
      expect(result.itemsCount, 1);
    });

    test('先选择文件再输入密码时复用同一加密字节，不再次打开文件选择器', () async {
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      readService.mockBytes = package.bytes;

      final selected = await coordinator.selectAndPrepareFile();
      final decrypted = await coordinator.decryptPreparedPreview(
        backupPassword: correctPassword,
      );

      expect(selected.sizeBytes, package.bytes.length);
      expect(decrypted.itemsCount, 1);
      expect(readService.readCalls, 1);
      expect(coordinator.takePreparedReadResult(), isNotNull);
    });

    test('清除会话后晚到的文件读取不得重新缓存或返回可用预检', () async {
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      final pending = Completer<BackupFileReadResult>();
      readService.pendingRead = pending;
      final selection = coordinator.selectAndPrepareFile();
      final rejected = expectLater(
        selection,
        throwsA(
          isA<BackupFileRestoreDecryptPreviewException>().having(
            (error) => error.type,
            'type',
            BackupFileRestoreDecryptPreviewErrorType.userCancelled,
          ),
        ),
      );
      coordinator.clearPreparedReadResult();
      pending.complete(
        BackupFileReadResult(
          bytes: package.bytes,
          sizeBytes: package.bytes.length,
          sizeLabel: '${package.bytes.length} B',
          readAt: 1234567,
          displaySource: '系统选择的文件',
        ),
      );
      await rejected;
      expect(coordinator.takePreparedReadResult(), isNull);
    });

    test('清除会话后晚到的流式文件识别不得进入流式恢复', () async {
      final pending = Completer<BackupFileReadResult>();
      readService.pendingRead = pending;
      final selection = coordinator.selectAndPrepareFile();
      final rejected = expectLater(
        selection,
        throwsA(
          isA<BackupFileRestoreDecryptPreviewException>().having(
            (error) => error.type,
            'type',
            BackupFileRestoreDecryptPreviewErrorType.userCancelled,
          ),
        ),
      );
      coordinator.clearPreparedReadResult();
      pending.completeError(
        BackupFileReadException(
          BackupFileReadErrorType.streamingV2Selected,
          '已选择流式备份文件。',
        ),
      );
      await rejected;
      expect(coordinator.takePreparedReadResult(), isNull);
    });

    test('解密期间清除会话后不得返回已认证内容清单', () async {
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      readService.mockBytes = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      ).bytes;
      await coordinator.selectAndPrepareFile();
      final preview = coordinator.decryptPreparedPreview(
        backupPassword: correctPassword,
      );
      final rejected = expectLater(
        preview,
        throwsA(
          isA<BackupFileRestoreDecryptPreviewException>().having(
            (error) => error.type,
            'type',
            BackupFileRestoreDecryptPreviewErrorType.userCancelled,
          ),
        ),
      );
      coordinator.clearPreparedReadResult();
      await rejected;
      expect(coordinator.takePreparedReadResult(), isNull);
    });

    test('2. 备份密码错误：抛出 invalidPasswordOrCorruptedData，断言异常不泄露敏感信息', () async {
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      readService.mockBytes = package.bytes;

      try {
        await coordinator.readAndDecryptPreview(
          backupPassword: 'TEST-wrong-pass',
        );
        fail('Should have failed for wrong password');
      } on BackupFileRestoreDecryptPreviewException catch (e) {
        expect(
          e.type,
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
        );
        expect(e.message, '备份密码不正确，或备份文件已损坏。');

        final errStr = e.toString();
        // ⚠️ 【安全红线】断言错误信息与 toString 脱敏
        expect(errStr, isNot(contains('TEST-pass-123')));
        expect(errStr, isNot(contains('TEST-wrong-pass')));
        expect(errStr, isNot(contains('ciphertext')));
        expect(errStr, isNot(contains('mac')));
        expect(errStr, isNot(contains('TEST-member-name')));
        expect(errStr, isNot(contains('{"')));
      }
    });

    test('3. 文件格式错误：抛出 invalidFileFormat，不显示底层异常细节', () async {
      readService.mockBytes = utf8.encode('not-a-json-string');

      try {
        await coordinator.readAndDecryptPreview(
          backupPassword: correctPassword,
        );
        fail('Should have failed for invalid JSON');
      } on BackupFileRestoreDecryptPreviewException catch (e) {
        expect(
          e.type,
          BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
        );
        expect(e.message, '备份文件格式不正确或已损坏。');

        final errStr = e.toString();
        expect(errStr, isNot(contains('not-a-json-string')));
        expect(errStr, isNot(contains('FormatException'))); // 不显示底层的解析异常类
      }
    });

    test('4. 文件过大与用户取消映射测试', () async {
      // 文件过大
      readService.mockException = BackupFileReadException(
        BackupFileReadErrorType.fileTooLarge,
        'File is too large',
      );
      try {
        await coordinator.readAndDecryptPreview(
          backupPassword: correctPassword,
        );
        fail('Should have failed');
      } on BackupFileRestoreDecryptPreviewException catch (e) {
        expect(e.type, BackupFileRestoreDecryptPreviewErrorType.fileTooLarge);
        expect(e.message, '备份文件过大，暂不支持读取。');
      }

      // 用户取消
      readService.mockException = BackupFileReadException(
        BackupFileReadErrorType.userCancelled,
        'User cancelled',
      );
      try {
        await coordinator.readAndDecryptPreview(
          backupPassword: correctPassword,
        );
        fail('Should have failed');
      } on BackupFileRestoreDecryptPreviewException catch (e) {
        expect(e.type, BackupFileRestoreDecryptPreviewErrorType.userCancelled);
        expect(e.message, '已取消选择备份文件。');
      }
    });

    test('5. schemaVersion 过高：抛出 unsupportedSchemaVersion', () async {
      final highSchemaPayload = BackupPayloadV1(
        exportedAt: 1718035200000,
        appVersion: '1.0.0-test',
        schemaVersion: 6,
        source: testPayload.source,
        data: testPayload.data,
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: highSchemaPayload,
        backupPassword: correctPassword,
        iterations: 1000,
      );
      final package = BackupFileCodec.encodeEnvelope(
        envelope: envelope,
        nowMillis: 1718035200000,
      );
      readService.mockBytes = package.bytes;

      try {
        await coordinator.readAndDecryptPreview(
          backupPassword: correctPassword,
        );
        fail('Should have failed for high schemaVersion');
      } on BackupFileRestoreDecryptPreviewException catch (e) {
        expect(
          e.type,
          BackupFileRestoreDecryptPreviewErrorType.unsupportedSchemaVersion,
        );
        expect(e.message, '当前版本暂不支持此备份文件。');
      }
    });
  });
}
