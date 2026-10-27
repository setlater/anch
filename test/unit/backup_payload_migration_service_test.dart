import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_payload_migration_service.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('低版本户口本载荷在写库前转换为当前规范结构', () {
    final payload = _legacyHouseholdPayload(schemaVersion: 3);

    final migrated = BackupPayloadMigrationService.migrateToSchema(
      payload,
      targetSchemaVersion: 5,
    );

    expect(migrated.schemaVersion, 5);
    expect(payload.data.childEntries, isEmpty);
    expect(
      migrated.data.childEntries.single.id,
      'legacy_household_member_legacy-book',
    );
    expect(
      migrated.data.childFields.map((field) => field.fieldKey),
      containsAll(['member_name', 'member_id_number']),
    );
    expect(
      migrated.data.childFields
          .firstWhere((field) => field.fieldKey == 'member_id_number')
          .copyable,
      isTrue,
    );
  });

  test('拒绝高于当前数据库版本的备份载荷', () {
    expect(
      () => BackupPayloadMigrationService.migrateToSchema(
        _legacyHouseholdPayload(schemaVersion: 6),
        targetSchemaVersion: 5,
      ),
      throwsA(isA<BackupPayloadMigrationException>()),
    );
  });

  test('V7 已删除资料载荷迁移时补为从当前资料删除', () {
    final base = _legacyHouseholdPayload(schemaVersion: 7);
    final deletedItem = BackupItemV1(
      id: 'legacy-deleted',
      memberId: systemFamilyMemberId,
      categoryKey: 'other',
      typeKey: 'generic',
      templateVersion: 1,
      title: '虚构历史删除资料',
      createdAt: 1000,
      updatedAt: 2000,
      isFavorite: false,
      isPinned: false,
      sortOrder: 0,
      status: 'deleted',
      deletedAt: 2000,
    );
    final payload = BackupPayloadV1(
      exportedAt: base.exportedAt,
      appVersion: base.appVersion,
      schemaVersion: 7,
      source: base.source,
      data: BackupDataV1(
        members: base.data.members,
        items: [deletedItem],
        itemFields: const [],
        appSettings: const [],
        attachments: const [],
      ),
    );

    final migrated = BackupPayloadMigrationService.migrateToSchema(
      payload,
      targetSchemaVersion: 8,
    );
    expect(migrated.data.items.single.statusBeforeDeletion, 'active');
  });

  test('V8 备份缺少来源字段时以原主键补齐', () {
    final base = _legacyHouseholdPayload(schemaVersion: 8);
    final attachment = BackupAttachmentV1(
      id: 'legacy-attachment',
      itemId: 'legacy-book',
      attachmentRole: 'proof',
      fileName: 'encrypted.bin',
      mimeType: 'application/octet-stream',
      plainSize: 1,
      encryptedSize: 1,
      sortOrder: 0,
      status: 'active',
      createdAt: 1000,
      updatedAt: 1000,
      encryptedData: '',
    );
    final payload = BackupPayloadV1(
      exportedAt: base.exportedAt,
      appVersion: base.appVersion,
      schemaVersion: 8,
      source: base.source,
      data: BackupDataV1(
        members: base.data.members,
        items: base.data.items,
        itemFields: base.data.itemFields,
        appSettings: const [],
        attachments: [attachment],
      ),
    );

    final migrated = BackupPayloadMigrationService.migrateToSchema(
      payload,
      targetSchemaVersion: 9,
    );

    expect(migrated.data.items.single.originId, 'legacy-book');
    expect(
      migrated.data.attachments.single.originAttachmentId,
      'legacy-attachment',
    );
  });
}

BackupPayloadV1 _legacyHouseholdPayload({required int schemaVersion}) {
  return BackupPayloadV1(
    exportedAt: 1000,
    appVersion: 'test',
    schemaVersion: schemaVersion,
    source: BackupSourceInfo(appId: 'anch.test', platform: 'test'),
    data: BackupDataV1(
      members: [
        BackupMemberV1(
          id: systemFamilyMemberId,
          name: '家庭',
          relationKey: 'family',
          isSystem: true,
          sortOrder: 0,
          createdAt: 1000,
          updatedAt: 1000,
          isArchived: false,
        ),
      ],
      items: [
        BackupItemV1(
          id: 'legacy-book',
          memberId: systemFamilyMemberId,
          categoryKey: 'certificate',
          typeKey: 'household_book',
          templateVersion: 1,
          title: '户口本',
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
          id: 'legacy-owner',
          itemId: 'legacy-book',
          fieldKey: 'page_owner',
          valueType: 'text',
          valueText: '迁移成员',
          sortOrder: 0,
          createdAt: 1000,
          updatedAt: 1000,
        ),
        BackupItemFieldV1(
          id: 'legacy-id',
          itemId: 'legacy-book',
          fieldKey: 'id_number',
          valueType: 'text',
          valueText: '110101199003072345',
          sortOrder: 1,
          createdAt: 1000,
          updatedAt: 1000,
        ),
      ],
      appSettings: const [],
      attachments: const [],
      childEntries: const [],
      childFields: const [],
    ),
  );
}
