import 'package:drift/drift.dart';
import 'members.dart';

/// 资料主表
@TableIndex(name: 'idx_items_member_status', columns: {#memberId, #status})
@TableIndex(name: 'idx_items_category_type', columns: {#categoryKey, #typeKey})
@TableIndex(
  name: 'idx_items_active_pinned_at',
  columns: {#status, #isPinned, #pinnedAt},
)
@TableIndex(name: 'idx_items_status_deleted_at', columns: {#status, #deletedAt})
class Items extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 跨设备复制时保持稳定的随机来源标识。
  TextColumn get originId => text().unique()();

  /// 所属成员 ID，外键级联拦截
  TextColumn get memberId => text().nullable().references(
    Members,
    #id,
    onDelete: KeyAction.restrict,
  )();

  /// 大类 Key：certificate / card / insurance / vehicle / other
  TextColumn get categoryKey => text().nullable()();

  /// 子类型 Key：如 id_card / debit_card / credit_card 等
  TextColumn get typeKey => text().nullable()();

  /// 资料创建/适配时所使用的内置模板版本号
  IntColumn get templateVersion => integer().withDefault(const Constant(1))();

  /// 资料标题
  TextColumn get title => text().nullable()();

  /// 列表主展示文本（低敏脱敏数据）
  TextColumn get primaryText => text().nullable()();

  /// 列表副展示文本（低敏脱敏数据）
  TextColumn get secondaryText => text().nullable()();

  /// 汇总摘要文本（低敏预览）
  TextColumn get summaryText => text().nullable()();

  /// 低敏模糊搜索文本
  TextColumn get searchText => text().nullable()();

  /// 资料整体备注信息
  TextColumn get note => text().nullable()();

  /// 是否常用
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// 是否置顶
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();

  /// 最近一次设为置顶的时间；取消置顶后清空，编辑资料不改变该值。
  IntColumn get pinnedAt => integer().nullable()();

  /// 手动排序权重
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 状态：active / archived / deleted
  TextColumn get status => text()
      .check(
        const CustomExpression<bool>(
          "status IN ('active', 'archived', 'deleted')",
        ),
      )
      .withDefault(const Constant('active'))();

  /// 移入最近删除的时间；活跃或归档资料为 null。
  IntColumn get deletedAt => integer().nullable()();

  /// 最近删除前的收纳状态；仅删除中的资料保存 active / archived。
  TextColumn get statusBeforeDeletion => text().nullable().check(
    const CustomExpression<bool>(
      "status_before_deletion IS NULL OR status_before_deletion IN ('active', 'archived')",
    ),
  )();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  /// 最近查看时间（本机行为，不备份）
  IntColumn get lastViewedAt => integer().nullable()();

  /// 结构化 JSON metadata (包含 warnings 和 derived)
  TextColumn get metadata => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    "CHECK ((status = 'deleted') = (deleted_at IS NOT NULL))",
    "CHECK ((status = 'deleted') = (status_before_deletion IS NOT NULL))",
  ];
}
