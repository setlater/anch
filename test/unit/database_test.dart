import 'package:sqlite3/sqlite3.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // 使用内存临时数据库进行测试
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
  });

  tearDown(() async {
    await db.close();
  });

  test('验证 onCreate 是否成功初始化系统虚拟成员', () async {
    final allMembers = await db.select(db.members).get();
    expect(allMembers.length, 2);
    
    final familyMember = allMembers.firstWhere((m) => m.id == systemFamilyMemberId);
    expect(familyMember.memberType, 'family');
    expect(familyMember.name, '家庭');
    expect(familyMember.isSystem, true);
    expect(familyMember.isArchived, false);

    final meMember = allMembers.firstWhere((m) => m.id == systemMeMemberId);
    expect(meMember.memberType, 'person');
    expect(meMember.name, '我');
    expect(meMember.isSystem, true);
    expect(meMember.isArchived, false);
  });

  test('验证外键约束开启拦截', () async {
    // 确保 PRAGMA foreign_keys = ON; 生效，验证数据库外键保护屏障
    
    // 1. 验证连接上查 PRAGMA foreign_keys
    final result = await db.customSelect('PRAGMA foreign_keys;').getSingle();
    final foreignKeysEnabled = result.read<int>('foreign_keys');
    expect(foreignKeysEnabled, 1, reason: '外键约束必须启用 (PRAGMA foreign_keys = ON)');

    // 2. 插入一条不存在 memberId 的 item，应当抛出 SqliteException 外键约束违背错误
    final now = DateTime.now().millisecondsSinceEpoch;
    final testItem = ItemsCompanion.insert(
      id: 'test-item-uuid-1234',
      originId: 'test-item-uuid-1234',
      memberId: const Value('non-existent-member-id'), // 不存在的成员
      categoryKey: const Value('certificate'),
      typeKey: const Value('id_card'),
      title: const Value('测试身份证'),
      createdAt: now,
      updatedAt: now,
    );

    expect(
      () => db.into(db.items).insert(testItem),
      throwsA(isA<SqliteException>()),
    );
  });
}
