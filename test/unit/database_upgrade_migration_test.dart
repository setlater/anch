import 'dart:io';

import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

void main() {
  group('数据库历史版本升级', () {
    for (final version in [1, 2, 3, 4, 5]) {
      test('v$version 夹具可原子升级至当前 schema', () async {
        final fixture = await _LegacyDatabaseFixture.create(version);
        addTearDown(fixture.dispose);

        final database = AppDatabase.fromOpener(
          _FileDatabaseOpener(fixture.file),
        );
        addTearDown(database.close);

        final childEntries = await database
            .select(database.itemChildEntries)
            .get();
        final childFields = await database
            .select(database.itemChildFields)
            .get();
        final items = await database.select(database.items).get();
        final members = await database.select(database.members).get();
        final foreignKeys = await database
            .customSelect('PRAGMA foreign_keys;')
            .getSingle();
        final userVersion = await database
            .customSelect('PRAGMA user_version;')
            .getSingle();
        final foreignKeyCheck = await database
            .customSelect('PRAGMA foreign_key_check;')
            .get();
        final itemFieldColumns = await database
            .customSelect('PRAGMA table_info(item_fields);')
            .get();
        final itemEvents = await database.select(database.itemEvents).get();

        expect(items.single.memberId, systemFamilyMemberId);
        expect(items.single.originId, items.single.id);
        expect(items.single.metadata, isNull);
        expect(items.single.deletedAt, isNull);
        expect(itemEvents, isEmpty);
        expect(
          itemFieldColumns.map((column) => column.read<String>('name')),
          isNot(
            containsAll([
              'template_field_known',
              'is_archived_field',
              'archived_reason',
            ]),
          ),
        );
        expect(
          members.any((member) => member.id == systemFamilyMemberId),
          isTrue,
        );
        if (version < 4) {
          expect(
            childEntries.single.id,
            'legacy_household_member_legacy-household-book',
          );
          expect(
            childFields.map((field) => field.fieldKey),
            containsAll(['member_name', 'member_id_number']),
          );
          expect(
            childFields
                .firstWhere((field) => field.fieldKey == 'member_id_number')
                .copyable,
            isTrue,
          );
        }
        expect(foreignKeys.read<int>('foreign_keys'), 1);
        expect(userVersion.read<int>('user_version'), 9);
        if (version == 4 || version == 5) {
          expect(items.single.isPinned, isTrue);
          expect(items.single.pinnedAt, 1000);
        }
        expect(foreignKeyCheck, isEmpty, reason: '升级后必须保留所有外键引用完整性');
        await expectLater(
          database.customStatement(
            "UPDATE items SET status = 'invalid' WHERE id = 'legacy-household-book';",
          ),
          throwsA(isA<sqlite.SqliteException>()),
        );
      });
    }

    test('v6 数据库新增事件变更明细表后升级至当前 schema', () async {
      final directory = await Directory.systemTemp.createTemp(
        'anch-db-v6-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}anch.sqlite',
      );
      final seed = AppDatabase.fromOpener(_FileDatabaseOpener(file));
      await seed.customSelect('SELECT 1;').get();
      await seed.close();
      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('DROP TABLE item_event_changes;');
      raw.execute('PRAGMA user_version = 6;');
      raw.close();

      final database = AppDatabase.fromOpener(_FileDatabaseOpener(file));
      addTearDown(database.close);
      expect(await database.select(database.itemEventChanges).get(), isEmpty);
      final userVersion = await database
          .customSelect('PRAGMA user_version;')
          .getSingle();
      expect(userVersion.read<int>('user_version'), 9);
    });

    test('v8 数据库为资料和附件补齐唯一来源标识', () async {
      final directory = await Directory.systemTemp.createTemp(
        'anch-db-v8-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}anch.sqlite',
      );
      final seed = AppDatabase.fromOpener(_FileDatabaseOpener(file));
      await seed.customSelect('SELECT 1;').get();
      await seed.close();

      final raw = sqlite.sqlite3.open(file.path);
      raw.execute('PRAGMA foreign_keys = OFF;');
      raw.execute(
        "INSERT INTO items (id, origin_id, member_id, template_version, "
        "is_favorite, is_pinned, sort_order, status, created_at, updated_at) "
        "VALUES ('v8-item', 'discarded-item-origin', '$systemFamilyMemberId', "
        "1, 0, 0, 0, 'active', 1000, 1000);",
      );
      raw.execute(
        "INSERT INTO attachments (id, origin_attachment_id, item_id, "
        "attachment_role, file_name, mime_type, plain_size, encrypted_size, "
        "sort_order, status, created_at, updated_at) VALUES "
        "('v8-attachment', 'discarded-attachment-origin', 'v8-item', "
        "'proof', 'encrypted.bin', 'application/octet-stream', 1, 1, 0, "
        "'active', 1000, 1000);",
      );
      raw.execute(
        'CREATE TABLE items_v8 AS SELECT id, member_id, category_key, '
        'type_key, template_version, title, primary_text, secondary_text, '
        'summary_text, search_text, note, is_favorite, is_pinned, pinned_at, '
        'sort_order, status, deleted_at, status_before_deletion, created_at, '
        'updated_at, last_viewed_at, metadata FROM items;',
      );
      raw.execute(
        'CREATE TABLE attachments_v8 AS SELECT id, item_id, linked_field_key, '
        'attachment_role, file_name, original_name, mime_type, plain_size, '
        'encrypted_size, sha256, sort_order, status, created_at, updated_at '
        'FROM attachments;',
      );
      raw.execute(
        'CREATE TABLE item_events_v8 AS SELECT id, item_id, event_type, '
        'occurred_at FROM item_events;',
      );
      raw.execute('DROP TABLE item_events;');
      raw.execute('DROP TABLE attachments;');
      raw.execute('DROP TABLE items;');
      raw.execute('ALTER TABLE items_v8 RENAME TO items;');
      raw.execute('ALTER TABLE attachments_v8 RENAME TO attachments;');
      raw.execute('ALTER TABLE item_events_v8 RENAME TO item_events;');
      raw.execute('PRAGMA user_version = 8;');
      raw.close();

      final database = AppDatabase.fromOpener(_FileDatabaseOpener(file));
      addTearDown(database.close);
      final item = (await database.select(database.items).get()).single;
      final attachment =
          (await database.select(database.attachments).get()).single;
      expect(item.originId, item.id);
      expect(attachment.originAttachmentId, attachment.id);
      await expectLater(
        database.customStatement(
          "INSERT INTO items (id, origin_id, template_version, is_favorite, "
          "is_pinned, sort_order, status, created_at, updated_at) VALUES "
          "('duplicate-origin', 'v8-item', 1, 0, 0, 0, 'active', 1000, 1000);",
        ),
        throwsA(isA<sqlite.SqliteException>()),
      );
    });

    test('历史已删除资料升级后视为从当前资料删除', () async {
      final fixture = await _LegacyDatabaseFixture.create(5);
      addTearDown(fixture.dispose);
      final raw = sqlite.sqlite3.open(fixture.file.path);
      raw.execute(
        "UPDATE items SET status = 'deleted' WHERE id = 'legacy-household-book';",
      );
      raw.close();

      final database = AppDatabase.fromOpener(
        _FileDatabaseOpener(fixture.file),
      );
      addTearDown(database.close);
      final item = (await database.select(database.items).get()).single;
      expect(item.status, 'deleted');
      expect(item.deletedAt, 1000);
      expect(item.statusBeforeDeletion, 'active');
    });

    test('拒绝以更高版本号降级打开数据库', () async {
      final fixture = await _LegacyDatabaseFixture.create(3);
      addTearDown(fixture.dispose);
      final raw = sqlite.sqlite3.open(fixture.file.path);
      raw.execute('PRAGMA user_version = 10;');
      raw.close();

      final database = AppDatabase.fromOpener(
        _FileDatabaseOpener(fixture.file),
      );
      addTearDown(database.close);

      await expectLater(
        database.select(database.items).get(),
        throwsA(isA<StateError>()),
      );
    });

    test('v3 子表迁移失败时回滚新建结构并保留旧版本号', () async {
      final fixture = await _LegacyDatabaseFixture.create(
        3,
        omitLegacyFieldValueType: true,
      );
      addTearDown(fixture.dispose);
      final database = AppDatabase.fromOpener(
        _FileDatabaseOpener(fixture.file),
      );

      await expectLater(
        database.select(database.items).get(),
        throwsA(isA<sqlite.SqliteException>()),
      );
      await database.close();

      final raw = sqlite.sqlite3.open(fixture.file.path);
      try {
        expect(raw.select('PRAGMA user_version;').single['user_version'], 3);
        expect(
          raw.select(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name IN ('item_child_entries', 'item_child_fields');",
          ),
          isEmpty,
        );
      } finally {
        raw.close();
      }
    });
  });
}

