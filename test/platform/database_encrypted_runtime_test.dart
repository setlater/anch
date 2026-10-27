@Tags(['platform'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/template/field_value_type.dart';

// ============================================================
// 加密数据库运行态行为测试
//
// 本测试模拟 App 主路径的完整持久化行为：
//   写入 → 关闭 → 同密钥重开 → 成员/类型/详情路径读取
//
// 测试环境说明：
//   sqlite3mc hooks 在宿主 Dart VM 也生效（第一批实测），
//   PRAGMA key 能真实加密文件，因此本测试的持久化验证是真实的。
//
// 测试覆盖：
//   1. 写入一条资料 → close → 同密钥重开 → Repository 层读取
//   2. 成员维度查询（按 memberId 过滤）
//   3. 类型维度查询（按 typeKey 过滤）
//   4. 详情路径读取（ItemWithFields，含字段）
//   5. 高敏字段值在 DB 层正确存储（不做掩码，UI 掩码由 widget 层处理）
//   6. 多条资料持久化与列表读取
//   7. inMemory opener 重开后仍不持久化（原有行为保持不变）
//   8. 错误密钥失败测试（保留）
// ============================================================

EncryptedAppDatabaseOpener _makeOpener(Directory dir, String name) {
  return EncryptedAppDatabaseOpener(
    databaseKey: 'test-placeholder-key-do-not-use-in-prod',
    databaseName: name,
    directoryOverride: dir,
  );
}

/// 构造标准测试写入资料（不含真实敏感信息）
SaveItemInput _makeTestItem({
  String memberId = systemFamilyMemberId,
  String title = '运行态测试身份证',
  String nameValue = '测试用户',
  String idNumberValue = '110101199001011234',
}) {
  return SaveItemInput(
    memberId: memberId,
    categoryKey: 'certificate',
    typeKey: 'id_card',
    title: title,
    primaryText: nameValue,
    secondaryText: '身份证',
    fields: [
      SaveItemFieldInput(
        fieldKey: 'name',
        valueType: FieldValueType.sensitiveText,
        valueText: nameValue,
      ),
      SaveItemFieldInput(
        fieldKey: 'id_number',
        valueType: FieldValueType.idNumber,
        valueText: idNumberValue,
        normalizedValue: idNumberValue.length >= 4
            ? idNumberValue.substring(idNumberValue.length - 4)
            : idNumberValue,
      ),
    ],
  );
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('anch_runtime_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ----------------------------------------------------------------
  // 一、核心持久化路径：写入 → close → 同密钥重开 → 读取
  // ----------------------------------------------------------------
  group('加密模式运行态 — 核心持久化路径验证', () {
    const dbName = 'runtime_persist.db';

    test('验证 1. 写入资料 → close → 同密钥重开 → Repository 层可读取', () async {
      late String savedItemId;

      // --- 第一次打开：写入 ---
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbName));
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(_makeTestItem());
          expect(savedItemId, isNotEmpty);

          // 确认当次写入可读
          final item = await itemRepo.getItemWithFields(savedItemId);
          expect(item, isNotNull);
          expect(item!.title, '运行态测试身份证');
        } finally {
          await db.close();
        }
      }

      // 确认数据库文件已持久化到磁盘
      final dbFile = File('${tempDir.path}/$dbName');
      expect(dbFile.existsSync(), isTrue, reason: '加密数据库文件应当已持久化');

      // --- 第二次打开（同密钥）：验证数据可读 ---
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbName));
        final itemRepo = ItemRepository(db);
        try {
          final item = await itemRepo.getItemWithFields(savedItemId);
          expect(item, isNotNull, reason: '同密钥重开后应能读取之前写入的资料');
          expect(item!.id, savedItemId);
          expect(item.title, '运行态测试身份证');
          expect(item.categoryKey, 'certificate');
          expect(item.typeKey, 'id_card');
        } finally {
          await db.close();
        }
      }
    });

    test('验证 2. 成员维度查询 — getRecentItemsForSession 可读到持久化资料', () async {
      late String savedItemId;

      // 第一次：写入
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbName));
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(
            _makeTestItem(title: '成员维度测试'),
          );
        } finally {
          await db.close();
        }
      }

      // 第二次：通过成员维度（最近会话列表）读取
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbName));
        final itemRepo = ItemRepository(db);
        try {
          // getRecentItemsForSession 查询所有 active 状态资料（按 updatedAt 倒序）
          final recentItems = await itemRepo.getRecentItemsForSession();
          expect(recentItems, isNotEmpty, reason: '成员维度：重开后应能读到持久化资料');

          final found = recentItems.where((i) => i.id == savedItemId).toList();
          expect(found.length, 1, reason: '应能通过 savedItemId 定位到资料');
          expect(found.first.memberId, systemFamilyMemberId);
          expect(found.first.title, '成员维度测试');
        } finally {
          await db.close();
        }
      }
    });

    test('验证 3. 类型维度查询 — 重开后按 typeKey 可过滤到持久化资料', () async {
      const dbNameType = 'runtime_type_query.db';
      late String savedItemId;

      // 第一次：写入
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameType));
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(
            _makeTestItem(title: '类型维度测试资料'),
          );
        } finally {
          await db.close();
        }
      }

      // 第二次：重开，按 typeKey = 'id_card' 过滤
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameType));
        final itemRepo = ItemRepository(db);
        try {
          final recentItems = await itemRepo.getRecentItemsForSession();
          final idCardItems = recentItems
              .where((i) => i.typeKey == 'id_card')
              .toList();

          expect(idCardItems, isNotEmpty, reason: '类型维度：重开后应能按 typeKey 过滤到资料');
          final found = idCardItems.where((i) => i.id == savedItemId).toList();
          expect(found.length, 1, reason: '按类型维度应能定位到资料');
          expect(found.first.categoryKey, 'certificate');
        } finally {
          await db.close();
        }
      }
    });

    test('验证 4. 详情路径 — 重开后 getItemWithFields 包含完整字段', () async {
      const dbNameDetail = 'runtime_detail.db';
      late String savedItemId;

      // 第一次：写入
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameDetail));
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(
            _makeTestItem(
              title: '详情路径测试',
              nameValue: '测试用户',
              idNumberValue: '110101199001011234',
            ),
          );
        } finally {
          await db.close();
        }
      }

      // 第二次：重开，验证 ItemWithFields（含字段）
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameDetail));
        final itemRepo = ItemRepository(db);
        try {
          final item = await itemRepo.getItemWithFields(savedItemId);
          expect(item, isNotNull, reason: '详情路径：重开后应能读取 ItemWithFields');
          expect(item!.fields.length, 2, reason: '字段应完整持久化');

          final nameField =
              item.fields.where((f) => f.fieldKey == 'name').toList();
          expect(nameField.length, 1);
          expect(
            nameField.first.valueText,
            '测试用户',
            reason: '姓名字段值应持久化正确',
          );
          expect(
            nameField.first.valueType,
            'sensitive_text',
            reason: '高敏字段类型应在 DB 层正确存储',
          );

          final idField =
              item.fields.where((f) => f.fieldKey == 'id_number').toList();
          expect(idField.length, 1);
          expect(idField.first.valueText, '110101199001011234');
          expect(idField.first.normalizedValue, '1234', reason: '尾号应正确持久化');
        } finally {
          await db.close();
        }
      }
    });

    test('验证 5. 高敏字段在 DB 层以 sensitive_text 类型正确存储', () async {
      const dbNameSensitive = 'runtime_sensitive.db';
      late String savedItemId;

      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameSensitive));
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(
            _makeTestItem(nameValue: '测试用户'),
          );
        } finally {
          await db.close();
        }
      }

      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameSensitive));
        final itemRepo = ItemRepository(db);
        try {
          final item = await itemRepo.getItemWithFields(savedItemId);
          expect(item, isNotNull);

          final sensitiveField =
              item!.fields.where((f) => f.fieldKey == 'name').first;
          // DB 层存储的是 valueType 字符串 'sensitive_text'
          // UI 掩码逻辑由 Widget 层处理，此处验证 DB 层数据完整性
          expect(sensitiveField.valueType, 'sensitive_text');
          expect(sensitiveField.valueText, '测试用户');
        } finally {
          await db.close();
        }
      }
    });
  });

  // ----------------------------------------------------------------
  // 二、多条资料持久化
  // ----------------------------------------------------------------
  group('加密模式运行态 — 多条资料持久化与列表读取', () {
    test('验证 6. 多条资料写入 → 重开 → 列表全部可读', () async {
      const dbNameMulti = 'runtime_multi.db';
      final savedIds = <String>[];

      // 第一次：写入 3 条
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameMulti));
        final itemRepo = ItemRepository(db);
        try {
          for (var i = 1; i <= 3; i++) {
            final id = await itemRepo.saveItemWithFields(
              _makeTestItem(
                title: '多条测试资料 $i',
                nameValue: '测试用户 $i',
              ),
            );
            savedIds.add(id);
          }
          expect(savedIds.length, 3);
        } finally {
          await db.close();
        }
      }

      // 第二次：重开，验证列表全部可读
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameMulti));
        final itemRepo = ItemRepository(db);
        try {
          final recentItems = await itemRepo.getRecentItemsForSession();
          expect(recentItems.length, 3, reason: '3 条资料应全部持久化且可读');

          for (final id in savedIds) {
            final found = recentItems.where((i) => i.id == id).toList();
            expect(found.length, 1, reason: 'id=$id 的资料应存在于列表中');
          }
        } finally {
          await db.close();
        }
      }
    });
  });

  // ----------------------------------------------------------------
  // 三、成员初始化持久化验证
  // ----------------------------------------------------------------
  group('加密模式运行态 — 成员层持久化验证', () {
    test('验证 7. 同密钥重开后 MemberRepository 可读取初始化成员', () async {
      const dbNameMember = 'runtime_member.db';

      // 第一次：触发 onCreate
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameMember));
        final memberRepo = MemberRepository(db);
        try {
          final members = await memberRepo.getActiveMembers();
          expect(members.length, 2);
          expect(members[0].name, '家庭');
          expect(members[1].name, '我');
        } finally {
          await db.close();
        }
      }

      // 第二次：重开，成员数据应持久化
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameMember));
        final memberRepo = MemberRepository(db);
        try {
          final members = await memberRepo.getActiveMembers();
          expect(
            members.length,
            2,
            reason: '重开后成员初始化数据应持久化',
          );
          expect(members[0].name, '家庭');
          expect(members[1].name, '我');
          expect(members.first.id, systemFamilyMemberId);
          expect(members.first.isSystem, true);
        } finally {
          await db.close();
        }
      }
    });
  });

  // ----------------------------------------------------------------
  // 四、默认 inMemory 模式回退验证
  // ----------------------------------------------------------------
  group('默认 inMemory 模式 — 重开后不持久化（原有行为）', () {
    test('验证 8. inMemory opener 重开后数据不持久化', () async {
      late String savedItemId;

      // 第一次内存数据库：写入
      {
        final opener = NativeAppDatabaseOpener(inMemory: true);
        final db = AppDatabase.fromOpener(opener);
        final itemRepo = ItemRepository(db);
        try {
          savedItemId = await itemRepo.saveItemWithFields(
            _makeTestItem(title: 'inMemory 回退测试'),
          );
          final items = await db.select(db.items).get();
          expect(items.length, 1);
        } finally {
          await db.close();
        }
      }

      // 第二次全新内存数据库：数据不应跨实例持久
      {
        final opener = NativeAppDatabaseOpener(inMemory: true);
        final db = AppDatabase.fromOpener(opener);
        final itemRepo = ItemRepository(db);
        try {
          final item = await itemRepo.getItemWithFields(savedItemId);
          expect(
            item,
            isNull,
            reason: 'inMemory 模式重开后，上次写入的资料不应可见（回退行为正确）',
          );

          final allItems = await db.select(db.items).get();
          expect(
            allItems,
            isEmpty,
            reason: 'inMemory 数据库每次重新初始化，不应保留上次实例的数据',
          );
        } finally {
          await db.close();
        }
      }
    });
  });

  // ----------------------------------------------------------------
  // 五、错误密钥验证（保留）
  // ----------------------------------------------------------------
  group('错误密钥验证 — 保留', () {
    test('验证 9. 错误密钥打开已加密文件应触发异常', () async {
      const dbNameWrongKey = 'runtime_wrong_key.db';

      // 第一次：用开发验证密钥体系 / 非正式生产准入写入
      {
        final db = AppDatabase.fromOpener(_makeOpener(tempDir, dbNameWrongKey));
        try {
          await db.select(db.members).get();
        } finally {
          await db.close();
        }
      }

      // 第二次：用错误密钥打开，应触发异常
      {
        final db = AppDatabase.fromOpener(
          EncryptedAppDatabaseOpener(
            databaseKey: 'test-placeholder-key-do-not-use-in-prod',
            databaseName: dbNameWrongKey,
            directoryOverride: tempDir,
            databaseKeyOverrideForTest: 'totally-wrong-key-12345',
          ),
        );
        try {
          await expectLater(
            db.select(db.members).get(),
            throwsException,
            reason: 'sqlite3mc 以错误密钥打开已加密文件应抛出异常',
          );
        } finally {
          try {
            await db.close();
          } catch (_) {}
        }
      }
    });
  });
}
