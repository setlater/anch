import '../../template/template_registry.dart';
import '../../template/migration_registry.dart';
import '../models/item_draft_input.dart';
import 'field_validation_error.dart';
import 'template_validator.dart';

/// 资料字段轻量级结构契约校验器 (只做静态判定校验，无任何执行副作用)
class FieldContractValidator {
  /// 校验资料草稿的结构契约（非侵入式校验，不自动触发任何更改）
  static ValidationResult validate(ItemDraftInput draft) {
    final errors = <FieldValidationError>[];
    final warnings = <FieldValidationError>[];
    bool migrationRequired = false;

    // 1. 验证类型标识 (typeKey) 与版本是否存在及兼容
    if (draft.typeKey == null || draft.typeKey!.isEmpty) {
      errors.add(
        FieldValidationError(
          errorCode: FieldValidationErrorCode.invalidTemplateType,
          errorMessage: '未指定资料子类型。',
        ),
      );
      return ValidationResult(errors: errors, warnings: warnings);
    }

    final existsAny = TemplateRegistry.getTemplate(draft.typeKey!) != null;
    final typeDef = TemplateRegistry.getTemplate(
      draft.typeKey!,
      draft.templateVersion,
    );

    if (typeDef == null) {
      if (existsAny) {
        errors.add(
          SchemaValidationError(
            errorCode: FieldValidationErrorCode.versionMismatch,
            errorMessage:
                '未找到版本为 [${draft.templateVersion}] 的模板 [${draft.typeKey}]。',
          ),
        );
      } else {
        errors.add(
          FieldValidationError(
            errorCode: FieldValidationErrorCode.invalidTemplateType,
            errorMessage: '未找到子类型标识为 [${draft.typeKey}] 的模板定义。',
          ),
        );
      }
      return ValidationResult(errors: errors, warnings: warnings);
    }

    // 2. 验证版本兼容与是否需要迁移路径 (对比当前注册的最新版本)
    final latestTypeDef = TemplateRegistry.getTemplate(draft.typeKey!);
    if (latestTypeDef != null &&
        latestTypeDef.version != draft.templateVersion &&
        !typeDef.supportsLegacyEditing) {
      if (MigrationRegistry.hasPath(
        draft.templateVersion,
        latestTypeDef.version,
      )) {
        migrationRequired = true;
        warnings.add(
          SchemaValidationError(
            errorCode: FieldValidationErrorCode.migrationRequired,
            errorMessage:
                '当前数据版本 [${draft.templateVersion}] 滞后于最新模板版本 [${latestTypeDef.version}]，可进行结构迁移。',
            isWarning: true,
          ),
        );
      } else {
        errors.add(
          SchemaValidationError(
            errorCode: FieldValidationErrorCode.versionMismatch,
            errorMessage:
                '数据版本 [${draft.templateVersion}] 不匹配最新模板版本 [${latestTypeDef.version}]，且未定义迁移转换规则路径。',
          ),
        );
        return ValidationResult(errors: errors, warnings: warnings);
      }
    }

    // 3. 验证资料大类是否匹配
    if (typeDef.categoryKey != draft.categoryKey) {
      errors.add(
        FieldValidationError(
          errorCode: FieldValidationErrorCode.categoryMismatch,
          errorMessage:
              '传入的资料大类 [${draft.categoryKey}] 与模板定义的所属大类 [${typeDef.categoryKey}] 不匹配。',
        ),
      );
      return ValidationResult(
        errors: errors,
        warnings: warnings,
        migrationRequired: migrationRequired,
      );
    }

    // 建立当前模板字段映射
    final templateFieldsMap = {for (final f in typeDef.fields) f.fieldKey: f};
    final genericCustomFieldIndexes = <int>{};

    // 4. 校验传入的各个字段是否符合静态契约
    for (final inputField in draft.fields) {
      final fieldKey = inputField.fieldKey;
      final genericCustomFieldIndex = _genericCustomFieldIndex(draft, fieldKey);

      if (genericCustomFieldIndex != null) {
        genericCustomFieldIndexes.add(genericCustomFieldIndex);
        if (fieldKey.startsWith('custom_field_label_') &&
            TemplateValidator.isForbiddenCustomFieldLabel(
              inputField.valueText ?? '',
            )) {
          errors.add(
            FieldValidationError(
              fieldKey: fieldKey,
              errorCode: FieldValidationErrorCode.forbiddenFieldSaved,
              errorMessage: '自定义字段名涉及高危凭证，系统绝不录入和保存此项信息。',
            ),
          );
        }
        continue;
      }

      // (a) 最优先规则：如果是高危敏感词，判定为 forbiddenFieldSaved 错误
      if (TemplateValidator.isForbiddenKey(fieldKey)) {
        errors.add(
          FieldValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.forbiddenFieldSaved,
            errorMessage: '字段 [$fieldKey] 包含高危敏感特征词，系统绝不录入和保存此项高危凭证信息！',
          ),
        );
        continue;
      }

      // 预先获取当前字段是否已被声明废弃
      final isDeprecated = TemplateRegistry.isFieldDeprecated(
        draft.typeKey!,
        fieldKey,
        typeDef.version,
      );

      if (isDeprecated) {
        warnings.add(
          SchemaValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.deprecatedField,
            errorMessage:
                '字段 [$fieldKey] 在模板 [${typeDef.label}] 的当前版本 [${typeDef.version}] 下已被废弃。',
            isWarning: true,
          ),
        );
      }