class _FileDatabaseOpener implements AppDatabaseOpener {
  const _FileDatabaseOpener(this.file);

  final File file;

  @override
  QueryExecutor openConnection() {
    return NativeDatabase(
      file,
      setup: (database) => database.execute('PRAGMA foreign_keys = ON;'),
    );
  }
}

class _LegacyDatabaseFixture {
  _LegacyDatabaseFixture(this.directory, this.file);

  final Directory directory;
  final File file;

  static Future<_LegacyDatabaseFixture> create(
    int version, {
    bool omitLegacyFieldValueType = false,
  }) async {
    final directory = await Directory.systemTemp.createTemp(
      'anch-db-migration-',
    );
    final file = File('${directory.path}${Platform.pathSeparator}anch.sqlite');

    final seed = AppDatabase.fromOpener(_FileDatabaseOpener(file));
    await seed.customSelect('SELECT 1;').get();
    await seed.close();

    final raw = sqlite.sqlite3.open(file.path);
    try {
      raw.execute('PRAGMA foreign_keys = OFF;');
      raw.execute('DROP TABLE item_event_changes;');
      raw.execute('DROP TABLE item_events;');
      if (version < 4) {
        raw.execute('DROP TABLE item_child_fields;');
        raw.execute('DROP TABLE item_child_entries;');
      }
      raw.execute('DROP TABLE members;');
      raw.execute(_membersSql(version));
      raw.execute('DROP TABLE items;');
      raw.execute(_itemsSql(version));
      raw.execute('DROP TABLE item_fields;');
      if (omitLegacyFieldValueType) {
        raw.execute(_itemFieldsWithoutValueTypeSql());
      } else {
        raw.execute(_legacyItemFieldsSql());
      }
      raw.execute('DROP TABLE attachments;');
      raw.execute(_legacyAttachmentsSql());
      raw.execute(
        "INSERT INTO members (id, member_type, name, ${version == 1 ? 'relation_key, ' : ''}"
        'sort_order, is_system, is_archived, created_at, updated_at) '
        "VALUES ('$systemFamilyMemberId', 'family', '家庭', "
        "${version == 1 ? "'family', " : ''}0, 1, 0, 1000, 1000);",
      );
      raw.execute(
        "INSERT INTO items (id, member_id, category_key, type_key, template_version, title, "
        'status, created_at, updated_at) '
        "VALUES ('legacy-household-book', '$systemFamilyMemberId', 'certificate', "
        "'household_book', 1, '户口本', 'active', 1000, 1000);",
      );
      if (version == 4 || version == 5) {
        raw.execute(
          "UPDATE items SET is_pinned = 1${version == 5 ? ', pinned_at = 1000' : ''} "
          "WHERE id = 'legacy-household-book';",
        );
      }
      if (version == 5) {
        raw.execute(
          "UPDATE items SET metadata = '{\"raw_state\":{}}' "
          "WHERE id = 'legacy-household-book';",
        );
      }
      final fieldColumns = omitLegacyFieldValueType
          ? 'id, item_id, field_key, value_text, sort_order, created_at, updated_at'
          : 'id, item_id, field_key, value_type, value_text, sort_order, created_at, updated_at';
      final ownerValues = omitLegacyFieldValueType
          ? "'legacy-owner', 'legacy-household-book', 'page_owner', '迁移成员', 0, 1000, 1000"
          : "'legacy-owner', 'legacy-household-book', 'page_owner', 'text', '迁移成员', 0, 1000, 1000";
      final idValues = omitLegacyFieldValueType
          ? "'legacy-id', 'legacy-household-book', 'id_number', '110101199003072345', 1, 1000, 1000"
          : "'legacy-id', 'legacy-household-book', 'id_number', 'text', '110101199003072345', 1, 1000, 1000";
      raw.execute(
        "INSERT INTO item_fields ($fieldColumns) VALUES ($ownerValues);",
      );
      raw.execute(
        "INSERT INTO item_fields ($fieldColumns) VALUES ($idValues);",
      );
      raw.execute('PRAGMA user_version = $version;');
    } finally {
      raw.close();
    }

    return _LegacyDatabaseFixture(directory, file);
  }

