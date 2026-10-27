/// 资料大类定义
class CategoryDefinition {
  /// 大类唯一标识 Key (如 certificate, card, insurance, vehicle, other)
  final String categoryKey;

  /// 显示名称 (如 证件资料, 卡片资料 等)
  final String label;

  /// 关联的所有子类型模板标识 Key 集合
  final List<String> types;

  const CategoryDefinition({
    required this.categoryKey,
    required this.label,
    required this.types,
  });
}
