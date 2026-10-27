/// 家庭成员保存业务输入模型
class SaveMemberInput {
  /// 成员 ID（更新时传入，新建时为 null）
  final String? id;

  /// 成员类型：person (真实人) / family (虚拟家庭)
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

  SaveMemberInput({
    this.id,
    required this.memberType,
    required this.name,
    this.avatarKey,
    this.note,
    this.sortOrder = 0,
    this.isSystem = false,
    this.isArchived = false,
  });
}
