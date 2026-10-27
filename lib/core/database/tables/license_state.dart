import 'package:drift/drift.dart';

/// 激活状态表
class LicenseState extends Table {
  /// 固定单行 ID: current_license_state
  TextColumn get id => text()();

  /// 激活状态：free (免费) / pro (专业版)
  TextColumn get licenseType => text().withDefault(const Constant('free'))();

  /// 激活完成时间戳
  IntColumn get activatedAt => integer().nullable()();

  /// 离线激活有效期截止时间
  IntColumn get expiresAt => integer().nullable()();

  /// 激活数据的特征签名值
  TextColumn get licensePayloadHash => text().nullable()();

  /// 最近一次本地策略验证的时间
  IntColumn get lastVerifiedAt => integer().nullable()();

  /// 状态：active (活跃) / expired (已过期) / invalid (失效)
  TextColumn get status => text().withDefault(const Constant('invalid'))();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'license_state';
}
