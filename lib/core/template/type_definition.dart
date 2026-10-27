import 'package:meta/meta.dart';
import 'field_definition.dart';

/// 资料子类型模板定义
///
/// This class belongs to the immutable contract layer. Runtime modification is prohibited.
/// Schema changes must go through version bumps.
@immutable
class TypeDefinition {
  /// 子类型标识 Key (如 id_card, credit_card)
  final String typeKey;

  /// 显示名称
  final String label;

  /// 所属大类标识 Key (如 certificate, card)
  final String categoryKey;

  /// 包含的属性字段定义集合
  final List<FieldDefinition> fields;

  /// 模板的版本号（受控冻结，默认值为 1）
  final int version;

  /// 该类型是否允许在创建/录入界面被用户选择
  final bool isAvailableForCreation;

  /// 该类型详情页头部是否以紧凑汇总模式展示
  final bool usesCompactSummaryHeader;

  /// 旧版资料是否继续按自身模板版本编辑，而不自动提升到最新版本。
  ///
  /// 仅用于无法无损自动转换的模板演进，避免保存时丢失历史字段语义。
  final bool supportsLegacyEditing;

  /// 拥有的默认加密附件角色
  @Deprecated('Deprecated property, no longer used in runtime logic.')
  final List<String> defaultAttachmentRoles;

  /// 该类型支持 of 系统内默认提醒类别
  @Deprecated('Deprecated property, no longer used in runtime logic.')
  final List<String> defaultReminderTypes;

  const TypeDefinition({
    this.version = 1,
    required this.typeKey,
    required this.label,
    required this.categoryKey,
    required this.fields,
    this.isAvailableForCreation = true,
    this.usesCompactSummaryHeader = false,
    this.supportsLegacyEditing = false,
    @Deprecated('Deprecated parameter, no longer used in runtime logic.')
    this.defaultAttachmentRoles = const [],
    @Deprecated('Deprecated parameter, no longer used in runtime logic.')
    this.defaultReminderTypes = const [],
  });
}
