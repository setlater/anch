/// 资料子项（如户口本成员）业务数据模型
class ItemChildEntryModel {
  /// 主键 UUID
  final String id;

  /// 所属主资料 ID
  final String itemId;

  /// 子项类型 (例如 'household_member')
  final String childType;

  /// 排序权重
  final int sortOrder;

  /// 子项下挂的所有具体属性字段
  final List<ItemChildFieldModel> fields;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  ItemChildEntryModel({
    required this.id,
    required this.itemId,
    required this.childType,
    required this.sortOrder,
    required this.fields,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 资料子项单个属性字段业务数据模型
class ItemChildFieldModel {
  /// 主键 UUID
  final String id;

  /// 所属子项 ID
  final String childEntryId;

  /// 字段 Key
  final String fieldKey;

  /// 字段展示中文名
  final String label;

  /// 字段值（明文）
  final String? valueText;

  /// 字段值格式类型
  final String valueType;

  /// 敏感级别
  final String sensitiveLevel;

  /// 是否可复制
  final bool copyable;

  /// 是否可被搜索索引
  final bool searchable;

  /// 是否作为摘要展现的来源之一
  final bool summary;

  /// 显示排序值
  final int sortOrder;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  ItemChildFieldModel({
    required this.id,
    required this.childEntryId,
    required this.fieldKey,
    required this.label,
    this.valueText,
    required this.valueType,
    required this.sensitiveLevel,
    required this.copyable,
    required this.searchable,
    required this.summary,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
}

/// 资料子项保存业务输入模型
class SaveItemChildEntryInput {
  /// 对应子项 ID（更新时传入，新建时可为 null）
  final String? id;

  /// 子项类型 (如 'household_member')
  final String childType;

  /// 排序权重
  final int sortOrder;

  /// 子项包含的具体属性字段输入集合
  final List<SaveItemChildFieldInput> fields;

  SaveItemChildEntryInput({
    this.id,
    required this.childType,
    required this.sortOrder,
    required this.fields,
  });
}

/// 资料子项单字段保存业务输入模型
class SaveItemChildFieldInput {
  /// 字段 Key
  final String fieldKey;

  /// 字段展示中文名
  final String label;

  /// 字段值明文
  final String? valueText;

  /// 字段类型
  final String valueType;

  /// 敏感等级
  final String sensitiveLevel;

  /// 是否可复制
  final bool copyable;

  /// 是否可被检索
  final bool searchable;

  /// 是否可作为摘要
  final bool summary;

  /// 排序权重
  final int sortOrder;

  SaveItemChildFieldInput({
    required this.fieldKey,
    required this.label,
    this.valueText,
    required this.valueType,
    required this.sensitiveLevel,
    this.copyable = false,
    this.searchable = false,
    this.summary = false,
    this.sortOrder = 0,
  });
}
