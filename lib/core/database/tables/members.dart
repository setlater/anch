import 'package:drift/drift.dart';

/// 家庭成员表
@TableIndex(name: 'idx_members_type_sort', columns: {#memberType, #sortOrder})
@TableIndex(name: 'idx_members_archived', columns: {#isArchived})
class Members extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 成员类型：person (真实人) / family (虚拟家庭)
  TextColumn get memberType => text()();

  /// 成员显示名称
  TextColumn get name => text()();

  /// 头像/图标 Key
  TextColumn get avatarKey => text().nullable()();

  /// 成员备注
  TextColumn get note => text().nullable()();

  /// 手动排序权重值
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 是否为系统内置成员
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  /// 是否归档
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
