@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/backup/backup_export_service.dart';
import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/template/field_value_type.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late BackupExportMetadata metadata;
  late BackupExportService exportService;

  setUp(() {
    // 1. 初始化内存只读数据库，保证测试独立性
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);

    metadata = BackupExportMetadata(
      appVersion: '1.0.0-test',
      schemaVersion: 1,
      appId: 'icu.codealive.anch',
      platform: 'test',
      locale: 'zh_CN',
    );

    exportService = BackupExportService(
      itemRepository: itemRepo,
      memberRepository: memberRepo,
      metadata: metadata,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('安册备份最小导出服务 (BackupExportService) 内存测试', () {
    final testPassword = 'my-test-export-password-123';
    const testIterations = 1000; // 较小的 iterations 以加快测试速度

    test('1. 验证空数据库或无用户资料时仍可以正常导出加密 envelope，且解密无误', () async {
      // 导出备份 (未写入任何资料，但可能存在系统自动生成的初始家庭成员)
      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(envelope.magic, 'ANCH_BACKUP');
      expect(envelope.version, 1);
      expect(envelope.kdf.iterations, testIterations);

      // 解密解密
      final payload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: testPassword,
      );

      expect(payload.format, 'anch.backup.payload');
      expect(payload.version, 1);
      expect(payload.appVersion, '1.0.0-test');
      expect(payload.data.items, isEmpty);
      expect(payload.data.itemFields, isEmpty);
      expect(payload.data.appSettings, isEmpty);
    });

    test('2. 验证有用户记录和高敏假数据资料时，可以顺利导出并在解密后完整还原且保留 TEST-* 高敏假数据', () async {
      // 1. 插入一个家庭成员 (不使用系统保留的 UUID)
      final memberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-A',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 插入一条资料及其属性子字段
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: memberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          templateVersion: 1,
          title: 'TEST-CARD-TITLE',
          status: 'active',
          isFavorite: true,
          isPinned: false,
          sortOrder: 1,
          fields: [
            SaveItemFieldInput(
              fieldKey: 'id_number',
              valueType: FieldValueType.sensitiveText,
              valueText:
                  'TEST-ID-CARD-NUMBER', // ⚠️ 高敏测试数据强制以 TEST-* 为前缀，防止泄露真实格式数据
              normalizedValue: 'TEST-NORMALIZED-ID',
              fieldNote: 'TEST-FIELD-NOTE',
              sortOrder: 1,
            ),
          ],
        ),
        recordUserEvent: true,
      );
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: memberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          templateVersion: 1,
          title: 'TEST-CARD-TITLE',
          status: 'active',
          isFavorite: true,
          isPinned: false,
          sortOrder: 1,
          fields: [
            SaveItemFieldInput(
              fieldKey: 'id_number',
              valueType: FieldValueType.sensitiveText,
              valueText: 'TEST-ID-CARD-NUMBER-UPDATED',
              normalizedValue: 'TEST-NORMALIZED-ID-UPDATED',
              fieldNote: 'TEST-FIELD-NOTE',
              sortOrder: 1,
            ),
          ],
        ),
        recordUserEvent: true,
      );

      // 3. 执行导出
      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: testPassword,
        iterations: testIterations,
        nowMillisForTest: 1718035200000,
      );

      // 4. 正确密码解密并校验还原度
      final decryptedPayload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: testPassword,
      );

      // 校验 members
      final backupMembers = decryptedPayload.data.members;
      expect(
        backupMembers.any((m) => m.name == 'TEST-MEMBER-A' && m.id == memberId),
        isTrue,
      );

      // 校验 items
      final backupItems = decryptedPayload.data.items;
      expect(backupItems.length, 1);
      expect(backupItems[0].id, itemId);
      expect(backupItems[0].title, 'TEST-CARD-TITLE');
      expect(backupItems[0].isFavorite, isTrue);

      // 校验 itemFields，高敏字段明文值应该在内存明文中无损还原
      final backupFields = decryptedPayload.data.itemFields;
      expect(backupFields.length, 1);
      expect(backupFields[0].itemId, itemId);
      expect(backupFields[0].fieldKey, 'id_number');
      expect(backupFields[0].valueText, 'TEST-ID-CARD-NUMBER-UPDATED');

      final eventChanges = decryptedPayload.data.itemEventChanges;
      expect(eventChanges, hasLength(1));
      expect(eventChanges.single.subjectLabel, '身份证号');
      expect(eventChanges.single.oldValue, isNull);
      expect(eventChanges.single.newValue, isNull);

      // 5. 错误密码解密拦截校验
      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: 'wrong-password-abc',
        ),
        throwsA(
          isA<BackupCryptoException>().having(
            (e) => e.type,
            'type',
            BackupCryptoErrorType.invalidPasswordOrCorruptedData,
          ),
        ),
      );
    });

    test(
      '3. 敏感排除字段严格扫描，确保导出的 envelope 及解密后的明文 payload 中绝对不含任何安全物理密钥或存储区字样',
      () async {
        // 1. 建立测试记录
        final memberId = await memberRepo.saveMember(
          SaveMemberInput(
            name: 'TEST-MEMBER-A',
            memberType: 'person',
            sortOrder: 1,
            isSystem: false,
            isArchived: false,
          ),
        );
        await itemRepo.saveItemWithFields(
          SaveItemInput(
            memberId: memberId,
            categoryKey: 'cat',
            typeKey: 'type',
            templateVersion: 1,
            title: 'TEST-TITLE',
            status: 'active',
            isFavorite: false,
            isPinned: false,
            sortOrder: 1,
            fields: [
              SaveItemFieldInput(
                fieldKey: 'key',
                valueType: FieldValueType.text,
                valueText: 'TEST-VALUE',
                sortOrder: 1,
              ),
            ],
          ),
        );

        // 2. 加密导出
        final envelope = await exportService.exportEncryptedBackup(
          backupPassword: testPassword,
          iterations: testIterations,
        );

        // 3. 扫描加密 envelope JSON 串，执行排除词验证
        final envelopeJson = jsonEncode(envelope.toJson()).toLowerCase();
        expect(envelopeJson, isNot(contains('backuppassword')));
        expect(envelopeJson, isNot(contains('backupkey')));
        expect(envelopeJson, isNot(contains('databasekey')));
        expect(envelopeJson, isNot(contains('securestorage')));
        expect(envelopeJson, isNot(contains('keystore')));
        expect(envelopeJson, isNot(contains('keychain')));
        // 确保不误伤 keyLength 等字段 (已在 envelope 中含有 kdf.keyLength 等，只在 toLowerCase 时校验不含上述特定的长词)

        // 4. 扫描解密出的明文 payload JSON 串，执行排除词验证
        final payload = await BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: testPassword,
        );
        final payloadJson = jsonEncode(payload.toJson()).toLowerCase();
        expect(payloadJson, isNot(contains('backuppassword')));
        expect(payloadJson, isNot(contains('backupkey')));
        expect(payloadJson, isNot(contains('databasekey')));
        expect(payloadJson, isNot(contains('securestorage')));
        expect(payloadJson, isNot(contains('keystore')));
        expect(payloadJson, isNot(contains('keychain')));
      },
    );

    test('4. 假数据规则约束，绝不出现任何真实格式的银行卡/手机号/身份证数据，高敏必须使用 TEST-* 前缀', () async {
      // 1. 建立测试记录并导出
      final memberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-A',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: memberId,
          categoryKey: 'cat',
          typeKey: 'type',
          templateVersion: 1,
          title: 'TEST-TITLE',
          status: 'active',
          isFavorite: false,
          isPinned: false,
          sortOrder: 1,
          fields: [
            SaveItemFieldInput(
              fieldKey: 'key',
              valueType: FieldValueType.sensitiveText,
              valueText:
                  'TEST-BANK-CARD-NUMBER', // ⚠️ 高敏测试数据强制以 TEST-* 为前缀规范，严禁真实数据
              sortOrder: 1,
            ),
          ],
        ),
      );

      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: testPassword,
        iterations: testIterations,
      );

      final payload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: testPassword,
      );

      for (final field in payload.data.itemFields) {
        if (field.valueText != null) {
          expect(field.valueText, startsWith('TEST-'));
          expect(field.valueText!.length, isNot(18));
          expect(field.valueText!.length, isNot(19));
          expect(field.valueText!.length, isNot(11));
        }
      }
    });

    test('4a. 最近删除资料及其完整事件序列进入备份', () async {
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 1,
          title: 'TEST-DELETED-ITEM',
          status: 'active',
          isFavorite: false,
          isPinned: false,
          sortOrder: 0,
          fields: const [],
        ),
        recordUserEvent: true,
      );
      expect(await itemRepo.moveToTrash(itemId), isTrue);

      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: testPassword,
        iterations: testIterations,
      );
      final payload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: testPassword,
      );

      final item = payload.data.items.single;
      expect(item.status, 'deleted');
      expect(item.deletedAt, isNotNull);
      expect(payload.data.itemEvents.map((event) => event.eventType), [
        'created',
        'moved_to_trash',
      ]);
    });

    test(
      '5. 验证内存工具方法 exportEncryptedBackupJson 和 exportEncryptedBackupJsonBytes 的功能闭环',
      () async {
        // 1. 保存一条数据
        final memberId = await memberRepo.saveMember(
          SaveMemberInput(
            name: 'TEST-MEMBER-A',
            memberType: 'person',
            sortOrder: 1,
            isSystem: false,
            isArchived: false,
          ),
        );
        await itemRepo.saveItemWithFields(
          SaveItemInput(
            memberId: memberId,
            categoryKey: 'cat',
            typeKey: 'type',
            templateVersion: 1,
            title: 'TEST-TITLE',
            status: 'active',
            isFavorite: false,
            isPinned: false,
            sortOrder: 1,
            fields: [
              SaveItemFieldInput(
                fieldKey: 'key',
                valueType: FieldValueType.text,
                valueText: 'TEST-VALUE',
                sortOrder: 1,
              ),
            ],
          ),
        );

        // 2. 测试返回 JSON 字符串的方法
        final jsonStr = await exportService.exportEncryptedBackupJson(
          backupPassword: testPassword,
          iterations: testIterations,
        );
        expect(jsonStr, startsWith('{'));
        expect(jsonStr, contains('"magic":"ANCH_BACKUP"'));

        // 3. 测试返回 Bytes 数组的方法
        final bytes = await exportService.exportEncryptedBackupJsonBytes(
          backupPassword: testPassword,
          iterations: testIterations,
        );
        final decodedJsonStr = utf8.decode(bytes);
        expect(decodedJsonStr, startsWith('{'));
        expect(decodedJsonStr, contains('"magic":"ANCH_BACKUP"'));
      },
    );
  });
}