  Future<void> dispose() => directory.delete(recursive: true);
}

String _membersSql(int version) {
  final relationKey = version == 1 ? ', relation_key TEXT NOT NULL' : '';
  return 'CREATE TABLE members ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'member_type TEXT NOT NULL, '
      'name TEXT NOT NULL'
      '$relationKey, '
      'avatar_key TEXT NULL, '
      'note TEXT NULL, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'is_system INTEGER NOT NULL DEFAULT 0, '
      'is_archived INTEGER NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL);';
}

String _itemsSql(int version) {
  final isV3OrLater = version >= 3;
  final nullable = isV3OrLater ? 'NULL' : 'NOT NULL';
  final metadata = isV3OrLater ? ', metadata TEXT NULL' : '';
  return 'CREATE TABLE items ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'member_id TEXT $nullable REFERENCES members (id) ON DELETE RESTRICT, '
      'category_key TEXT $nullable, '
      'type_key TEXT $nullable, '
      'template_version INTEGER NOT NULL DEFAULT 1, '
      'title TEXT $nullable, '
      'primary_text TEXT NULL, '
      'secondary_text TEXT NULL, '
      'summary_text TEXT NULL, '
      'search_text TEXT NULL, '
      'note TEXT NULL, '
      'is_favorite INTEGER NOT NULL DEFAULT 0, '
      'is_pinned INTEGER NOT NULL DEFAULT 0, '
      '${version >= 5 ? 'pinned_at INTEGER NULL, ' : ''}'
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      "status TEXT NOT NULL DEFAULT 'active', "
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'last_viewed_at INTEGER NULL'
      '$metadata);';
}

