@Tags(['security'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/backup/backup_import_service.dart';
import 'package:anch/core/backup/attachment_restore_recovery_service.dart';
import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/service/item_expiry_overview_service.dart';
import 'package:anch/core/template/field_value_type.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late BackupImportService importService;

  setUp(() {
    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 43)));
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);
    importService = BackupImportService(database: db);
  });

  tearDown(() async {
    await db.close();
  });

  // 辅助方法：生成基本合法的 BackupPayloadV1 内存对象
  BackupPayloadV1 createValidPayload({
    List<BackupMemberV1>? members,
    List<BackupItemV1>? items,
    List<BackupItemFieldV1>? itemFields,
    List<BackupAttachmentV1>? attachments,
    List<BackupAppSettingV1>? appSettings,
    List<BackupItemEventV1>? itemEvents,
    List<BackupItemEventChangeV1>? itemEventChanges,
    int schemaVersion = 1,
  }) {
    final defaultMembers = [
      // 必须包含内置系统虚拟家庭成员，否则前置校验会拒绝
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
    ];

    return BackupPayloadV1(
      exportedAt: 1718035200000,
      appVersion: '1.0.0-test',
      schemaVersion: schemaVersion,
      source: BackupSourceInfo(
        appId: 'icu.codealive.anch',
        platform: 'test',
        locale: 'zh_CN',
        exportMode: 'manual',
      ),
      data: BackupDataV1(
        members: members ?? defaultMembers,
        items: items ?? [],
        itemFields: itemFields ?? [],
        appSettings: appSettings ?? [],
        attachments: attachments ?? [],
        itemEvents: itemEvents ?? [],
        itemEventChanges: itemEventChanges ?? [],
      ),
    );
  }

  group('安册备份恢复导入服务 (BackupImportService) 测试', () {
    const testPassword = 'my-test-import-password-123';
    const testIterations = 1000; // 较小的 iterations 以加快测试速度

    test('1. 当前 schema 备份可用正确密码覆盖恢复，并保留原 ID、创建更新时间', () async {
      // 1. 构造一个包含系统成员、一个普通成员、一个条目以及其高敏子字段的 Payload 并加密
      final payload = createValidPayload(
        schemaVersion: db.schemaVersion,
        members: [
          BackupMemberV1(
            id: systemFamilyMemberId,
            name: '家庭',
            relationKey: 'family',
            isSystem: true,
            sortOrder: 0,
            createdAt: 1000000,
            updatedAt: 2000000,
            isArchived: false,
          ),
          BackupMemberV1(
            id: 'member-person-uuid-a',
            name: 'TEST-MEMBER-A',
            relationKey: 'self',
            isSystem: false,
            sortOrder: 1,
            createdAt: 3000000,
            updatedAt: 4000000,
            isArchived: false,
          ),
        ],
        items: [
          BackupItemV1(
            id: 'item-uuid-a',
            originId: 'origin-item-uuid-a',
            memberId: 'member-person-uuid-a',
            categoryKey: 'identity',
            typeKey: 'id_card',
            templateVersion: 1,
            title: 'TEST-CARD-TITLE',
            createdAt: 5000000,
            updatedAt: 6000000,
            isFavorite: true,
            isPinned: false,
            sortOrder: 1,
            status: 'active',
          ),
        ],
        itemFields: [
          BackupItemFieldV1(
            id: 'field-uuid-a',
            itemId: 'item-uuid-a',
            fieldKey: 'id_number',
            valueType: 'sensitiveText',
            valueText: 'TEST-ID-CARD-NUMBER-ABC',
            normalizedValue: 'TEST-NORMALIZED-ID',
            fieldNote: 'TEST-FIELD-NOTE',
            sortOrder: 1,
            createdAt: 7000000,
            updatedAt: 8000000,
          ),
        ],
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // 2. 在另一个干净的数据库（此处即 setup 中的 db）中执行恢复
      final result = await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      // 3. 校验恢复结果统计
      expect(result.restoredMembersCount, 2);
      expect(result.restoredItemsCount, 1);
      expect(result.restoredItemFieldsCount, 1);
      expect(result.restoredAppSettingsCount, 0);

      // 4. 读取数据库以确认所有内容被无损且按照原 ID/时间戳/内容还原
      final member = await memberRepo.getMemberById('member-person-uuid-a');
      expect(member, isNotNull);
      expect(member!.name, 'TEST-MEMBER-A');
      expect(member.createdAt, 3000000);
      expect(member.updatedAt, 4000000);
      expect(member.isSystem, isFalse);

      final itemWithFields = await itemRepo.getItemWithFields('item-uuid-a');
      expect(itemWithFields, isNotNull);
      expect(itemWithFields!.title, 'TEST-CARD-TITLE');
      expect(itemWithFields.originId, 'origin-item-uuid-a');
      expect(itemWithFields.createdAt, 5000000);
      expect(itemWithFields.updatedAt, 6000000);
      expect(itemWithFields.fields.length, 1);

      final field = itemWithFields.fields[0];
      expect(field.id, 'field-uuid-a');
      expect(field.fieldKey, 'id_number');
      expect(field.valueText, 'TEST-ID-CARD-NUMBER-ABC'); // ⚠️ 高敏原样恢复
      expect(field.createdAt, 7000000);
      expect(field.updatedAt, 8000000);
    });

    test('1d. 最近删除状态与资料事件可随备份恢复', () async {
      final payload = createValidPayload(
        schemaVersion: db.schemaVersion,
        items: [
          BackupItemV1(
            id: 'deleted-item-a',
            memberId: systemFamilyMemberId,
            categoryKey: 'other',
            typeKey: 'generic',
            templateVersion: 1,
            title: 'TEST-DELETED-ITEM',
            createdAt: 1000,
            updatedAt: 2000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 0,
            status: 'deleted',
            deletedAt: 3000,
            statusBeforeDeletion: 'active',
          ),
        ],
        itemEvents: const [
          BackupItemEventV1(
            id: 'event-created-a',
            itemId: 'deleted-item-a',
            eventType: 'created',
            occurredAt: 1000,
          ),
          BackupItemEventV1(
            id: 'event-deleted-a',
            itemId: 'deleted-item-a',
            eventType: 'moved_to_trash',
            occurredAt: 3000,
          ),
        ],
        itemEventChanges: const [
          BackupItemEventChangeV1(
            id: 'change-status-a',
            eventId: 'event-deleted-a',
            changeKind: 'value_changed',
            subjectKey: 'status',
            subjectLabel: '资料状态',
            oldValue: '使用中',
            newValue: '最近删除',
            sortOrder: 0,
          ),
        ],
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      final restored = await itemRepo.getItemWithFields('deleted-item-a');
      expect(restored?.status, 'deleted');
      expect(restored?.deletedAt, 3000);
      expect(await itemRepo.getDeletedItemCount(), 1);
      final events = await db.select(db.itemEvents).get();
      expect(events.map((event) => event.eventType), [
        'created',
        'moved_to_trash',
      ]);
      final changes = await db.select(db.itemEventChanges).get();
      expect(changes.single.eventId, 'event-deleted-a');
      expect(changes.single.oldValue, '使用中');
      expect(changes.single.newValue, '最近删除');
    });

    test('1e. 事件变更引用缺失或类型非法时在覆盖写入前拒绝恢复', () async {
      final baseEvent = const BackupItemEventV1(
        id: 'event-a',
        itemId: 'item-a',
        eventType: 'updated',
        occurredAt: 2000,
      );
      final item = BackupItemV1(
        id: 'item-a',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        templateVersion: 1,
        title: 'TEST-ITEM-A',
        createdAt: 1000,
        updatedAt: 2000,
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
      );
      for (final change in [
        const BackupItemEventChangeV1(
          id: 'change-missing-event',
          eventId: 'missing-event',
          changeKind: 'field_changed',
          subjectKey: 'title',
          subjectLabel: '资料标题',
          oldValue: null,
          newValue: null,
          sortOrder: 0,
        ),
        const BackupItemEventChangeV1(
          id: 'change-invalid-kind',
          eventId: 'event-a',
          changeKind: 'unsafe_value_snapshot',
          subjectKey: 'title',
          subjectLabel: '资料标题',
          oldValue: null,
          newValue: null,
          sortOrder: 0,
        ),
        const BackupItemEventChangeV1(
          id: 'change-unsafe-values',
          eventId: 'event-a',
          changeKind: 'value_changed',
          subjectKey: 'id_number',
          subjectLabel: '身份证号',
          oldValue: 'TEST-OLD-SENSITIVE-VALUE',
          newValue: 'TEST-NEW-SENSITIVE-VALUE',
          sortOrder: 0,
        ),
      ]) {
        final payload = createValidPayload(
          schemaVersion: db.schemaVersion,
          items: [item],
          itemEvents: [baseEvent],
          itemEventChanges: [change],
        );
        final envelope = await BackupCryptoService.encryptPayload(
          payload: payload,
          backupPassword: testPassword,
          iterations: testIterations,
        );
        await expectLater(
          importService.restoreFromEnvelope(
            envelope: envelope,
            backupPassword: testPassword,
          ),
          throwsA(isA<BackupImportException>()),
        );
      }
    });

    test('1a. 恢复后的信用卡列表可从字段表读取账单日和还款日', () async {
      final payload = createValidPayload(
        schemaVersion: db.schemaVersion,
        items: [
          BackupItemV1(
            id: 'restored-credit-card',
            memberId: systemFamilyMemberId,
            categoryKey: 'card',
            typeKey: 'credit_card',
            templateVersion: 1,
            title: '虚构恢复信用卡（7890）',
            primaryText: '虚构银行 · Visa',
            createdAt: 5000000,
            updatedAt: 6000000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 1,
            status: 'active',
          ),
        ],
        itemFields: [
          BackupItemFieldV1(
            id: 'restored-credit-card-bill-day',
            itemId: 'restored-credit-card',
            fieldKey: 'bill_day',
            valueType: 'text',
            valueText: '8',
            sortOrder: 1,
            createdAt: 7000000,
            updatedAt: 8000000,
          ),
          BackupItemFieldV1(
            id: 'restored-credit-card-repayment-day',
            itemId: 'restored-credit-card',
            fieldKey: 'repayment_day',
            valueType: 'text',
            valueText: '12',
            sortOrder: 2,
            createdAt: 7000000,
            updatedAt: 8000000,
          ),
        ],
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      final restored = (await itemRepo.getActiveItems()).single;
      expect(restored.billDay, '8');
      expect(restored.repaymentDay, '12');
      expect(restored.metadata, isNull);
    });

    test('1b. 恢复后的资料可从正式字段计算已过期和即将到期状态', () async {
      final payload = createValidPayload(
        schemaVersion: db.schemaVersion,
        items: [
          BackupItemV1(
            id: 'restored-expired-passport',
            memberId: systemFamilyMemberId,
            categoryKey: 'certificate',
            typeKey: 'passport',
            templateVersion: 1,
            title: '虚构已过期护照',
            createdAt: 5000000,
            updatedAt: 6000000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 1,
            status: 'active',
          ),
          BackupItemV1(
            id: 'restored-upcoming-insurance',
            memberId: systemFamilyMemberId,
            categoryKey: 'insurance',
            typeKey: 'insurance',
            templateVersion: 1,
            title: '虚构即将到期保险',
            createdAt: 5000001,
            updatedAt: 6000001,
            isFavorite: false,
            isPinned: false,
            sortOrder: 2,
            status: 'active',
          ),
        ],
        itemFields: [
          BackupItemFieldV1(
            id: 'restored-passport-valid-until',
            itemId: 'restored-expired-passport',
            fieldKey: 'valid_until',
            valueType: 'date',
            valueText: '2026-07-01',
            sortOrder: 1,
            createdAt: 7000000,
            updatedAt: 8000000,
          ),
          BackupItemFieldV1(
            id: 'restored-insurance-end-date',
            itemId: 'restored-upcoming-insurance',
            fieldKey: 'end_date',
            valueType: 'date',
            valueText: '2026-07-20',
            sortOrder: 1,
            createdAt: 7000001,
            updatedAt: 8000001,
          ),
        ],
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      final restored = await itemRepo.getActiveItems();
      expect(restored.every((item) => item.metadata == null), isTrue);

      final overview = ItemExpiryOverviewService.calculate(
        restored,
        DateTime(2026, 7, 16),
      );
      expect(overview.expiredCount, 1);
      expect(overview.upcomingCount, 1);

      final detail = await itemRepo.getItemWithFields(
        'restored-expired-passport',
      );
      expect(detail?.rawState?['fields']?['valid_until'], '2026-07-01');
    });

    test('1c. 附件先写入 staging，数据库提交后才替换正式目录', () async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'anch-backup-import-success-',
      );
      addTearDown(() => documentsDir.delete(recursive: true));
      final attachmentBytes = await AttachmentCryptoService.encryptData(
        Uint8List.fromList(<int>[1]),
      );
      final payload = createValidPayload(
        items: [
          BackupItemV1(
            id: 'item-with-attachment',
            memberId: systemFamilyMemberId,
            categoryKey: 'other',
            typeKey: 'generic',
            templateVersion: 1,
            title: 'TEST-ATTACHMENT',
            createdAt: 1000,
            updatedAt: 1000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 0,
            status: 'active',
          ),
        ],
        attachments: [
          BackupAttachmentV1(
            id: 'attachment-new',
            itemId: 'item-with-attachment',
            attachmentRole: 'proof',
            fileName: 'new.enc',
            mimeType: 'application/octet-stream',
            plainSize: 1,
            encryptedSize: attachmentBytes.length,
            sortOrder: 0,
            status: 'active',
            createdAt: 1000,
            updatedAt: 1000,
            encryptedData: base64UrlEncode(attachmentBytes),
          ),
        ],
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );
      final service = BackupImportService(
        database: db,
        documentsDirectoryProvider: () async => documentsDir,
      );

      await service.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      final restoredFile = File('${documentsDir.path}/attachments/new.enc');
      expect(await restoredFile.readAsBytes(), attachmentBytes);
      expect(
        await documentsDir
            .list()
            .where((entry) => entry.path.contains('.attachments-restore-'))
            .isEmpty,
        isTrue,
      );
      expect(
        await File(
          '${documentsDir.path}/$attachmentRestoreJournalFileName',
        ).exists(),
        isFalse,
      );
      expect(
        await (db.select(db.appSettings)..where(
              (table) => table.key.equals(attachmentRestoreOperationSettingKey),
            ))
            .getSingleOrNull(),
        isNull,
      );
    });

    test('2. 验证覆盖恢复策略：导入前数据库里已有的旧数据被彻底清空', () async {
      // 1. 预先往数据库中写入旧数据
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-OLD-MEMBER',
          memberType: 'person',
          sortOrder: 2,
          isSystem: false,
          isArchived: false,
        ),
      );
      final oldItemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: oldMemberId,
          categoryKey: 'identity',
          typeKey: 'id_card',
          templateVersion: 1,
          title: 'TEST-OLD-TITLE',
          status: 'active',
          isFavorite: false,
          isPinned: false,
          sortOrder: 1,
          fields: [
            SaveItemFieldInput(
              fieldKey: 'id_number',
              valueType: FieldValueType.sensitiveText,
              valueText: 'TEST-OLD-ID',
              sortOrder: 1,
            ),
          ],
        ),
      );

      // 2. 构造一个仅包含系统成员和另一个成员的备份 payload，并不包含 oldItemId 对应的数据
      final payload = createValidPayload(
        members: [
          BackupMemberV1(
            id: systemFamilyMemberId,
            name: '家庭',
            relationKey: 'family',
            isSystem: true,
            sortOrder: 0,
            createdAt: 1000000,
            updatedAt: 2000000,
            isArchived: false,
          ),
          BackupMemberV1(
            id: 'new-member-uuid',
            name: 'TEST-NEW-MEMBER',
            relationKey: 'self',
            isSystem: false,
            sortOrder: 1,
            createdAt: 3000000,
            updatedAt: 4000000,
            isArchived: false,
          ),
        ],
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // 3. 执行覆盖恢复
      await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: testPassword,
      );

      // 4. 验证旧数据已被彻底抹除，只剩新数据
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNull);

      final oldItem = await itemRepo.getItemWithFields(oldItemId);
      expect(oldItem, isNull);

      // 新写入的成员应存在
      final newMember = await memberRepo.getMemberById('new-member-uuid');
      expect(newMember, isNotNull);
      expect(newMember!.name, 'TEST-NEW-MEMBER');
    });

    test('3. 验证错误密码导致解密失败，且原有数据库的数据完好无损', () async {
      // 1. 预先向数据库写入旧数据
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 准备备份 envelope
      final payload = createValidPayload();
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // 3. 传入错误密码恢复，验证异常拦截
      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: 'wrong-import-password',
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.invalidPasswordOrCorruptedData,
          ),
        ),
      );

      // 4. 验证原数据库中的旧数据未被清除或损坏
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
      expect(oldMember!.name, 'TEST-MEMBER-BEFORE');
    });

    test('4. 验证引用完整性校验失败时阻断恢复，且原数据不受破坏', () async {
      // 1. 写入旧数据做参照
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // A. 资料条目引用的 memberId 在备份 members 中不存在
      final badPayloadA = createValidPayload(
        items: [
          BackupItemV1(
            id: 'item-uuid-bad',
            memberId: 'non-existent-member-uuid', // 不存在的 memberId
            categoryKey: 'identity',
            typeKey: 'id_card',
            templateVersion: 1,
            title: 'BAD-ITEM',
            createdAt: 10000,
            updatedAt: 20000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 1,
            status: 'active',
          ),
        ],
      );

      final envelopeA = await BackupCryptoService.encryptPayload(
        payload: badPayloadA,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelopeA,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.missingMemberReference,
          ),
        ),
      );

      // B. 字段引用的 itemId 在备份 items 中不存在
      final badPayloadB = createValidPayload(
        itemFields: [
          BackupItemFieldV1(
            id: 'field-uuid-bad',
            itemId: 'non-existent-item-uuid', // 不存在的 itemId
            fieldKey: 'id_number',
            valueType: 'text',
            valueText: 'BAD-FIELD-VALUE',
            sortOrder: 1,
            createdAt: 10000,
            updatedAt: 20000,
          ),
        ],
      );

      final envelopeB = await BackupCryptoService.encryptPayload(
        payload: badPayloadB,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelopeB,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.missingItemReference,
          ),
        ),
      );

      // C. 资料事件引用不存在的资料时必须在覆盖前拒绝。
      final badPayloadC = createValidPayload(
        itemEvents: const [
          BackupItemEventV1(
            id: 'event-uuid-bad-ref',
            itemId: 'non-existent-item-uuid',
            eventType: 'created',
            occurredAt: 10000,
          ),
        ],
      );
      final envelopeC = await BackupCryptoService.encryptPayload(
        payload: badPayloadC,
        backupPassword: testPassword,
        iterations: testIterations,
      );
      await expectLater(
        importService.restoreFromEnvelope(
          envelope: envelopeC,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (error) => error.type,
            'type',
            BackupImportErrorType.missingItemReference,
          ),
        ),
      );

      // D. 未知事件类型不得进入数据库。
      final badPayloadD = createValidPayload(
        items: [
          BackupItemV1(
            id: 'item-for-invalid-event',
            memberId: systemFamilyMemberId,
            categoryKey: 'other',
            typeKey: 'generic',
            templateVersion: 1,
            title: 'TEST-INVALID-EVENT-ITEM',
            createdAt: 10000,
            updatedAt: 10000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 0,
            status: 'active',
          ),
        ],
        itemEvents: const [
          BackupItemEventV1(
            id: 'event-uuid-invalid-type',
            itemId: 'item-for-invalid-event',
            eventType: 'unknown',
            occurredAt: 10000,
          ),
        ],
      );
      final envelopeD = await BackupCryptoService.encryptPayload(
        payload: badPayloadD,
        backupPassword: testPassword,
        iterations: testIterations,
      );
      await expectLater(
        importService.restoreFromEnvelope(
          envelope: envelopeD,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (error) => error.type,
            'type',
            BackupImportErrorType.invalidPayload,
          ),
        ),
      );

      // 验证原数据库依然无损
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('5. 验证缺失系统内置家庭成员时拒绝恢复，且原有数据不受破坏', () async {
      // 1. 写入旧数据做参照
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 构造一个不含内置系统成员 systemFamilyMemberId 的 members 列表
      final badPayload = createValidPayload(
        members: [
          BackupMemberV1(
            id: 'some-other-uuid',
            name: '家庭',
            relationKey: 'family',
            isSystem: false, // 不是内置系统成员
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 2000,
            isArchived: false,
          ),
        ],
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: badPayload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.missingSystemMember,
          ),
        ),
      );

      // 验证原数据库依然无损
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('6. 验证存在重复 ID 时拒绝恢复，且原有数据不受破坏', () async {
      // 1. 写入旧数据做参照
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 构造具有重复 ID 的成员列表
      final badPayload = createValidPayload(
        members: [
          BackupMemberV1(
            id: systemFamilyMemberId,
            name: '家庭',
            relationKey: 'family',
            isSystem: true,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 2000,
            isArchived: false,
          ),
          BackupMemberV1(
            id: 'dup-id-123',
            name: 'MEMBER-A',
            relationKey: 'spouse',
            isSystem: false,
            sortOrder: 1,
            createdAt: 1000,
            updatedAt: 2000,
            isArchived: false,
          ),
          BackupMemberV1(
            id: 'dup-id-123', // 重复 ID
            name: 'MEMBER-B',
            relationKey: 'child',
            isSystem: false,
            sortOrder: 2,
            createdAt: 1000,
            updatedAt: 2000,
            isArchived: false,
          ),
        ],
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: badPayload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.duplicatedId,
          ),
        ),
      );

      // 验证原数据库依然无损
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('7. 验证 schemaVersion 不兼容时拒绝恢复，且原数据不受破坏', () async {
      // 1. 写入旧数据做参照
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 构造 schemaVersion = 99 的 Payload
      final badPayload = createValidPayload(schemaVersion: 99);

      final envelope = await BackupCryptoService.encryptPayload(
        payload: badPayload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.unsupportedSchemaVersion,
          ),
        ),
      );

      // 验证原数据库依然无损
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
    });

    test('8. 验证物理写入冲突导致回滚：在前置校验全部通过但在事务物理回填中途触发唯一性约束冲突，验证事务完整回滚且不破坏旧数据', () async {
      // 1. 写入旧数据做参照
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-MEMBER-BEFORE',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      // 2. 构造一个能通过前置校验，但在插入数据库时触发联合唯一性约束冲突的 Payload：
      // 在 item_fields 中，同属于 item-uuid-a 具有两个不同 id 却具有相同 fieldKey ('phone') 的 field。
      // 前置校验中由于 field.id 是唯一的 (field-1 和 field-2)，并且其引用的 itemId 存在，因此会 100% 成功通过前置校验！
      // 但是在 Drift 中插入数据库 item_fields 表时，会触发联合唯一索引 uniqueKeys => [{itemId, fieldKey}] 约束异常。
      final badPayload = createValidPayload(
        members: [
          BackupMemberV1(
            id: systemFamilyMemberId,
            name: '家庭',
            relationKey: 'family',
            isSystem: true,
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 2000,
            isArchived: false,
          ),
          BackupMemberV1(
            id: 'member-person-uuid-a',
            name: 'TEST-MEMBER-A',
            relationKey: 'self',
            isSystem: false,
            sortOrder: 1,
            createdAt: 3000,
            updatedAt: 4000,
            isArchived: false,
          ),
        ],
        items: [
          BackupItemV1(
            id: 'item-uuid-a',
            memberId: 'member-person-uuid-a',
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
            fieldKey: 'phone', // ⚠️ 重复的 fieldKey 组合
            valueType: 'text',
            valueText: 'TEST-PHONE-1',
            sortOrder: 1,
            createdAt: 7000,
            updatedAt: 8000,
          ),
          BackupItemFieldV1(
            id: 'field-uuid-2',
            itemId: 'item-uuid-a',
            fieldKey: 'phone', // ⚠️ 重复的 fieldKey 组合，触发联合唯一冲突
            valueType: 'text',
            valueText: 'TEST-PHONE-2',
            sortOrder: 2,
            createdAt: 7000,
            updatedAt: 8000,
          ),
        ],
      );

      final envelope = await BackupCryptoService.encryptPayload(
        payload: badPayload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // 3. 运行覆盖导入，拦截抛出的 databaseWriteFailed 异常
      expect(
        () => importService.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: testPassword,
        ),
        throwsA(
          isA<BackupImportException>().having(
            (e) => e.type,
            'type',
            BackupImportErrorType.databaseWriteFailed,
          ),
        ),
      );

      // 4. 验证原数据库依然无损，旧数据没有被清空，证明事务成功回滚了删除操作
      final oldMember = await memberRepo.getMemberById(oldMemberId);
      expect(oldMember, isNotNull);
      expect(oldMember!.name, 'TEST-MEMBER-BEFORE');
    });

    test('8b. 数据库恢复失败时恢复旧附件目录', () async {
      final documentsDir = await Directory.systemTemp.createTemp(
        'anch-backup-import-rollback-',
      );
      addTearDown(() => documentsDir.delete(recursive: true));
      final oldMemberId = await memberRepo.saveMember(
        SaveMemberInput(
          name: 'TEST-OLD-MEMBER',
          memberType: 'person',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );
      final oldItemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: oldMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          title: 'TEST-OLD-ITEM',
          status: 'active',
          isFavorite: false,
          isPinned: false,
          sortOrder: 0,
          fields: const [],
        ),
      );
      await db
          .into(db.attachments)
          .insert(
            AttachmentsCompanion.insert(
              id: 'old-attachment',
              originAttachmentId: 'old-attachment',
              itemId: oldItemId,
              attachmentRole: 'proof',
              fileName: 'old.enc',
              mimeType: 'application/octet-stream',
              createdAt: 1000,
              updatedAt: 1000,
            ),
          );
      final attachmentsDir = Directory('${documentsDir.path}/attachments');
      await attachmentsDir.create();
      final oldFile = File('${attachmentsDir.path}/old.enc');
      await oldFile.writeAsBytes(<int>[9, 8, 7], flush: true);

      final payload = createValidPayload(
        items: [
          BackupItemV1(
            id: 'new-item',
            memberId: systemFamilyMemberId,
            categoryKey: 'other',
            typeKey: 'generic',
            templateVersion: 1,
            title: 'TEST-NEW-ITEM',
            createdAt: 1000,
            updatedAt: 1000,
            isFavorite: false,
            isPinned: false,
            sortOrder: 0,
            status: 'active',
          ),
        ],
        itemFields: [
          BackupItemFieldV1(
            id: 'duplicate-field-a',
            itemId: 'new-item',
            fieldKey: 'title',
            valueType: 'text',
            valueText: 'TEST-A',
            sortOrder: 0,
            createdAt: 1000,
            updatedAt: 1000,
          ),
          BackupItemFieldV1(
            id: 'duplicate-field-b',
            itemId: 'new-item',
            fieldKey: 'title',
            valueType: 'text',
            valueText: 'TEST-B',
            sortOrder: 1,
            createdAt: 1000,
            updatedAt: 1000,
          ),
        ],
        attachments: [
          BackupAttachmentV1(
            id: 'new-attachment',
            itemId: 'new-item',
            attachmentRole: 'proof',
            fileName: 'new.enc',
            mimeType: 'application/octet-stream',
            plainSize: 1,
            encryptedSize: 3,
            sortOrder: 0,
            status: 'active',
            createdAt: 1000,
            updatedAt: 1000,
            encryptedData: 'AQID',
          ),
        ],
      );
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );
      final service = BackupImportService(
        database: db,
        documentsDirectoryProvider: () async => documentsDir,
      );

      await expectLater(
        service.restoreFromEnvelope(
          envelope: envelope,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupImportException>()),
      );

      expect(await oldFile.readAsBytes(), <int>[9, 8, 7]);
      expect(await File('${attachmentsDir.path}/new.enc').exists(), isFalse);
      expect(await itemRepo.getItemWithFields(oldItemId), isNotNull);
    });

    test(
      '9. 脱敏与敏感校验：验证 Exception 的 toString() 以及 ImportResult 摘要信息绝对安全',
      () async {
        // 1. 验证 BackupImportResult 不携带任何资料敏感明文或私隐
        final result = BackupImportResult(
          restoredMembersCount: 2,
          restoredItemsCount: 5,
          restoredItemFieldsCount: 10,
          restoredAppSettingsCount: 0,
          restoredAt: 1718035200000,
        );

        final resultStr = result.toString().toLowerCase();
        expect(resultStr, isNot(contains('test-')));
        expect(resultStr, isNot(contains('password')));

        // 2. 真实触发一个解密失败（密码错误），捕获异常，断言异常消息绝对不包含错误密码字样或假敏感字样
        try {
          final payload = createValidPayload();
          final envelope = await BackupCryptoService.encryptPayload(
            payload: payload,
            backupPassword: 'SECRET-PASSWORD-XYZ',
            iterations: testIterations,
          );
          await importService.restoreFromEnvelope(
            envelope: envelope,
            backupPassword: 'WRONG-PASSWORD-ABC',
          );
          fail('Should have failed due to decryption error');
        } on BackupImportException catch (e) {
          final exStr = e.toString();
          expect(exStr, isNot(contains('SECRET-PASSWORD-XYZ')));
          expect(exStr, isNot(contains('WRONG-PASSWORD-ABC')));
          expect(exStr, isNot(contains('{'))); // 确保不含明文 JSON
          expect(exStr, isNot(contains('envelope')));
          expect(exStr, isNot(contains('payload')));
        }
      },
    );
  });
}
