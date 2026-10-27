@Tags(['platform'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/template/field_value_type.dart';

const String _kTestKey = 'test-placeholder-key-do-not-use-in-prod';

// ============================================================
// 重要背景：sqlite3mc hooks 机制说明
//
// sqlite3mc 仅在 Flutter 原生构建（flutter build apk / flutter run）时
// 通过 build hooks 将 sqlite3mc 静态库链入 Android/iOS 原生层。
//
// 在 `fvm flutter test`（Dart VM 环境）中：
// - 宿主机使用系统 SQLite，不具备 sqlite3mc 功能
// - PRAGMA key / PRAGMA cipher_version 会被静默忽略或报错
// - 加密文件的实际保护效果无法在测试中验证
//
// 因此本测试的目标是：
// 2. 验证基础 CRUD、外键、持久化等数据库逻辑在加密 opener 下正常工作
// 3. 验证错误密钥在设备端的行为说明（测试仅做存档验证）
// 4. 验证 inMemory opener 完全不受影响
//
// 实际加密效果（cipher_version 断言、加密文件保护）需在 Android 模拟器/真机上验证：
//   fvm flutter run -d emulator-5554 --dart-define=ANCH_USE_ENCRYPTED_DB=true
// ============================================================

void main() {
  late Directory tempDir;

  setUp(() async {
    // 使用系统临时目录，避免依赖 app 私有 documents 目录（测试环境不可用）
    tempDir = await Directory.systemTemp.createTemp('anch_encrypted_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('EncryptedAppDatabaseOpener — 基础功能验证', () {
    test('验证 1. 加密 opener 可以创建 AppDatabase 并执行基础初始化', () async {
      final opener = EncryptedAppDatabaseOpener(
        databaseKey: _kTestKey,
        databaseName: 'test_encrypted.db',
        directoryOverride: tempDir,
      );
      final db = AppDatabase.fromOpener(opener);

      try {
        // 验证 onCreate 初始化（包含"家庭"和"我"系统成员）
        final members = await db.select(db.members).get();
        expect(members.length, 2);
        expect(members.any((m) => m.id == systemFamilyMemberId && m.name == '家庭' && m.isSystem), true);
        expect(members.any((m) => m.id == systemMeMemberId && m.name == '我' && m.isSystem), true);
      } finally {
        await db.close();
      }
    });

    test('验证 2. 加密 opener 外键约束正常工作', () async {
      final opener = EncryptedAppDatabaseOpener(
        databaseKey: _kTestKey,
        databaseName: 'test_encrypted_fk.db',
        directoryOverride: tempDir,
      );
      final db = AppDatabase.fromOpener(opener);

      try {
        final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
        final foreignKeysEnabled = result.read<int>('foreign_keys');
        expect(foreignKeysEnabled, 1, reason: '加密数据库外键约束必须启用');
      } finally {
        await db.close();
      }
    });

    test('验证 3. 加密 opener 可以执行完整 CRUD 并级联删除', () async {
      final opener = EncryptedAppDatabaseOpener(
        databaseKey: _kTestKey,
        databaseName: 'test_encrypted_crud.db',
        directoryOverride: tempDir,
      );
      final db = AppDatabase.fromOpener(opener);
      final itemRepo = ItemRepository(db);

      try {
        // 写入一条资料
        final saveInput = SaveItemInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'certificate',
          typeKey: 'id_card',
          title: '加密测试身份证',
          primaryText: '测试人',
          secondaryText: '身份证',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'name',
              valueType: FieldValueType.sensitiveText,
              valueText: '测试人',
            ),
            SaveItemFieldInput(
              fieldKey: 'id_number',
              valueType: FieldValueType.idNumber,
              valueText: '110101199003072345',
              normalizedValue: '2345',
            ),
          ],
        );

        final itemId = await itemRepo.saveItemWithFields(saveInput);
        expect(itemId, isNotEmpty);

        // 读取验证
        final retrieved = await itemRepo.getItemWithFields(itemId);
        expect(retrieved, isNotNull);
        expect(retrieved!.title, '加密测试身份证');
        expect(retrieved.fields.length, 2);

        // 级联删除验证
        await itemRepo.deleteItem(itemId);
        final checkItem = await itemRepo.getItemWithFields(itemId);
        expect(checkItem, isNull);

        final allFields = await db.select(db.itemFields).get();
        expect(allFields, isEmpty, reason: '级联删除后字段必须自动清除');
      } finally {
        await db.close();
      }
    });
  });

  group('EncryptedAppDatabaseOpener — 同密钥重开数据持久化验证', () {
    test('验证 4. 同密钥重开数据库后可以读到之前写入的数据', () async {
      const dbName = 'test_encrypted_persist.db';

      // 第一次打开：触发 onCreate，确保数据库文件已创建
      {
        final opener = EncryptedAppDatabaseOpener(
          databaseKey: _kTestKey,
          databaseName: dbName,
          directoryOverride: tempDir,
        );
        final db = AppDatabase.fromOpener(opener);
        final memberRepo = MemberRepository(db);
        try {
          final members = await memberRepo.getActiveMembers();
          expect(members.length, 2); // 系统"家庭"和"我"成员
        } finally {
          await db.close();
        }
      }

      // 确认数据库文件已创建
      final dbFile = File('${tempDir.path}/$dbName');
      expect(dbFile.existsSync(), isTrue, reason: '数据库文件应当已持久化到磁盘');

      // 第二次打开同一文件（同密钥）：验证数据持久化
      {
        final opener = EncryptedAppDatabaseOpener(
          databaseKey: _kTestKey,
          databaseName: dbName,
          directoryOverride: tempDir,
        );
        final db = AppDatabase.fromOpener(opener);
        final memberRepo = MemberRepository(db);
        try {
          final members = await memberRepo.getActiveMembers();
          expect(
            members.length,
            2,
            reason: '同密钥重开应能读到之前初始化的数据（文件持久化成功）',
          );
          expect(members.first.id, systemFamilyMemberId);
        } finally {
          await db.close();
        }
      }
    });
  });

  group('EncryptedAppDatabaseOpener — 错误密钥验证', () {
    test(
      '验证 5. 使用错误密钥打开已加密数据库时，应触发 SqliteException（file is not a database）',
      () async {
        // ✅ 实测发现：sqlite3mc hooks 在宿主 Dart VM 测试环境中也生效（第一批接入时验证）
        // 因此 PRAGMA key 能真实加密文件，以错误密钥重开时
        // sqlite3mc 会抛出 SqliteException(26: file is not a database)
        // 这正是预期的密钥保护行为

        const dbName = 'test_encrypted_wrong_key.db';

        // 第一次：用开发验证密钥体系 / 非正式生产准入写入（文件将被真实加密）
        {
          final opener = EncryptedAppDatabaseOpener(
            databaseKey: _kTestKey,
            databaseName: dbName,
            directoryOverride: tempDir,
          );
          final db = AppDatabase.fromOpener(opener);
          try {
            // 触发 onCreate，确保文件已创建并以该开发验证密钥加密
            await db.select(db.members).get();
          } finally {
            await db.close();
          }
        }

        // 确认加密文件已存在
        final dbFile = File('${tempDir.path}/$dbName');
        expect(dbFile.existsSync(), isTrue, reason: '加密数据库文件应当已创建');

        // 第二次：用错误密钥打开同一加密文件，应触发 SqliteException
        {
          final opener = EncryptedAppDatabaseOpener(
            databaseKey: _kTestKey,
            databaseName: dbName,
            directoryOverride: tempDir,
            databaseKeyOverrideForTest: 'totally-wrong-key-12345',
          );
          final db = AppDatabase.fromOpener(opener);
          try {
            // 期望抛出异常（file is not a database / SQLITE_NOTADB code 26）
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
      },
    );
  });

  group('NativeAppDatabaseOpener — inMemory 原有功能不受影响', () {
    test('验证 6. inMemory opener 原有行为继续正常工作', () async {
      final opener = NativeAppDatabaseOpener(inMemory: true);
      final db = AppDatabase.fromOpener(opener);

      try {
        final members = await db.select(db.members).get();
        expect(members.length, 2);
        expect(members.any((m) => m.name == '家庭'), true);
        expect(members.any((m) => m.name == '我'), true);

        // 验证外键约束
        final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
        expect(result.read<int>('foreign_keys'), 1);
      } finally {
        await db.close();
      }
    });

    test('验证 7. inMemory 数据库不持久化（每次重新初始化）', () async {
      // 第一次内存数据库实例
      final opener1 = NativeAppDatabaseOpener(inMemory: true);
      final db1 = AppDatabase.fromOpener(opener1);
      final itemRepo1 = ItemRepository(db1);

      final saveInput = SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: '内存测试资料',
        primaryText: '测试',
        secondaryText: '证件',
        fields: [
          SaveItemFieldInput(
            fieldKey: 'name',
            valueType: FieldValueType.sensitiveText,
            valueText: '内存测试',
          ),
        ],
      );

      await itemRepo1.saveItemWithFields(saveInput);
      final items1 = await db1.select(db1.items).get();
      expect(items1.length, 1);
      await db1.close();

      // 第二次全新内存数据库实例，数据不应跨实例持久
      final opener2 = NativeAppDatabaseOpener(inMemory: true);
      final db2 = AppDatabase.fromOpener(opener2);
      try {
        final items2 = await db2.select(db2.items).get();
        expect(
          items2,
          isEmpty,
          reason: 'inMemory 数据库每次重新初始化，不应保留上次实例的数据',
        );
      } finally {
        await db2.close();
      }
    });
  });

  group('EncryptedAppDatabaseOpener — 集成 AppKeyManager 校验', () {
    test('验证 8. 集成 MemorySecureKeyValueStore，写入并重开可读', () async {
      final fakeStore = MemorySecureKeyValueStore();
      final keyManager = SecureStorageAppKeyManager(store: fakeStore);
      final key = await keyManager.getOrCreateDatabaseKey();

      const dbName = 'test_integration_key_manager.db';

      // 1. 写入数据并关闭
      {
        final opener = EncryptedAppDatabaseOpener(
          databaseKey: key,
          databaseName: dbName,
          directoryOverride: tempDir,
        );
        final db = AppDatabase.fromOpener(opener);
        final itemRepo = ItemRepository(db);
        try {
          final saveInput = SaveItemInput(
            memberId: systemFamilyMemberId,
            categoryKey: 'certificate',
            typeKey: 'id_card',
            title: '集成测试数据',
            primaryText: '测试用户',
            secondaryText: '身份测试',
            fields: [
              SaveItemFieldInput(
                fieldKey: 'name',
                valueType: FieldValueType.sensitiveText,
                valueText: '测试用户',
              ),
            ],
          );
          await itemRepo.saveItemWithFields(saveInput);
        } finally {
          await db.close();
        }
      }

      // 2. 再次读取（使用同一个 keyManager 再次获取同一个 key）
      {
        final sameKey = await keyManager.getOrCreateDatabaseKey();
        final opener = EncryptedAppDatabaseOpener(
          databaseKey: sameKey,
          databaseName: dbName,
          directoryOverride: tempDir,
        );
        final db = AppDatabase.fromOpener(opener);
        final itemRepo = ItemRepository(db);
        try {
          final recent = await itemRepo.getRecentItemsForSession();
          expect(recent.length, 1);
          expect(recent.first.title, '集成测试数据');
        } finally {
          await db.close();
        }
      }
    });
  });
}