String _legacyItemFieldsSql() {
  return 'CREATE TABLE item_fields ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'item_id TEXT NOT NULL REFERENCES items (id) ON DELETE CASCADE, '
      'field_key TEXT NOT NULL, '
      'value_type TEXT NOT NULL, '
      'value_text TEXT NULL, '
      'normalized_value TEXT NULL, '
      'field_note TEXT NULL, '
      'template_field_known INTEGER NOT NULL DEFAULT 1, '
      'is_archived_field INTEGER NOT NULL DEFAULT 0, '
      'archived_reason TEXT NULL, '
      'raw_field_label TEXT NULL, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'UNIQUE (item_id, field_key));';
}

String _legacyAttachmentsSql() {
  return 'CREATE TABLE attachments ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'item_id TEXT NOT NULL REFERENCES items (id) ON DELETE CASCADE, '
      'linked_field_key TEXT NULL, '
      'attachment_role TEXT NOT NULL, '
      'file_name TEXT NOT NULL, '
      'original_name TEXT NULL, '
      'mime_type TEXT NOT NULL, '
      'plain_size INTEGER NOT NULL DEFAULT 0, '
      'encrypted_size INTEGER NOT NULL DEFAULT 0, '
      'sha256 TEXT NULL, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      "status TEXT NOT NULL DEFAULT 'active', "
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL);';
}

String _itemFieldsWithoutValueTypeSql() {
  return 'CREATE TABLE item_fields ('
      'id TEXT NOT NULL PRIMARY KEY, '
      'item_id TEXT NOT NULL REFERENCES items (id) ON DELETE CASCADE, '
      'field_key TEXT NOT NULL, '
      'value_text TEXT NULL, '
      'sort_order INTEGER NOT NULL DEFAULT 0, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL, '
      'UNIQUE (item_id, field_key));';
}
