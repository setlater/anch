import 'backup_payload.dart';

/// 将历史备份载荷转换为当前数据库可恢复的规范结构。
///
/// 转换只在内存中进行，调用方必须在写入数据库前完成完整校验。
class BackupPayloadMigrationService {
  const BackupPayloadMigrationService._();

  static BackupPayloadV1 migrateToSchema(
    BackupPayloadV1 payload, {
    required int targetSchemaVersion,
  }) {
    if (payload.schemaVersion > targetSchemaVersion) {
      throw const BackupPayloadMigrationException('备份版本高于当前数据库版本');
    }
    if (payload.schemaVersion == targetSchemaVersion) return payload;

    final childEntries = [...payload.data.childEntries];
    final childFields = [...payload.data.childFields];
    final itemIdsWithChildEntries = childEntries
        .map((entry) => entry.itemId)
        .toSet();

    for (final item in payload.data.items) {
      if (item.typeKey != 'household_book' ||
          itemIdsWithChildEntries.contains(item.id)) {
        continue;
      }

      final legacyFields = payload.data.itemFields
          .where(
            (field) =>
                field.itemId == item.id &&
                _legacyFieldKeys.contains(field.fieldKey) &&
                field.valueText != null &&
                field.valueText!.trim().isNotEmpty,
          )
          .toList();
      if (legacyFields.isEmpty) continue;

      final entryId = 'legacy_household_member_${item.id}';
      childEntries.add(
        BackupItemChildEntryV1(
          id: entryId,
          itemId: item.id,
          childType: 'household_member',
          sortOrder: 0,
          createdAt: item.createdAt,
          updatedAt: item.updatedAt,
        ),
      );
      itemIdsWithChildEntries.add(item.id);

      for (final field in legacyFields) {
        final mapped = _LegacyHouseholdBackupField.from(field.fieldKey);
        childFields.add(
          BackupItemChildFieldV1(
            id: '${entryId}_${mapped.key}',
            childEntryId: entryId,
            fieldKey: mapped.key,
            label: mapped.label,
            valueText: field.valueText,
            valueType: field.valueType,
            sensitiveLevel: mapped.sensitiveLevel,
            copyable: mapped.copyable,
            searchable: mapped.searchable,
            summary: false,
            sortOrder: field.sortOrder,
            createdAt: item.createdAt,
            updatedAt: item.updatedAt,
          ),
        );
      }
    }

    final items = payload.data.items
        .map(
          (item) =>
              item.status == 'deleted' && item.statusBeforeDeletion == null
              ? item.withStatusBeforeDeletion('active')
              : item,
        )
        .toList(growable: false);

    return BackupPayloadV1(
      format: payload.format,
      version: payload.version,
      exportedAt: payload.exportedAt,
      appVersion: payload.appVersion,
      schemaVersion: targetSchemaVersion,
      source: payload.source,
      data: BackupDataV1(
        members: payload.data.members,
        items: items,
        itemFields: payload.data.itemFields,
        appSettings: payload.data.appSettings,
        attachments: payload.data.attachments,
        childEntries: childEntries,
        childFields: childFields,
        itemEvents: payload.data.itemEvents,
        itemEventChanges: payload.data.itemEventChanges,
      ),
    );
  }
}

class BackupPayloadMigrationException implements Exception {
  const BackupPayloadMigrationException(this.message);

  final String message;
}

const _legacyFieldKeys = {
  'page_owner',
  'relation_to_head',
  'id_number',
  'former_name',
  'ethnicity',
  'native_place',
  'birth_place',
};

class _LegacyHouseholdBackupField {
  const _LegacyHouseholdBackupField({
    required this.key,
    required this.label,
    this.sensitiveLevel = 'none',
    this.copyable = false,
    this.searchable = false,
  });

  final String key;
  final String label;
  final String sensitiveLevel;
  final bool copyable;
  final bool searchable;

  static _LegacyHouseholdBackupField from(String sourceKey) {
    switch (sourceKey) {
      case 'page_owner':
        return const _LegacyHouseholdBackupField(
          key: 'member_name',
          label: '成员姓名',
          sensitiveLevel: 'medium',
          searchable: true,
        );
      case 'id_number':
        return const _LegacyHouseholdBackupField(
          key: 'member_id_number',
          label: '身份证号',
          sensitiveLevel: 'high',
          copyable: true,
        );
      case 'relation_to_head':
        return const _LegacyHouseholdBackupField(
          key: 'relation_to_head',
          label: '与户主关系',
        );
      case 'former_name':
        return const _LegacyHouseholdBackupField(
          key: 'former_name',
          label: '曾用名',
          sensitiveLevel: 'medium',
        );
      case 'ethnicity':
        return const _LegacyHouseholdBackupField(key: 'ethnicity', label: '民族');
      case 'native_place':
        return const _LegacyHouseholdBackupField(
          key: 'native_place',
          label: '籍贯',
          sensitiveLevel: 'medium',
        );
      case 'birth_place':
        return const _LegacyHouseholdBackupField(
          key: 'birth_place',
          label: '出生地',
          sensitiveLevel: 'medium',
        );
      default:
        throw ArgumentError.value(sourceKey, 'sourceKey');
    }
  }
}
