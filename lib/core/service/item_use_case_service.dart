import 'dart:convert';
import '../repository/item_repository.dart';
import '../repository/member_repository.dart';
import '../repository/models/save_item_input.dart';
import '../repository/models/item_child_entry_model.dart';
import '../repository/models/item_model.dart';
import '../repository/models/item_with_fields.dart';
import '../template/template_registry.dart';
import '../template/category_definition.dart';
import 'models/item_draft_input.dart';
import 'models/item_save_result.dart';
import 'item_search_service.dart';
import 'builder/item_text_builder.dart';
import 'item_global_registry.dart';
import 'validation/template_validator.dart';
import 'validation/field_validation_error.dart';
import '../template/migration_service.dart';
import '../template/field_value_type.dart';
import '../template/field_definition.dart';
import 'models/execution_context.dart';
import '../template/migration_dto.dart';
import '../runtime/runtime_context.dart';

export 'item_global_registry.dart';

/// 从字段列表中提取派生属性（尾号、生日、性别）
Map<String, String> _extractDerived(List<ItemFieldDraftInput> fields) {
  final derived = <String, String>{};

  // 查找卡号/身份证号/护照/驾照中的尾号
  final cardOrIdField = fields.firstWhere(
    (f) =>
        f.fieldKey == 'card_number' ||
        f.fieldKey == 'id_number' ||
        f.fieldKey == 'passport_number' ||
        f.fieldKey == 'driver_license_number',
    orElse: () => ItemFieldDraftInput(fieldKey: ''),
  );

  if (cardOrIdField.fieldKey.isNotEmpty && cardOrIdField.valueText != null) {
    final val = cardOrIdField.valueText!.trim();
    if (val.isNotEmpty) {
      derived['tailNumber'] = val.length >= 4
          ? val.substring(val.length - 4)
          : val;
    }
  }

  // 从身份证号提取生日与性别
  final idField = fields.firstWhere(
    (f) => f.fieldKey == 'id_number',
    orElse: () => ItemFieldDraftInput(fieldKey: ''),
  );

  if (idField.fieldKey.isNotEmpty && idField.valueText != null) {
    final val = idField.valueText!.trim();
    if (val.length == 18) {
      derived['birthDate'] = val.substring(6, 14);
      final genderDigit = int.tryParse(val.substring(16, 17));
      if (genderDigit != null) {
        derived['gender'] = (genderDigit % 2 == 1) ? '男' : '女';
      }
    } else if (val.length == 15) {
      derived['birthDate'] = '19${val.substring(6, 12)}';
      final genderDigit = int.tryParse(val.substring(14, 15));
      if (genderDigit != null) {
        derived['gender'] = (genderDigit % 2 == 1) ? '男' : '女';
      }
    }
  }

  return derived;
}

class OperationResult {
  final bool success;
  final ItemWithFields? rollback;
  final Object? error;
  final String? itemId;

  const OperationResult({
    required this.success,
    this.rollback,
    this.error,
    this.itemId,
  });
}

/// 资料草稿保存用例服务层
class ItemUseCaseService {
  final ItemRepository itemRepo;
  final MemberRepository memberRepo;
  final RuntimeContext runtime;
  final ItemGlobalRegistry registry;
  final ItemSearchService searchService;

  ItemUseCaseService({
    required this.itemRepo,
    required this.memberRepo,
    required this.runtime,
    ItemGlobalRegistry? registry,
  }) : registry = registry ?? ItemGlobalRegistry.instance,
       searchService = ItemSearchService(runtime, itemRepo: itemRepo);

