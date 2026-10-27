import 'dart:convert';
import '../../attachment/attachment_model.dart';
import '../../service/validation/field_validation_error.dart';

/// 资料详实业务模型（集成子字段列表）
class ItemWithFields {
  // ==========================================
  // A. Core Fields (核心基础数据，必须稳定)
  // ==========================================

  /// 主键 UUID
  final String id;

  /// 跨设备复制时保持稳定的随机来源标识。
  final String originId;

  /// 所属家庭成员 ID
  final String? memberId;

  /// 大类 Key
  final String? categoryKey;

  /// 子类型 Key
  final String? typeKey;

  /// 适配模板版本
  final int templateVersion;

  /// 资料标题
  final String? title;

  /// 整体备注
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

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  /// 最近查看时间
  final int? lastViewedAt;

  /// 所有下挂的动态子属性字段集合
  final List<ItemFieldModel> fields;

  /// 关联的所有加密附件列表
  final List<AttachmentModel> attachments;

  // ==========================================
  // B. Derived Fields (系统衍生数据，用于列表展示与极速索引)
  // ==========================================

  /// 列表主展示文本
  final String? primaryText;

  /// 列表副展示文本
  final String? secondaryText;

  /// 汇总摘要文本
  final String? summaryText;

  /// 低敏搜索文本 (低敏)
  final String? searchText;

  /// 还款日
  final String? repaymentDay;

  // ==========================================
  // C. Metadata Fields (元数据层，仅用于诊断、调试、导入导出，禁止 UI 直接访问)
  // ==========================================

  /// 结构化校验警告。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  final List<Warning> validationWarnings;

  /// 原始的 DB metadata 列内容。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  final String? metadata;

  /// 语义拆分：诊断警告。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  List<Warning> get diagnostics => validationWarnings;

  /// 语义拆分：原始输入快照。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  Map<String, dynamic>? get rawState {
    Map<String, dynamic> state = {};
    try {
      if (metadata != null && metadata!.isNotEmpty) {
        final data = jsonDecode(metadata!);
        final rawState = data['raw_state'];
        if (rawState is Map) {
          state = Map<String, dynamic>.from(rawState);
        }
      }
    } catch (_) {}

    final fieldValues = state['fields'] is Map
        ? Map<String, dynamic>.from(state['fields'] as Map)
        : <String, dynamic>{};
    for (final field in fields) {
      fieldValues[field.fieldKey] = field.valueText;
    }
    if (fieldValues.isEmpty && state.isEmpty) {
      return null;
    }
    state['fields'] = fieldValues;
    return state;
  }

  ItemWithFields({
    required this.id,
    String? originId,
    this.memberId,
    this.categoryKey,
    this.typeKey,
    required this.templateVersion,
    this.title,
    this.primaryText,
    this.secondaryText,
    this.summaryText,
    this.searchText,
    this.repaymentDay,
    this.note,
    required this.isFavorite,
    required this.isPinned,
    this.pinnedAt,
    required this.sortOrder,
    required this.status,
    this.deletedAt,
    this.statusBeforeDeletion,
    required this.createdAt,
    required this.updatedAt,
    this.lastViewedAt,
    required this.fields,
    this.attachments = const [],
    this.validationWarnings = const [],
    this.metadata,
  }) : originId = originId ?? id;
}

/// 资料单字段属性业务模型
class ItemFieldModel {
  /// 主键 UUID
  final String id;

  /// 所属资料 ID
  final String itemId;

  /// 字段 Key
  final String fieldKey;

  /// 字段类型
  final String valueType;

  /// 原始展示明文
  final String? valueText;

  /// 标准化值（低敏）
  final String? normalizedValue;

  /// 字段级备注说明
  final String? fieldNote;

  /// 当前运行的 App 代码内置注册字典是否认识此字段
  @Deprecated(
    'Deprecated property, no longer read or written in active runtime logic.',
  )
  final bool templateFieldKnown;

  /// 是否是历史遗留未知字段
  @Deprecated(
    'Deprecated property, no longer read or written in active runtime logic.',
  )
  final bool isArchivedField;

  /// 成为历史字段原因说明
  @Deprecated(
    'Deprecated property, no longer read or written in active runtime logic.',
  )
  final String? archivedReason;

  /// 中文名称兜底展现
  final String? rawFieldLabel;

  /// 排序位置
  final int sortOrder;

  /// 创建时间
  final int createdAt;

  /// 更新时间
  final int updatedAt;

  ItemFieldModel({
    required this.id,
    required this.itemId,
    required this.fieldKey,
    required this.valueType,
    this.valueText,
    this.normalizedValue,
    this.fieldNote,
    @Deprecated(
      'Deprecated parameter, no longer read or written in active runtime logic.',
    )
    required this.templateFieldKnown,
    @Deprecated(
      'Deprecated parameter, no longer read or written in active runtime logic.',
    )
    required this.isArchivedField,
    @Deprecated(
      'Deprecated parameter, no longer read or written in active runtime logic.',
    )
    this.archivedReason,
    this.rawFieldLabel,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });
}
