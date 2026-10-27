import 'package:drift/drift.dart';
import 'item_child_entries.dart';

/// 资料子项的属性字段表（如户口本多成员的每个字段详情）
@TableIndex(
  name: 'idx_child_fields_entry_sort',
  columns: {#childEntryId, #sortOrder},
)
class ItemChildFields extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 所属子项 ID，外键级联删除
  TextColumn get childEntryId =>
      text().references(ItemChildEntries, #id, onDelete: KeyAction.cascade)();

  /// 字段 Key
  TextColumn get fieldKey => text()();

  /// 字段展示中文名
  TextColumn get label => text()();

  /// 原始展示明文值
  TextColumn get valueText => text().nullable()();

  /// 字段值格式类型
  TextColumn get valueType => text()();

  /// 敏感级别
  TextColumn get sensitiveLevel => text()();

  /// 是否可复制
  BoolColumn get copyable => boolean().withDefault(const Constant(false))();

  /// 是否可被搜索索引
  BoolColumn get searchable => boolean().withDefault(const Constant(false))();

  /// 是否作为摘要展现的来源之一
  BoolColumn get summary => boolean().withDefault(const Constant(false))();

  /// 字段显示顺序
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// 联合唯一约束：同一子项下属性 fieldKey 唯一
  @override
  List<Set<Column>> get uniqueKeys => [
    {childEntryId, fieldKey},
  ];
}