  /// 保存资料草稿业务逻辑（普通诊断不阻断；必填和禁止保存项阻断）。
  Future<ItemSaveResult> saveDraft(
    ItemDraftInput draft, {
    ExecutionContext? context,
  }) async {
    try {
      // 1. 调用校验器验证模板合法性与防卫拦截
      final validation = TemplateValidator.validate(draft);
      context?.observer?.onValidationResult(
        validation,
        typeKey: draft.typeKey ?? '',
      );

      final blockingErrors = validation.errors
          .where(
            (e) =>
                e.errorCode == FieldValidationErrorCode.requiredFieldMissing ||
                e.errorCode == FieldValidationErrorCode.forbiddenFieldSaved,
          )
          .toList();
      if (blockingErrors.isNotEmpty) {
        return ItemSaveResult.failure(blockingErrors);
      }

      // 2. 编排层判断：若需要迁移，显式调用 MigrationService 执行迁移转换
      var finalDraft = draft;
      var activeErrors = validation.errors;
      if (validation.migrationRequired &&
          draft.typeKey != null &&
          draft.typeKey!.isNotEmpty) {
        final latestTypeDef = TemplateRegistry.getTemplate(draft.typeKey!)!;
        final migrationFields = draft.fields
            .map(
              (f) => MigrationFieldInput(
                fieldKey: f.fieldKey,
                valueText: f.valueText,
                fieldNote: f.fieldNote,
              ),
            )
            .toList();

        final migratedFields = MigrationService.migrateFields(migrationFields);

        finalDraft = ItemDraftInput(
          id: draft.id,
          memberId: draft.memberId,
          categoryKey: draft.categoryKey,
          typeKey: draft.typeKey,
          templateVersion: latestTypeDef.version,
          title: draft.title,
          note: draft.note,
          isFavorite: draft.isFavorite,
          isPinned: draft.isPinned,
          pinnedAt: draft.pinnedAt,
          sortOrder: draft.sortOrder,
          status: draft.status,
          fields: migratedFields
              .map(
                (f) => ItemFieldDraftInput(
                  fieldKey: f.fieldKey,
                  valueText: f.valueText,
                  fieldNote: f.fieldNote,
                ),
              )
              .toList(),
          attachments: draft.attachments,
          childEntries: draft.childEntries,
        );

        // 迁移后再次校验契约契合度
        final migratedValidation = TemplateValidator.validate(finalDraft);
        context?.observer?.onValidationResult(
          migratedValidation,
          typeKey: finalDraft.typeKey ?? '',
        );
        activeErrors = migratedValidation.errors;
      }

      // 3. 根据草稿成员 ID 在服务层异步拉取成员信息（memberId 可为 null）
      String? memberName;
      if (finalDraft.memberId != null) {
        final member = await memberRepo.getMemberById(finalDraft.memberId!);
        if (member != null) {
          memberName = member.name;
        }
      }

      // 获取当前对应的模板定义（typeKey 可为 null，允许保存无模板资料）
      final typeDef =
          (finalDraft.typeKey != null && finalDraft.typeKey!.isNotEmpty)
          ? TemplateRegistry.getTemplate(
              finalDraft.typeKey!,
              finalDraft.templateVersion,
            )
          : null;

      final categoryLabel = finalDraft.categoryKey != null
          ? TemplateRegistry.getCategories()
                .firstWhere(
                  (c) => c.categoryKey == finalDraft.categoryKey,
                  orElse: () => CategoryDefinition(
                    categoryKey: finalDraft.categoryKey!,
                    label: '其他资料',
                    types: const [],
                  ),
                )
                .label
          : '其他资料';

      // 4. 敏感度特征加工脱敏，生成 high 敏字段的标准化 normalizedValue 尾号值
      final normalizedValues = <String, String?>{};
      for (final inputField in finalDraft.fields) {
        final FieldDefinition? fieldDef =
            (typeDef != null &&
                typeDef.fields.any((f) => f.fieldKey == inputField.fieldKey))
            ? typeDef.fields.firstWhere(
                (f) => f.fieldKey == inputField.fieldKey,
              )
            : null;
        if (fieldDef == null) continue;

        final normalized = SensitiveFieldGuard.normalizeSensitiveField(
          fieldKey: inputField.fieldKey,
          valueText: inputField.valueText,
          level: fieldDef.sensitiveLevel,
        );
        normalizedValues[inputField.fieldKey] = normalized;
      }

      // 5. 调用 Builder 加工拼装各类展示文本与搜索关键词
      final title = TitleSummaryBuilder.buildTitle(
        draft: finalDraft,
        typeDef: typeDef,
        memberName: memberName,
      );

      final primaryText = TitleSummaryBuilder.buildPrimaryText(
        draft: finalDraft,
        typeDef: typeDef,
        title: title,
      );

      final secondaryText = TitleSummaryBuilder.buildSecondaryText(
        draft: finalDraft,
        typeDef: typeDef,
        primaryVal: primaryText,
      );

      List<SaveItemChildEntryInput>? resolvedChildEntries =
          finalDraft.childEntries;
      if (resolvedChildEntries == null && finalDraft.id != null) {
        final dbChildEntries = await itemRepo.getChildEntries(finalDraft.id!);
        resolvedChildEntries = dbChildEntries
            .map(
              (e) => SaveItemChildEntryInput(
                id: e.id,
                childType: e.childType,
                sortOrder: e.sortOrder,
                fields: e.fields
                    .map(
                      (f) => SaveItemChildFieldInput(
                        fieldKey: f.fieldKey,
                        label: f.label,
                        valueText: f.valueText,
                        valueType: f.valueType,
                        sensitiveLevel: f.sensitiveLevel,
                        copyable: f.copyable,
                        searchable: f.searchable,
                        summary: f.summary,
                        sortOrder: f.sortOrder,
                      ),
                    )
                    .toList(),
              ),
            )
            .toList();
      }

      final summaryText = TitleSummaryBuilder.buildSummaryText(
        draft: finalDraft,
        typeDef: typeDef,
        childEntries: resolvedChildEntries,
      );

      final searchText = SearchTextBuilder.buildSearchText(
        title: title,
        typeDef: typeDef,
        categoryLabel: categoryLabel,
        fields: finalDraft.fields,
        normalizedValues: normalizedValues,
        childEntries: resolvedChildEntries,
      );

      // 6. 转换并组装为 Repository 层的业务入库模型
      final repoFields = <SaveItemFieldInput>[];
      for (var i = 0; i < finalDraft.fields.length; i++) {
        final inputField = finalDraft.fields[i];
        final FieldDefinition? fieldDef =
            (typeDef != null &&
                typeDef.fields.any((f) => f.fieldKey == inputField.fieldKey))
            ? typeDef.fields.firstWhere(
                (f) => f.fieldKey == inputField.fieldKey,
              )
            : null;

        final int sortOrder = (typeDef == null || fieldDef == null)
            ? i
            : typeDef.fields.indexWhere(
                (f) => f.fieldKey == inputField.fieldKey,
              );

        repoFields.add(
          SaveItemFieldInput(
            fieldKey: inputField.fieldKey,
            valueType: fieldDef?.valueType ?? FieldValueType.text,
            valueText: inputField.valueText?.trim(),
            normalizedValue: normalizedValues[inputField.fieldKey],
            fieldNote: inputField.fieldNote?.trim(),
            sortOrder: sortOrder == -1 ? i : sortOrder,
          ),
        );
      }

      // 7. 构建 metadata JSON（包含 diagnostics 和 raw_state 语义拆分）
      final allWarnings = [
        ...validation.errors.map(
          (e) => Warning(
            fieldKey: e.fieldKey,
            errorCode: e.errorCode.name,
            errorMessage: e.errorMessage,
          ),
        ),
        ...validation.warnings.map(
          (w) => Warning(
            fieldKey: w.fieldKey,
            errorCode: w.errorCode.name,
            errorMessage: w.errorMessage,
          ),
        ),
      ];

      final metadataStr = jsonEncode({
        'diagnostics': allWarnings.map((w) => w.toJson()).toList(),
        'field_origins': {
          for (final f in finalDraft.fields) f.fieldKey: f.origin.name,
        },
        'derived': _extractDerived(finalDraft.fields),
      });

      final saveInput = SaveItemInput(
        id: finalDraft.id,
        memberId: finalDraft.memberId,
        categoryKey: finalDraft.categoryKey,
        typeKey: finalDraft.typeKey,
        templateVersion: finalDraft.templateVersion,
        title: title,
        primaryText: primaryText,
        secondaryText: secondaryText,
        summaryText: summaryText,
        searchText: searchText,
        note: finalDraft.note?.trim(),
        isFavorite: finalDraft.isFavorite,
        isPinned: finalDraft.isPinned,
        pinnedAt: finalDraft.pinnedAt,
        sortOrder: finalDraft.sortOrder,
        status: finalDraft.status,
        fields: repoFields,
        attachments: finalDraft.attachments,
        validationWarnings: allWarnings,
        metadata: metadataStr,
        childEntries: finalDraft.childEntries,
      );

      // 8. 调用持久化 Repository 层事务落库
      final itemId = await itemRepo.saveItemWithFields(
        saveInput,
        recordUserEvent: true,
      );
      registry.emit(ItemEvent(type: ItemEventType.saved, itemId: itemId));
      return ItemSaveResult.success(itemId, activeErrors);
    } catch (e) {
      // 只有底层物理写失败或运行期系统故障才抛出异常
      rethrow;
    }
  }

