import 'dart:convert';

import 'package:drift/drift.dart';
import 'database_opener.dart';
import 'tables/members.dart';
import 'tables/items.dart';
import 'tables/item_fields.dart';
import 'tables/attachments.dart';
import 'tables/reminders.dart';
import 'tables/app_settings.dart';
import 'tables/license_state.dart';
import 'tables/item_child_entries.dart';
import 'tables/item_child_fields.dart';
import 'tables/item_events.dart';
import 'tables/item_event_changes.dart';

part 'app_database.g.dart';

/// 系统内置虚拟家庭成员 ID，固定标准 UUID
const String systemFamilyMemberId = '00000000-0000-4000-8000-000000000001';

/// 系统内置“我”虚拟成员 ID，固定标准 UUID
const String systemMeMemberId = '00000000-0000-4000-8000-000000000002';

@DriftDatabase(
  tables: [
    Members,
    Items,
    ItemFields,
    Attachments,
    Reminders,
    AppSettings,
    LicenseState,
    ItemChildEntries,
    ItemChildFields,
    ItemEvents,
    ItemEventChanges,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// DO NOT instantiate directly. Use DependencyProvider.
  AppDatabase._(AppDatabaseOpener opener) : super(opener.openConnection());

  factory AppDatabase.fromOpener(AppDatabaseOpener opener) =>
      AppDatabase._(opener);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      // 创建所有表和索引
      await m.createAll();

      // 初始化插入“家庭”虚拟成员作为系统基底
      final now = DateTime.now().millisecondsSinceEpoch;
      await into(members).insert(
        MembersCompanion.insert(
          id: systemFamilyMemberId,
          memberType: 'family',
          name: '家庭',
          isSystem: const Value(true),
          isArchived: const Value(false),
          sortOrder: const Value(0),
          createdAt: now,
          updatedAt: now,
        ),
      );

      // 初始化插入“我”虚拟成员作为系统内置成员
      await into(members).insert(
        MembersCompanion.insert(
          id: systemMeMemberId,
          memberType: 'person',
          name: '我',
          isSystem: const Value(true),
          isArchived: const Value(false),
          sortOrder: const Value(1),
          createdAt: now,
          updatedAt: now,
        ),
      );
    },
    onUpgrade: (m, from, to) async {
      if (from > to) {
        throw StateError('不支持降级打开数据库');
      }

      if (from < 5) {
        await m.addColumn(items, items.pinnedAt);
      }

      if (from < 2) {
        await m.alterTable(TableMigration(members));
      }

      if (from < 3) {
        await m.addColumn(items, items.metadata);
      }

      if (from < 4) {
        await m.database.transaction(() async {
          await m.createTable(itemChildEntries);
          await m.createTable(itemChildFields);
          await _migrateLegacyHouseholdBookFields(m);
        });
      }

      if (from < 5) {
        await m.database.customStatement(
          'UPDATE items SET pinned_at = updated_at WHERE is_pinned = 1;',
        );
        await m.database.customStatement(
          'CREATE INDEX IF NOT EXISTS idx_items_active_pinned_at '
          'ON items (status, is_pinned, pinned_at);',
        );
      }

      if (from < 6) {
        await m.database.customStatement('PRAGMA foreign_keys = OFF;');
        try {
          await m.database.transaction(() async {
            await m.database.customStatement(
              "UPDATE items SET status = 'active' "
              "WHERE status NOT IN ('active', 'archived', 'deleted');",
            );
            await m.database.customStatement(
              "UPDATE attachments SET status = 'active' "
              "WHERE status NOT IN ('active', 'deleted');",
            );
            await _removeLegacyRawState(m);
            await m.alterTable(
              TableMigration(
                items,
                newColumns: [
                  items.originId,
                  items.deletedAt,
                  items.statusBeforeDeletion,
                ],
                columnTransformer: {
                  items.originId: const CustomExpression<String>('id'),
                  items.deletedAt: const CustomExpression<int>(
                    "CASE WHEN status = 'deleted' THEN updated_at ELSE NULL END",
                  ),
                  items.statusBeforeDeletion: const CustomExpression<String>(
                    "CASE WHEN status = 'deleted' THEN 'active' ELSE NULL END",
                  ),
                },
              ),
            );
            await m.alterTable(TableMigration(itemFields));
            await m.alterTable(
              TableMigration(
                attachments,
                newColumns: [attachments.originAttachmentId],
                columnTransformer: {
                  attachments.originAttachmentId:
                      const CustomExpression<String>('id'),
                },
              ),
            );
            await m.createTable(itemEvents);
          });
        } finally {
          await m.database.customStatement('PRAGMA foreign_keys = ON;');
        }
      }

      if (from < 7) {
        await m.createTable(itemEventChanges);
      }

      if (from >= 6 && from < 8) {
        await m.database.customStatement('PRAGMA foreign_keys = OFF;');
        try {
          await m.database.transaction(() async {
            await m.alterTable(
              TableMigration(
                items,
                newColumns: [items.originId, items.statusBeforeDeletion],
                columnTransformer: {
                  items.originId: const CustomExpression<String>('id'),
                  items.statusBeforeDeletion: const CustomExpression<String>(
                    "CASE WHEN status = 'deleted' THEN 'active' ELSE NULL END",
                  ),
                },
              ),
            );
            await m.alterTable(
              TableMigration(
                attachments,
                newColumns: [attachments.originAttachmentId],
                columnTransformer: {
                  attachments.originAttachmentId:
                      const CustomExpression<String>('id'),
                },
              ),
            );
            await m.alterTable(TableMigration(itemEvents));
          });
        } finally {
          await m.database.customStatement('PRAGMA foreign_keys = ON;');
        }
      }

      if (from >= 8 && from < 9) {
        await m.database.customStatement('PRAGMA foreign_keys = OFF;');
        try {
          await m.database.transaction(() async {
            await m.alterTable(
              TableMigration(
                items,
                newColumns: [items.originId],
                columnTransformer: {
                  items.originId: const CustomExpression<String>('id'),
                },
              ),
            );
            await m.alterTable(
              TableMigration(
                attachments,
                newColumns: [attachments.originAttachmentId],
                columnTransformer: {
                  attachments.originAttachmentId:
                      const CustomExpression<String>('id'),
                },
              ),
            );
            await m.alterTable(TableMigration(itemEvents));
          });
        } finally {
          await m.database.customStatement('PRAGMA foreign_keys = ON;');
        }
      }
    },
  );

  Future<void> _migrateLegacyHouseholdBookFields(Migrator migrator) async {
    final legacyItems = await migrator.database
        .customSelect(
          "SELECT id, created_at, updated_at FROM items WHERE type_key = 'household_book';",
        )
        .get();

    for (final item in legacyItems) {
      final itemId = item.read<String>('id');
      final createdAt = item.read<int>('created_at');
      final updatedAt = item.read<int>('updated_at');
      final fields = await migrator.database
          .customSelect(
            "SELECT field_key, value_type, value_text, sort_order FROM item_fields "
            "WHERE item_id = ? AND field_key IN ("
            "'page_owner', 'relation_to_head', 'id_number', 'former_name', "
            "'ethnicity', 'native_place', 'birth_place');",
            variables: [Variable.withString(itemId)],
          )
          .get();

      final legacyFields = fields.where((field) {
        final value = field.read<String?>('value_text');
        return value != null && value.trim().isNotEmpty;
      });
      if (legacyFields.isEmpty) continue;

      final entryId = 'legacy_household_member_$itemId';
      await migrator.database.customStatement(
        "INSERT INTO item_child_entries (id, item_id, child_type, sort_order, created_at, updated_at) "
        "VALUES (?, ?, 'household_member', 0, ?, ?);",
        [entryId, itemId, createdAt, updatedAt],
      );

      for (final field in legacyFields) {
        final sourceKey = field.read<String>('field_key');
        final mapped = _LegacyHouseholdField.from(sourceKey);
        await migrator.database.customStatement(
          "INSERT INTO item_child_fields ("
          "id, child_entry_id, field_key, label, value_text, value_type, "
          "sensitive_level, copyable, searchable, summary, sort_order, created_at, updated_at"
          ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
          [
            '${entryId}_${mapped.key}',
            entryId,
            mapped.key,
            mapped.label,
            field.read<String?>('value_text'),
            field.read<String>('value_type'),
            mapped.sensitiveLevel,
            mapped.copyable ? 1 : 0,
            mapped.searchable ? 1 : 0,
            0,
            field.read<int>('sort_order'),
            createdAt,
            updatedAt,
          ],
        );
      }
    }
  }

  Future<void> _removeLegacyRawState(Migrator migrator) async {
    final rows = await migrator.database
        .customSelect(
          'SELECT id, metadata FROM items WHERE metadata IS NOT NULL;',
        )
        .get();
    for (final row in rows) {
      final rawMetadata = row.read<String?>('metadata');
      if (rawMetadata == null || rawMetadata.isEmpty) continue;
      try {
        final decoded = jsonDecode(rawMetadata);
        if (decoded is! Map<String, dynamic> ||
            !decoded.containsKey('raw_state')) {
          continue;
        }
        decoded.remove('raw_state');
        final cleaned = decoded.isEmpty ? null : jsonEncode(decoded);
        await migrator.database.customStatement(
          'UPDATE items SET metadata = ? WHERE id = ?;',
          [cleaned, row.read<String>('id')],
        );
      } catch (_) {
        // 不猜测或覆盖无法解析的历史元数据。
      }
    }
  }
}

