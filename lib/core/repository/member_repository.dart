import 'dart:math';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'models/member_model.dart';
import 'models/save_member_input.dart';

/// 家庭成员数据访问 Repository (完全隔离 Drift 实体)
class MemberRepository {
  final AppDatabase db;

  /// DO NOT instantiate directly outside DI layer.
  MemberRepository(this.db);

  /// 原生生成高安全强度的 UUID v4 字符串
  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant RFC4122

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 转换数据库物理实体至业务模型
  MemberModel _mapToModel(Member m) {
    return MemberModel(
      id: m.id,
      memberType: m.memberType,
      name: m.name,
      avatarKey: m.avatarKey,
      note: m.note,
      sortOrder: m.sortOrder,
      isSystem: m.isSystem,
      isArchived: m.isArchived,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  /// 在启动、重置或恢复边界显式补齐系统成员，兼容存量数据库。
  Future<void> ensureSystemMembersExist() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.members)
        .insert(
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
          mode: InsertMode.insertOrIgnore,
        );
    await db
        .into(db.members)
        .insert(
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
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// 获取所有活跃（未归档）的成员，按 sortOrder 升序排列
  Future<List<MemberModel>> getActiveMembers() async {
    final list =
        await (db.select(db.members)
              ..where((tbl) => tbl.isArchived.equals(false))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();
    return list.map(_mapToModel).toList();
  }

  /// 获取所有成员（包含已归档成员）
  Future<List<MemberModel>> getAllMembers() async {
    final list = await (db.select(
      db.members,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)])).get();
    return list.map(_mapToModel).toList();
  }

  /// 保存或更新成员（如果主键触发冲突，执行更新）
  Future<String> saveMember(SaveMemberInput input) async {
    final memberId = input.id ?? _generateUuid();

    // 强制安全性校验保护
    if (memberId == systemFamilyMemberId || memberId == systemMeMemberId) {
      throw UnsupportedError('系统内置成员禁止通过常规接口修改或保存。');
    }
    if (input.isSystem) {
      throw UnsupportedError('禁止通过常规接口创建或保存系统内置成员。');
    }
    if (input.memberType == 'family') {
      throw UnsupportedError('禁止通过常规接口创建或保存虚拟“家庭”类型成员。');
    }

    final existing = input.id != null ? await getMemberById(input.id!) : null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final companion = MembersCompanion(
      id: Value(memberId),
      memberType: Value(input.memberType),
      name: Value(input.name),
      avatarKey: Value(input.avatarKey),
      note: Value(input.note),
      sortOrder: Value(input.sortOrder),
      isSystem: Value(input.isSystem),
      isArchived: Value(input.isArchived),
      updatedAt: Value(now),
      createdAt: Value(existing?.createdAt ?? now),
    );

    await db.into(db.members).insertOnConflictUpdate(companion);
    return memberId;
  }

  /// 批量更新自定义成员的展示顺序
  Future<void> updateMembersOrder(List<String> memberIds) async {
    await db.transaction(() async {
      for (int i = 0; i < memberIds.length; i++) {
        final id = memberIds[i];
        if (id == systemFamilyMemberId || id == systemMeMemberId) continue;
        await (db.update(db.members)..where((tbl) => tbl.id.equals(id))).write(
          MembersCompanion(
            sortOrder: Value(i + 2), // “家庭”为 0，“我”为 1，自定义成员从 2 开始
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        );
      }
    });
  }

  /// 归档成员（系统内置家庭/“我”成员不可归档）
  Future<void> archiveMember(String memberId) async {
    if (memberId == systemFamilyMemberId || memberId == systemMeMemberId) {
      throw UnsupportedError('系统内置成员禁止被归档。');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await (db.update(
      db.members,
    )..where((tbl) => tbl.id.equals(memberId))).write(
      MembersCompanion(isArchived: const Value(true), updatedAt: Value(now)),
    );
  }

  /// 根据成员 ID 获取成员业务模型
  Future<MemberModel?> getMemberById(String memberId) async {
    final member = await (db.select(
      db.members,
    )..where((tbl) => tbl.id.equals(memberId))).getSingleOrNull();
    return member == null ? null : _mapToModel(member);
  }
}
