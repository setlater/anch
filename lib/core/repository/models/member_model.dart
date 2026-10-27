/// 家庭成员业务模型
class MemberModel {
  /// 主键 UUID
  final String id;

  /// 成员类型：person / family
  final String memberType;

  /// 成员显示名称
  final String name;

  /// 头像/图标 Key
  final String? avatarKey;

  /// 成员备注
  final String? note;

  /// 手动排序权重值
  final int sortOrder;

  /// 是否为系统内置成员
  final bool isSystem;

  /// 是否归档
  final bool isArchived;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  MemberModel({
    required this.id,
    required this.memberType,
    required this.name,
    this.avatarKey,
    this.note,
    required this.sortOrder,
    required this.isSystem,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
  });
}