  /// 将资料移入最近删除，并保留字段和加密附件。
  Future<OperationResult> deleteItem(String itemId) async {
    final rollback = await itemRepo.getItemWithFields(itemId);
    try {
      final moved = await itemRepo.moveToTrash(itemId);
      if (!moved) {
        return OperationResult(
          success: false,
          rollback: rollback,
          itemId: itemId,
          error: StateError('资料不存在或不处于可删除状态'),
        );
      }
      registry.emit(ItemEvent(type: ItemEventType.deleted, itemId: itemId));
      return OperationResult(success: true, rollback: rollback, itemId: itemId);
    } catch (e) {
      return OperationResult(
        success: false,
        rollback: rollback,
        error: e,
        itemId: itemId,
      );
    }
  }

  /// 更新资料的置顶状态，不改动资料字段或附件。
  Future<OperationResult> updateItemPinned(
    String itemId, {
    required bool isPinned,
  }) async {
    try {
      final updated = await itemRepo.updateItemPinned(
        itemId,
        isPinned: isPinned,
      );
      if (!updated) {
        return OperationResult(
          success: false,
          itemId: itemId,
          error: StateError('资料不存在或已删除'),
        );
      }
      registry.emit(ItemEvent(type: ItemEventType.saved, itemId: itemId));
      return OperationResult(success: true, itemId: itemId);
    } catch (error) {
      return OperationResult(success: false, itemId: itemId, error: error);
    }
  }

