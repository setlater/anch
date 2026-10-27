import '../repository/models/member_model.dart';
import '../repository/models/item_model.dart';
import '../repository/models/item_with_fields.dart';
import '../attachment/attachment_model.dart';
import '../repository/models/item_child_entry_model.dart';
import 'backup_payload.dart';

/// 备份模型映射器 (Mapper)。
///
/// 职责：
/// 1. 实现核心业务实体模型单向映射到备份实体的纯内存转换逻辑。
/// 2. ⚠️ 【安全边界】本类仅进行纯模型内存数据转换，不查询数据库、不接受 Repository 实例、不接入 UI。
/// 3. 本类需要保留敏感字段 `valueText` 属性，以便后续能完整导出和恢复，但这只属于内存态，严禁将其明文持久化或输出日志。
abstract final class BackupPayloadMapper {
  BackupPayloadMapper._();

  /// 家庭成员业务模型 [MemberModel] 转为备份模型 [BackupMemberV1]
  static BackupMemberV1 toBackupMember(MemberModel model) {
    return BackupMemberV1(
      id: model.id,
      name: model.name,
      relationKey: 'other',
      isSystem: model.isSystem,
      sortOrder: model.sortOrder,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      note: model.note,
      isArchived: model.isArchived,
    );
  }

  /// 资料主记录业务模型 [ItemModel] 转为备份模型 [BackupItemV1]
  static BackupItemV1 toBackupItemFromModel(ItemModel model) {
    return BackupItemV1(
      id: model.id,
      originId: model.originId,
      memberId: model.memberId,
      categoryKey: model.categoryKey,
      typeKey: model.typeKey,
      templateVersion: model.templateVersion,
      title: model.title,
      primaryText: model.primaryText,
      secondaryText: model.secondaryText,
      summaryText: model.summaryText,
      searchText: model.searchText,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isFavorite: model.isFavorite,
      isPinned: model.isPinned,
      pinnedAt: model.pinnedAt,
      sortOrder: model.sortOrder,
      status: model.status,
      deletedAt: model.deletedAt,
      statusBeforeDeletion: model.statusBeforeDeletion,
    );
  }

  /// 资料详实业务模型 [ItemWithFields] 转为备份模型 [BackupItemV1]
  static BackupItemV1 toBackupItemFromFields(ItemWithFields model) {
    return BackupItemV1(
      id: model.id,
      originId: model.originId,
      memberId: model.memberId,
      categoryKey: model.categoryKey,
      typeKey: model.typeKey,
      templateVersion: model.templateVersion,
      title: model.title,
      primaryText: model.primaryText,
      secondaryText: model.secondaryText,
      summaryText: model.summaryText,
      searchText: model.searchText,
      note: model.note,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      isFavorite: model.isFavorite,
      isPinned: model.isPinned,
      pinnedAt: model.pinnedAt,
      sortOrder: model.sortOrder,
      status: model.status,
      deletedAt: model.deletedAt,
      statusBeforeDeletion: model.statusBeforeDeletion,
    );
  }

  /// 资料单字段属性业务模型 [ItemFieldModel] 转为备份模型 [BackupItemFieldV1]
  static BackupItemFieldV1 toBackupItemField(ItemFieldModel model) {
    return BackupItemFieldV1(
      id: model.id,
      itemId: model.itemId,
      fieldKey: model.fieldKey,
      valueType: model.valueType,
      valueText: model.valueText, // 备份必须保留明文以便恢复，仅驻留于加密前的内存负荷中
      normalizedValue: model.normalizedValue,
      fieldNote: model.fieldNote,
      sortOrder: model.sortOrder,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  /// 附件业务模型 [AttachmentModel] 转为备份模型 [BackupAttachmentV1]
  static BackupAttachmentV1 toBackupAttachment(
    AttachmentModel model,
    String encryptedDataBase64,
  ) {
    return BackupAttachmentV1(
      id: model.id,
      originAttachmentId: model.originAttachmentId,
      itemId: model.itemId,
      linkedFieldKey: model.linkedFieldKey,
      attachmentRole: model.attachmentRole,
      fileName: model.fileName,
      originalName: model.originalName,
      mimeType: model.mimeType,
      plainSize: model.plainSize,
      encryptedSize: model.encryptedSize,
      sha256: model.sha256,
      sortOrder: model.sortOrder,
      status: model.status,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      encryptedData: encryptedDataBase64,
    );
  }

  /// 资料子表项业务模型 [ItemChildEntryModel] 转为备份模型 [BackupItemChildEntryV1]
  static BackupItemChildEntryV1 toBackupItemChildEntry(
    ItemChildEntryModel model,
  ) {
    return BackupItemChildEntryV1(
      id: model.id,
      itemId: model.itemId,
      childType: model.childType,
      sortOrder: model.sortOrder,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  /// 资料子属性字段业务模型 [ItemChildFieldModel] 转为备份模型 [BackupItemChildFieldV1]
  static BackupItemChildFieldV1 toBackupItemChildField(
    ItemChildFieldModel model,
  ) {
    return BackupItemChildFieldV1(
      id: model.id,
      childEntryId: model.childEntryId,
      fieldKey: model.fieldKey,
      label: model.label,
      valueText: model.valueText,
      valueType: model.valueType,
      sensitiveLevel: model.sensitiveLevel,
      copyable: model.copyable,
      searchable: model.searchable,
      summary: model.summary,
      sortOrder: model.sortOrder,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }
}
