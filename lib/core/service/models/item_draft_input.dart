import '../../attachment/save_attachment_input.dart';
import '../../field/field_origin.dart';
import '../../repository/models/item_child_entry_model.dart';

/// 资料草稿保存输入模型（解耦 Drift 实体，专供 Service 层使用）
class ItemDraftInput {
  /// 资料 ID（更新时传入，新建时为 null）
  final String? id;

  /// 所属家庭成员 ID
  final String? memberId;

  /// 资料大类 Key
  final String? categoryKey;

  /// 资料子类型 Key
  final String? typeKey;

  /// 创建/适配的模板版本号 (受控冻结，默认值为 1)
  final int templateVersion;

  /// 资料标题（可选，为空时系统将根据规则自动生成）
  final String? title;

  /// 资料整体备注信息
  final String? note;

  /// 是否常用
  final bool isFavorite;

  /// 是否置顶
  final bool isPinned;

  /// 最近一次设为置顶的时间；取消置顶时为空。
  final int? pinnedAt;

  /// 手动排序权重
  final int sortOrder;

  /// 状态：active / archived
  final String status;

  /// 包含的所有子字段录入草稿列表
  final List<ItemFieldDraftInput> fields;

  /// 包含的所有附件录入列表
  final List<SaveAttachmentInput> attachments;

  /// 关联的子表项集合 (三态语义: null 表示保留已有，[] 表示清空，非空表示覆盖)
  final List<SaveItemChildEntryInput>? childEntries;

  ItemDraftInput({
    this.id,
    this.memberId,
    this.categoryKey,
    this.typeKey,
    this.templateVersion = 1,
    this.title,
    this.note,
    this.isFavorite = false,
    this.isPinned = false,
    this.pinnedAt,
    this.sortOrder = 0,
    this.status = 'active',
    required this.fields,
    this.attachments = const [],
    this.childEntries,
  });
}

/// 资料单属性字段录入草稿模型
class ItemFieldDraftInput {
  /// 字段唯一标识 Key
  final String fieldKey;

  /// 录入的原始明文值
  final String? valueText;

  /// 字段级单独备注
  final String? fieldNote;

  /// 字段来源标记
  final FieldOrigin origin;

  ItemFieldDraftInput({
    required this.fieldKey,
    this.valueText,
    this.fieldNote,
    this.origin = FieldOrigin.unknown,
  });
}