  Future<OperationResult> archiveItem(String itemId) async {
    try {
      final updated = await itemRepo.archiveItem(itemId);
      if (!updated) {
        return OperationResult(
          success: false,
          itemId: itemId,
          error: StateError('资料不存在或不处于当前资料'),
        );
      }
      registry.emit(ItemEvent(type: ItemEventType.saved, itemId: itemId));
      return OperationResult(success: true, itemId: itemId);
    } catch (error) {
      return OperationResult(success: false, itemId: itemId, error: error);
    }
  }

  Future<OperationResult> unarchiveItem(String itemId) async {
    try {
      final updated = await itemRepo.unarchiveItem(itemId);
      if (!updated) {
        return OperationResult(
          success: false,
          itemId: itemId,
          error: StateError('资料不存在或不处于已归档资料'),
        );
      }
      registry.emit(ItemEvent(type: ItemEventType.saved, itemId: itemId));
      return OperationResult(success: true, itemId: itemId);
    } catch (error) {
      return OperationResult(success: false, itemId: itemId, error: error);
    }
  }

  Future<OperationResult> restoreItem(ItemWithFields rollback) async {
    try {
      final restored = await itemRepo.restoreFromTrash(rollback.id);
      if (restored) {
        registry.emit(
          ItemEvent(type: ItemEventType.restored, itemId: rollback.id),
        );
        return OperationResult(
          success: true,
          rollback: rollback,
          itemId: rollback.id,
        );
      }
      return OperationResult(
        success: false,
        rollback: rollback,
        error: StateError('资料不存在或不处于最近删除'),
        itemId: rollback.id,
      );
    } catch (error) {
      return OperationResult(
        success: false,
        rollback: rollback,
        error: error,
        itemId: rollback.id,
      );
    }
  }

  Future<OperationResult> permanentlyDeleteItem(String itemId) async {
    try {
      final item = await itemRepo.getItemWithFields(itemId);
      if (item == null || item.status != 'deleted') {
        return OperationResult(
          success: false,
          itemId: itemId,
          error: StateError('仅允许永久删除最近删除中的资料'),
        );
      }
      await itemRepo.deleteItem(itemId);
      registry.emit(ItemEvent(type: ItemEventType.deleted, itemId: itemId));
      return OperationResult(success: true, itemId: itemId);
    } catch (error) {
      return OperationResult(success: false, itemId: itemId, error: error);
    }
  }

  /// 搜寻匹配关键词的低敏资料，返回过滤后的 ItemModel 列表
  Future<List<ItemModel>> searchItems(String keyword) async {
    return searchService.searchItems(keyword);
  }
}
