@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';
import 'package:anch/core/backup/backup_file_restore_apply_coordinator.dart';
import 'package:anch/core/backup/backup_import_service.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_envelope.dart';

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

class SpyBackupImportService extends BackupImportService {
  bool restoreFromEnvelopeCalled = false;

  SpyBackupImportService({required super.database});

  @override
  Future<BackupImportResult> restoreFromEnvelope({
    required BackupEnvelopeV1 envelope,
    required String backupPassword,
  }) async {
    restoreFromEnvelopeCalled = true;
    return super.restoreFromEnvelope(
      envelope: envelope,
      backupPassword: backupPassword,
    );
  }
}

void main() {
  group('BackupFileRestoreApplyCoordinator 测试', () {
    late AppDatabase db;
    late MemberRepository memberRepo;
    late SpyBackupImportService importService;
    late FakeBackupFileReadService readService;
    late BackupFileRestoreApplyCoordinator coordinator;
    late BackupPayloadV1 testPayload;
    const String correctPassword = 'TEST-pass-123';
    const int testIterations = 1000;

    setUp(() {
      final opener = NativeAppDatabaseOpener(inMemory: true);
      db = AppDatabase.fromOpener(opener);
      memberRepo = MemberRepository(db);
      importService = SpyBackupImportService(database: db);
      readService = FakeBackupFileReadService();
      coordinator = BackupFileRestoreApplyCoordinator(
        readService: readService,
        importService: importService,
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
        ),
        data: BackupDataV1(
          members: [
            BackupMemberV1(
              id: systemFamilyMemberId,
              name: '家庭',
              relationKey: 'family',
              isSystem: true,
              sortOrder: 0,
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
              isArchived: false,
            ),
            BackupMemberV1(
              id: 'TEST-member-uuid-b',
              name: 'TEST-member-name-b',
              relationKey: 'self',
              isSystem: false,
              sortOrder: 1,
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
              isArchived: false,
            ),
          ],
          items: [],
          itemFields: [],
          appSettings: [],
        ),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('1. 成功覆盖：验证数据库被覆盖且返回结果和 toString 彻底脱敏', () async {
      // 1. 预先向数据库写入旧成员 A
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-OLD-MEMBER-A',
        memberType: 'person',
        sortOrder: 2,
        isSystem: false,
        isArchived: false,
      ));

      // 2. 准备备份字节流 (只有系统成员和新成员 B)
      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: testIterations,
      );
      final package = BackupFileCodec.encodeEnvelope(envelope: envelope, nowMillis: 1718035200000);
      readService.mockBytes = package.bytes;

      // 3. 执行覆盖恢复
      final result = await coordinator.readAndApplyRestore(backupPassword: correctPassword);

      // 4. 断言结果
      expect(result.restoredMembersCount, 2);
      expect(result.restoredItemsCount, 0);

      // 5. 断言旧成员已被删除，新成员写入成功
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNull);

      final newMember = await memberRepo.getMemberById('TEST-member-uuid-b');
      expect(newMember, isNotNull);
      expect(newMember!.name, 'TEST-member-name-b');
      expect(importService.restoreFromEnvelopeCalled, isTrue);

      // 6. 验证 result.toString() 不包含敏感信息
      final resultStr = result.toString();
      expect(resultStr, isNot(contains('TEST-member-name-b')));
      expect(resultStr, isNot(contains('TEST-OLD-MEMBER-A')));
      expect(resultStr, isNot(contains('TEST-pass-123')));
      expect(resultStr, isNot(contains('ciphertext')));
      expect(resultStr, isNot(contains('mac')));
      expect(resultStr, isNot(contains('content://')));
      expect(resultStr, isNot(contains('/sdcard')));
      expect(resultStr, isNot(contains('/storage')));
    });

    test('2. 错误密码：抛出 invalidPasswordOrCorruptedData 且数据库数据保持不变', () async {
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-MEMBER-STAY',
        memberType: 'person',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ));

      final envelope = await BackupCryptoService.encryptPayload(
        payload: testPayload,
        backupPassword: correctPassword,
        iterations: testIterations,
      );
      final package = BackupFileCodec.encodeEnvelope(envelope: envelope, nowMillis: 1718035200000);
      readService.mockBytes = package.bytes;

      try {
        await coordinator.readAndApplyRestore(backupPassword: 'wrong-password-999');
        fail('Should have failed');
      } on BackupFileRestoreApplyException catch (e) {
        expect(e.type, BackupFileRestoreApplyErrorType.invalidPasswordOrCorruptedData);
        expect(e.message, '备份密码不正确，或备份文件已损坏。');

        final errStr = e.toString();
        // ⚠️ 【安全红线】断言错误信息与 toString 脱敏
        expect(errStr, isNot(contains('TEST-pass-123')));
        expect(errStr, isNot(contains('wrong-password-999')));
        expect(errStr, isNot(contains('ciphertext')));
        expect(errStr, isNot(contains('mac')));
      }

      // 验证原有数据库未受损
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
      expect(oldMember!.name, 'TEST-MEMBER-STAY');
    });

    test('3. 文件格式错误：抛出 invalidFileFormat 且数据库不变', () async {
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-MEMBER-STAY',
        memberType: 'person',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ));

      readService.mockBytes = utf8.encode('bad-envelope-bytes');

      try {
        await coordinator.readAndApplyRestore(backupPassword: correctPassword);
        fail('Should have failed');
      } on BackupFileRestoreApplyException catch (e) {
        expect(e.type, BackupFileRestoreApplyErrorType.invalidFileFormat);
        expect(e.message, '备份文件格式不正确或已损坏。');
      }

      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('4. 引用缺失：解密成功但校验失败，抛出 importValidationFailed 且数据库不变', () async {
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-MEMBER-STAY',
        memberType: 'person',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ));

      // 缺少内置家庭系统成员的 Payload
      final badPayload = BackupPayloadV1(
        exportedAt: 1718035200000,
        appVersion: '1.0.0-test',
        schemaVersion: 1,
        source: testPayload.source,
        data: BackupDataV1(
          members: [
            BackupMemberV1(
              id: 'not-family-uuid',
              name: '普通人',
              relationKey: 'self',
              isSystem: false,
              sortOrder: 1,
              createdAt: 1718035200000,
              updatedAt: 1718035200000,
              isArchived: false,
            ),
          ],
          items: [],
          itemFields: [],
          appSettings: [],
        ),
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: badPayload,
        backupPassword: correctPassword,
        iterations: testIterations,
      );
      final package = BackupFileCodec.encodeEnvelope(envelope: envelope, nowMillis: 1718035200000);
      readService.mockBytes = package.bytes;

      try {
        await coordinator.readAndApplyRestore(backupPassword: correctPassword);
        fail('Should have failed');
      } on BackupFileRestoreApplyException catch (e) {
        expect(e.type, BackupFileRestoreApplyErrorType.importValidationFailed);
        expect(e.message, '备份内容校验失败，未执行恢复。');
      }

      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('5. 唯一性冲突：写入失败回滚且数据库原数据不变', () async {
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-MEMBER-STAY',
        memberType: 'person',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ));

      // 构造联合唯一键 itemId & fieldKey 冲突的 Payload
      final conflictPayload = BackupPayloadV1(
        exportedAt: 1718035200000,
        appVersion: '1.0.0-test',
        schemaVersion: 1,
        source: testPayload.source,
        data: BackupDataV1(
          members: testPayload.data.members,
          items: [
            BackupItemV1(
              id: 'item-uuid-a',
              memberId: 'TEST-member-uuid-b',
              categoryKey: 'identity',
              typeKey: 'id_card',
              templateVersion: 1,
              title: 'TEST-CARD-TITLE',
              createdAt: 5000,
              updatedAt: 6000,
              isFavorite: true,
              isPinned: false,
              sortOrder: 1,
              status: 'active',
            ),
          ],
          itemFields: [
            BackupItemFieldV1(
              id: 'field-uuid-1',
              itemId: 'item-uuid-a',
              fieldKey: 'phone', // 重复的 key
              valueType: 'text',
              valueText: '123',
              sortOrder: 1,
              createdAt: 7000,
              updatedAt: 8000,
            ),
            BackupItemFieldV1(
              id: 'field-uuid-2',
              itemId: 'item-uuid-a',
              fieldKey: 'phone', // 联合唯一约束 itemId + fieldKey 发生冲突
              valueType: 'text',
              valueText: '456',
              sortOrder: 2,
              createdAt: 7000,
              updatedAt: 8000,
            ),
          ],
          appSettings: [],
        ),
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: conflictPayload,
        backupPassword: correctPassword,
        iterations: testIterations,
      );
      final package = BackupFileCodec.encodeEnvelope(envelope: envelope, nowMillis: 1718035200000);
      readService.mockBytes = package.bytes;

      try {
        await coordinator.readAndApplyRestore(backupPassword: correctPassword);
        fail('Should have failed');
      } on BackupFileRestoreApplyException catch (e) {
        expect(e.type, BackupFileRestoreApplyErrorType.importTransactionFailed);
        expect(e.message, '恢复未完成，请返回首页核对资料后再试。');
      }

      // 验证事务完整回滚，旧数据未被清除
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
      expect(oldMember!.name, 'TEST-MEMBER-STAY');
    });

    test('6. 用户取消：不触发恢复且原有数据库数据不变', () async {
      final oldMemberId = await memberRepo.saveMember(SaveMemberInput(
        name: 'TEST-MEMBER-STAY',
        memberType: 'person',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ));

      // 1. FakeReadService 抛 userCancelled
      readService.mockException = BackupFileReadException(
        BackupFileReadErrorType.userCancelled,
        'User cancelled file picker',
      );

      try {
        await coordinator.readAndApplyRestore(backupPassword: correctPassword);
        fail('Should have failed');
      } on BackupFileRestoreApplyException catch (e) {
        // 2. coordinator 抛 BackupFileRestoreApplyException.userCancelled
        expect(e.type, BackupFileRestoreApplyErrorType.userCancelled);
        expect(e.message, '已取消选择备份文件。');
      }

      // 3. importService 不应被调用
      expect(importService.restoreFromEnvelopeCalled, isFalse);

      // 4. 数据库保持原数据不变
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
      expect(oldMember!.name, 'TEST-MEMBER-STAY');
    });
  });
}
