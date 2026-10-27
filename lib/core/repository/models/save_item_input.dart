import '../../attachment/save_attachment_input.dart';
import '../../../core/template/field_value_type.dart';
import '../../service/validation/field_validation_error.dart';
import 'item_child_entry_model.dart';

/// 资料保存业务输入模型
class SaveItemInput {
  /// 资料 ID（更新时传入，新建时为 null）
  final String? id;

  /// 导入资料携带的稳定来源标识；本机新建时留空。
  final String? originId;

  /// 所属家庭成员 ID
  final String? memberId;

  /// 大类 Key
  final String? categoryKey;

  /// 子类型 Key
  final String? typeKey;

  /// 创建/适配模板版本号
  final int templateVersion;

  /// 资料标题
  final String? title;

  /// 列表主展示文本 (低敏)
  final String? primaryText;

  /// 列表副展示文本 (低敏)
  final String? secondaryText;

  /// 汇总摘要文本 (低敏)
  final String? summaryText;

  /// 低敏模糊搜索文本
  final String? searchText;

  /// 备注信息
  final String? note;

  /// 是否常用
  final bool isFavorite;

  /// 是否置顶
  final bool isPinned;

  /// 最近一次设为置顶的时间；取消置顶时为空。
  final int? pinnedAt;

  /// 手动排序权重
  final int sortOrder;

  /// 状态：active / archived / deleted
  final String status;

  /// 移入最近删除的时间。
  final int? deletedAt;

  /// 最近删除前的收纳状态。
  final String? statusBeforeDeletion;

  /// 关联的属性字段输入集合
  final List<SaveItemFieldInput> fields;

  /// 关联的附件输入集合
  final List<SaveAttachmentInput> attachments;

  /// 结构化校验警告
  final List<Warning> validationWarnings;

  /// 原始的 DB metadata 列内容
  final String? metadata;

  /// 关联的子表项集合 (三态语义: null 表示保留已有，[] 表示清空，非空表示覆盖)
  final List<SaveItemChildEntryInput>? childEntries;

  SaveItemInput({
    this.id,
    this.originId,
    this.memberId,
    this.categoryKey,
    this.typeKey,
    this.templateVersion = 1,
    this.title,
    this.primaryText,
    this.secondaryText,
    this.summaryText,
    this.searchText,
    this.note,
    this.isFavorite = false,
    this.isPinned = false,
    this.pinnedAt,
    this.sortOrder = 0,
    this.status = 'active',
    this.deletedAt,
    this.statusBeforeDeletion,
    required this.fields,
    this.attachments = const [],
    this.validationWarnings = const [],
    this.metadata,
    this.childEntries,
  });
}

/// 资料单字段保存业务输入模型
class SaveItemFieldInput {
  /// 字段 Key
  final String fieldKey;

  /// 字段值类型枚举（在模板层与Repository强类型限制）
  final FieldValueType valueType;

  /// 字段展示明文
  final String? valueText;

  /// 标准化值
  final String? normalizedValue;

  /// 字段级备注
  final String? fieldNote;

  /// 显示排序值
  final int sortOrder;

  SaveItemFieldInput({
    required this.fieldKey,
    required this.valueType,
    this.valueText,
    this.normalizedValue,
    this.fieldNote,
    this.sortOrder = 0,
  });
}
