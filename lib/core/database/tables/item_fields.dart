import 'package:drift/drift.dart';
import 'items.dart';

/// 资料动态字段表
@TableIndex(name: 'idx_fields_item_sort', columns: {#itemId, #sortOrder})
@TableIndex(
  name: 'idx_fields_normalized',
  columns: {#fieldKey, #normalizedValue},
)
class ItemFields extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 所属资料 ID，外键级联删除
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  /// 字段 Key
  TextColumn get fieldKey => text()();

  /// 字段值类型
  TextColumn get valueType => text()();

  /// 原始展示明文
  TextColumn get valueText => text().nullable()();

  /// 标准化值（低敏）
  TextColumn get normalizedValue => text().nullable()();

  /// 字段级备注
  TextColumn get fieldNote => text().nullable()();

  /// 恢复旧备份时的字段中文名
  TextColumn get rawFieldLabel => text().nullable()();

  /// 字段显示顺序
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  /// 联合唯一约束：同一资料下 fieldKey 唯一
  @override
  List<Set<Column>> get uniqueKeys => [
    {itemId, fieldKey},
  ];
}
