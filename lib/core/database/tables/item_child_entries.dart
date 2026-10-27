import 'package:drift/drift.dart';
import 'items.dart';

/// 资料子表项记录（支持 1-N 可重复子项，如户口本多成员）
@TableIndex(
  name: 'idx_child_entries_item_sort',
  columns: {#itemId, #childType, #sortOrder},
)
class ItemChildEntries extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 所属资料 ID，外键级联删除
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  /// 子项类型（例如 'household_member'）
  TextColumn get childType => text()();

  /// 字段显示顺序
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// 联合唯一约束：同一资料下同类子项的 sortOrder 唯一，防排序冲突
  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, childType, sortOrder},
  ];
}