class _LegacyHouseholdField {
  const _LegacyHouseholdField({
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

  static _LegacyHouseholdField from(String sourceKey) {
    switch (sourceKey) {
      case 'page_owner':
        return const _LegacyHouseholdField(
          key: 'member_name',
          label: '成员姓名',
          sensitiveLevel: 'medium',
          searchable: true,
        );
      case 'id_number':
        return const _LegacyHouseholdField(
          key: 'member_id_number',
          label: '身份证号',
          sensitiveLevel: 'high',
          copyable: true,
        );
      case 'relation_to_head':
        return const _LegacyHouseholdField(
          key: 'relation_to_head',
          label: '与户主关系',
        );
      case 'former_name':
        return const _LegacyHouseholdField(
          key: 'former_name',
          label: '曾用名',
          sensitiveLevel: 'medium',
        );
      case 'ethnicity':
        return const _LegacyHouseholdField(key: 'ethnicity', label: '民族');
      case 'native_place':
        return const _LegacyHouseholdField(
          key: 'native_place',
          label: '籍贯',
          sensitiveLevel: 'medium',
        );
      case 'birth_place':
        return const _LegacyHouseholdField(
          key: 'birth_place',
          label: '出生地',
          sensitiveLevel: 'medium',
        );
      default:
        throw ArgumentError.value(sourceKey, 'sourceKey');
    }
  }
}
