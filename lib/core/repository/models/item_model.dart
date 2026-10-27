import 'dart:convert';
import '../../service/validation/field_validation_error.dart';

/// 资料主记录业务模型 (不含动态子字段列表，常用于列表极速渲染)
class ItemModel {
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

  // ==========================================
  // B. Derived Fields (系统衍生数据，用于列表展示与极速索引)
  // ==========================================

  /// 列表主展示文本 (低敏)
  final String? primaryText;

  /// 列表副展示文本 (低敏)
  final String? secondaryText;

  /// 汇总摘要文本 (低敏)
  final String? summaryText;

  /// 低敏搜索文本 (低敏)
  final String? searchText;

  /// 还款日
  final String? repaymentDay;

  /// 账单日
  final String? billDay;

  // ==========================================
  // C. Metadata Fields (元数据层，仅用于诊断、调试、导入导出，禁止 UI 直接访问)
  // ==========================================

  /// 结构化校验警告。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  final List<Warning> validationWarnings;

  /// 原始的 DB metadata 列内容。元数据层字段，UI 禁止直接使用，仅限调试/导出使用。
  final String? metadata;

  /// 列表摘要与状态计算所需的正式字段值。正式字段优先于元数据快照。
  final Map<String, String?> fieldValues;

  /// 列表、搜索和资料卡片只保留状态白名单；保险另保留低敏险种以重建摘要。
  ItemModel toListSummary() {
    final rawFields = rawState?['fields'];
    final summaryFields = <String, String?>{};
    for (final key in [
      'bill_day',
      'repayment_day',
      'valid_until',
      'end_date',
      'is_long_term',
      if (typeKey == 'insurance') 'insurance_type',
      if (typeKey == 'debit_card' || typeKey == 'credit_card') ...[
        'bank_name',
        'is_closed',
      ],
    ]) {
      if (rawFields is Map && rawFields.containsKey(key)) {
        summaryFields[key] = rawFields[key]?.toString();
      }
    }
    // 历史保险派生文本可能包含已退役字段；正式字段优先，只重建允许的摘要。
    final insuranceSummary = typeKey == 'insurance'
        ? ['insurance_type', 'end_date']
              .map((key) => summaryFields[key]?.trim() ?? '')
              .where((value) => value.isNotEmpty)
              .join(' · ')
        : null;
    return ItemModel(
      id: id,
      originId: originId,
      memberId: memberId,
      categoryKey: categoryKey,
      typeKey: typeKey,
      templateVersion: templateVersion,
      title: title,
      primaryText: insuranceSummary ?? primaryText,
      secondaryText: typeKey == 'insurance' ? null : secondaryText,
      summaryText: insuranceSummary ?? summaryText,
      searchText: searchText,
      repaymentDay: summaryFields['repayment_day'] ?? repaymentDay,
      billDay: summaryFields['bill_day'] ?? billDay,
      isFavorite: isFavorite,
      isPinned: isPinned,
      pinnedAt: pinnedAt,
      sortOrder: sortOrder,
      status: status,
      deletedAt: deletedAt,
      statusBeforeDeletion: statusBeforeDeletion,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastViewedAt: lastViewedAt,
      fieldValues: Map.unmodifiable(summaryFields),
    );
  }

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

    final fields = state['fields'] is Map
        ? Map<String, dynamic>.from(state['fields'] as Map)
        : <String, dynamic>{};
    fields.addAll(fieldValues);
    if (fields.isEmpty && state.isEmpty) {
      return null;
    }
    state['fields'] = fields;
    return state;
  }

  ItemModel({
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
    this.billDay,
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
    this.validationWarnings = const [],
    this.metadata,
    this.fieldValues = const {},
  }) : originId = originId ?? id;
}
