import 'package:drift/drift.dart';

/// 本地设置 KV 表
class AppSettings extends Table {
  /// 设置 key
  TextColumn get key => text()();

  /// 序列化后的设置值
  TextColumn get value => text().nullable()();

  /// 设置值类型
  TextColumn get valueType => text()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {key};
}