      // (b) 验证字段 Key 是否在全局静态注册中心中
      if (!TemplateRegistry.allFieldKeys.contains(fieldKey)) {
        errors.add(
          FieldValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.unknownFieldKey,
            errorMessage: '字段 [$fieldKey] 未在任何注册的静态字段契约中定义。',
          ),
        );
        continue;
      }

      // (c) 验证字段 Key 是否属于当前子类型模板定义的字段集合中
      final fieldDef = templateFieldsMap[fieldKey];
      if (fieldDef == null) {
        if (isDeprecated) {
          // 如果字段已被废弃且模板无定义，跳过 blocking error 校验（仅标记废弃警告即可，不阻断保存）
          continue;
        }
        errors.add(
          FieldValidationError(
            fieldKey: fieldKey,
            errorCode: FieldValidationErrorCode.unknownFieldKey,
            errorMessage:
                '字段 [$fieldKey] 不在模板 [${typeDef.label}] 的字段定义集合中，拒绝保存。',
          ),
        );
        continue;
      }

      // (d) 验证字段值是否符合值类型格式约束
      final valueText = inputField.valueText;
      if (valueText != null && valueText.isNotEmpty) {
        final formatError = TemplateValidator.validateValueType(
          fieldDef.valueType,
          valueText,
        );
        if (formatError != null) {
          errors.add(
            FieldValidationError(
              fieldKey: fieldKey,
              errorCode: FieldValidationErrorCode.invalidFormat,
              errorMessage: '字段 [${fieldDef.label}] 输入内容格式不合规：$formatError',
            ),
          );
        }
      }
    }

    for (final index in genericCustomFieldIndexes) {
      final labelKey = 'custom_field_label_$index';
      final valueKey = 'custom_field_value_$index';
      final label =
          draft.fields
              .firstWhere(
                (field) => field.fieldKey == labelKey,
                orElse: () => ItemFieldDraftInput(fieldKey: labelKey),
              )
              .valueText
              ?.trim() ??
          '';
      final value =
          draft.fields
              .firstWhere(
                (field) => field.fieldKey == valueKey,
                orElse: () => ItemFieldDraftInput(fieldKey: valueKey),
              )
              .valueText
              ?.trim() ??
          '';
      if (label.isEmpty && value.isEmpty) continue;
      if (label.isEmpty) {
        errors.add(
          FieldValidationError(
            fieldKey: labelKey,
            errorCode: FieldValidationErrorCode.requiredFieldMissing,
            errorMessage: '自定义字段必须填写字段名。',
          ),
        );
      }
      if (value.isEmpty) {
        errors.add(
          FieldValidationError(
            fieldKey: valueKey,
            errorCode: FieldValidationErrorCode.requiredFieldMissing,
            errorMessage: '自定义字段必须填写字段值。',
          ),
        );
      }
    }

    // 5. 必填字段缺失校验（模板声明必填）
    for (final fieldDef in typeDef.fields) {
      if (fieldDef.required) {
        final inputField = draft.fields.firstWhere(
          (f) => f.fieldKey == fieldDef.fieldKey,
          orElse: () => ItemFieldDraftInput(fieldKey: fieldDef.fieldKey),
        );
        final val = inputField.valueText;
        if (val == null || val.trim().isEmpty) {
          errors.add(
            FieldValidationError(
              fieldKey: fieldDef.fieldKey,
              errorCode: FieldValidationErrorCode.requiredFieldMissing,
              errorMessage: '字段 [${fieldDef.label}] 是必填项，当前未提供或内容为空。',
            ),
          );
        }
      }
    }

    return ValidationResult(
      errors: errors,
      warnings: warnings,
      migrationRequired: migrationRequired,
    );
  }

  static int? _genericCustomFieldIndex(ItemDraftInput draft, String fieldKey) {
    if (draft.typeKey != 'generic' || draft.templateVersion != 2) {
      return null;
    }
    final match = RegExp(
      r'^custom_field_(?:label|value)_([1-9]\d*)$',
    ).firstMatch(fieldKey);
    return match == null ? null : int.parse(match.group(1)!);
  }
}
