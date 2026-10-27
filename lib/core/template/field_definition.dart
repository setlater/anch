import 'package:meta/meta.dart';
import 'field_priority.dart';
import 'field_value_type.dart';
import 'sensitive_level.dart';

/// 字段元信息定义
///
/// This class belongs to the immutable contract layer. Runtime modification is prohibited.
/// Schema changes must go through version bumps.
@immutable
class FieldDefinition {
  /// 字段唯一 Key（必须长期稳定，对应数据库物理键）
  final String fieldKey;

  /// 界面展示的中文名称
  final String label;

  /// 字段值类型描述
  final FieldValueType valueType;

  /// 字段敏感度分级
  final SensitiveLevel sensitiveLevel;

  /// 是否为录入时的必填项
  final bool required;

  /// 字段显示与展现折叠的优先级
  final FieldPriority priority;

  /// 录入时的中文占位符/提示文本
  @Deprecated('Deprecated property, no longer used in runtime logic.')
  final String? inputHint;

  /// 在详情中是否可被一键快速复制
  final bool copyable;

  /// 该字段值是否允许提取特征加入低敏模糊搜索索引
  final bool searchable;

  /// 该字段值是否常驻卡片列表摘要部分展现
  final bool summary;

  /// 是否可以作为日历提醒的生成源
  @Deprecated('Deprecated property, no longer used in runtime logic.')
  final bool reminderSource;

  const FieldDefinition({
    required this.fieldKey,
    required this.label,
    required this.valueType,
    required this.sensitiveLevel,
    this.required = false,
    this.priority = FieldPriority.p0,
    @Deprecated('Deprecated parameter, no longer used in runtime logic.')
    this.inputHint,
    this.copyable = false,
    this.searchable = false,
    this.summary = false,
    @Deprecated('Deprecated parameter, no longer used in runtime logic.')
    this.reminderSource = false,
  });
}
