import 'package:drift/drift.dart';
import 'items.dart';

/// 提醒配置表
@TableIndex(name: 'idx_reminders_schedule', columns: {#enabled, #nextTriggerAt})
@TableIndex(name: 'idx_reminders_item', columns: {#itemId})
class Reminders extends Table {
  /// 主键 UUID
  TextColumn get id => text()();

  /// 所属资料 ID，外键级联删除
  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  /// 关联的字段 Key
  TextColumn get fieldKey => text().nullable()();

  /// 提醒类型
  TextColumn get reminderType => text()();

  /// 触发日期源值
  TextColumn get sourceValue => text()();

  /// 触发值类型分类：date / month_day / day_of_month
  TextColumn get sourceValueType => text()();

  /// 触发绝对毫秒时间戳
  IntColumn get remindAt => integer()();

  /// 提前几天提醒
  IntColumn get advanceDays => integer().withDefault(const Constant(0))();

  /// 周期重复配置
  TextColumn get repeatRule => text().nullable()();

  /// 提醒总开关
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();

  /// 上次触发报警时间
  IntColumn get lastTriggeredAt => integer().nullable()();

  /// 下次触发时间戳
  IntColumn get nextTriggerAt => integer().nullable()();

  /// 稍后提醒挂起时间
  IntColumn get snoozedUntil => integer().nullable()();

  /// 用户忽略警报时间戳
  IntColumn get dismissedAt => integer().nullable()();

  /// 操作系统通知注册 ID
  IntColumn get notificationLocalId => integer().nullable()();

  /// 备注说明
  TextColumn get note => text().nullable()();

  /// 创建时间
  IntColumn get createdAt => integer()();

  /// 更新时间
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
