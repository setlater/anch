import 'package:drift/drift.dart';
import 'items.dart';

/// 加密附件元信息表
@TableIndex(name: 'idx_attachments_item', columns: {#itemId})
@TableIndex(name: 'idx_attachments_linked', columns: {#itemId, #linkedFieldKey})
class Attachments extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 跨设备复制时保持稳定的随机来源标识。
  TextColumn get originAttachmentId => text().unique()();

  /// 所属资料 ID，外键级联删除
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  /// 关联的字段 Key
  TextColumn get linkedFieldKey => text().nullable()();

  /// 附件角色
  TextColumn get attachmentRole => text()();

  /// 物理加密存储的随机 UUID 文件名
  TextColumn get fileName => text()();

  /// 原始文件名
  TextColumn get originalName => text().nullable()();

  /// 媒体类型
  TextColumn get mimeType => text()();

  /// 文件解密前的大小
  IntColumn get plainSize => integer().withDefault(const Constant(0))();

  /// 文件加密后物理占据的大小
  IntColumn get encryptedSize => integer().withDefault(const Constant(0))();

  /// 加密文件内容的 SHA-256
  TextColumn get sha256 => text().nullable()();

  /// 排序权重
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  /// 状态：active / deleted
  TextColumn get status => text()
      .check(const CustomExpression<bool>("status IN ('active', 'deleted')"))
      .withDefault(const Constant('active'))();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
