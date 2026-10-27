import 'dart:convert';
import 'dart:math';
import '../../../core/service/interaction/field_interaction_rule.dart';
import '../../../core/service/validation/template_validator.dart';
import '../../../core/repository/models/item_with_fields.dart';
import '../../../core/service/models/item_draft_input.dart';
import '../../../core/template/field_priority.dart';
import 'package:flutter/foundation.dart';
import '../../../core/repository/models/member_model.dart';
import '../../../core/field/field_origin.dart';
import '../../../core/template/type_definition.dart';
import 'item_auto_fill_engine.dart';
import 'item_entry_flow_state.dart';
import 'field_state.dart';
import '../../../core/template/template_registry.dart';
import '../../../core/template/field_value_type.dart';

/// ItemEntryFlowController manages transitions and user selections
/// for the ItemEntryFlowPage wizard flow.
class ItemEntryFlowController extends ValueNotifier<ItemEntryFlowState> {
  final bool enableAutoFillScaffold;
  final ItemAutoFillEngine autoFillEngine;

  ItemEntryFlowController({
    required this.enableAutoFillScaffold,
    required this.autoFillEngine,
  }) : super(const ItemEntryFlowState(currentStep: ItemEntryStep.type));

  final _interactionEngine = FieldInteractionEngine.defaultEngine();

  /// 将用户输入和允许的联动结果一次提交，来源为 user 的目标字段不覆盖。
  void updateFieldWithInteractions(String key, String text) {
    final type = value.selectedType;
    if (type == null) return;
    final fields = Map<String, FieldState>.from(value.fieldValues);
    fields[key] = FieldState(value: text, origin: FieldOrigin.user);
    final updates = _interactionEngine.evaluate(
      typeKey: type.typeKey,
      fieldKey: key,
      value: text,
      currentFormValues: {
        for (final entry in fields.entries) entry.key: entry.value.value,
      },
    );
    for (final entry in updates.entries) {
      if (fields[entry.key]?.origin != FieldOrigin.user) {
        fields[entry.key] = FieldState(
          value: entry.value,
          origin: FieldOrigin.autofill,
        );
      }
    }
    // 动态字段计数仍由唯一状态写入原语维护。
    if (usesDynamicGenericFields) {
      applyFieldChange(key, text, FieldOrigin.user);
    } else {
      value = value.copyWith(fieldValues: fields);
    }
  }

  Map<String, String> requiredFieldErrors() {
    final type = value.selectedType;
    if (type == null) return const {};
    String text(String key) => value.fieldValues[key]?.value.trim() ?? '';
    final errors = <String, String>{};
    if (usesDynamicGenericFields) {
      for (var index = 1; index <= value.genericCustomFieldCount; index++) {
        final labelKey = genericFieldKey('label', index);
        final valueKey = genericFieldKey('value', index);
        final label = text(labelKey);
        final content = text(valueKey);
        if (label.isEmpty && content.isEmpty) continue;
        if (label.isEmpty) {
          errors[labelKey] = '请填写字段名';
        } else if (TemplateValidator.isForbiddenCustomFieldLabel(label)) {
          errors[labelKey] = '此字段涉及高危凭证，安册不会保存';
        }
        if (content.isEmpty) errors[valueKey] = '请填写字段值';
      }
    }
    for (final field in type.fields) {
      if (!field.required) continue;
      final isIdCard = type.typeKey == 'id_card';
      if (isIdCard &&
          field.fieldKey == 'valid_until' &&
          text('is_long_term') == 'true') {
        continue;
      }
      if (text(field.fieldKey).isEmpty) {
        errors[field.fieldKey] = isIdCard && field.fieldKey == 'gender'
            ? '请选择性别'
            : '字段 [${field.label}] 是必填项，当前未提供或内容为空。';
      }
    }
    return errors;
  }

  Map<String, String> identitySuggestions(Map<String, String> profile) {
    final type = value.selectedType;
    if (type == null) return const {};
    final available = type.fields.map((field) => field.fieldKey).toSet();
    final suggestions = <String, String>{};
    void suggest(String target, String? text) {
      if (text != null &&
          text.isNotEmpty &&
          available.contains(target) &&
          (value.fieldValues[target]?.value.trim().isEmpty ?? true)) {
        suggestions[target] = text;
      }
    }

    for (final key in const [
      'name',
      'name_cn',
      'child_name',
      'holder_name',
      'account_name',
    ]) {
      suggest(key, profile['name']);
    }
    for (final key in const ['gender', 'birth_date']) {
      suggest(key, profile[key]);
    }
    return suggestions;
  }

  /// 唯一的状态变更写入原语
  void applyFieldChange(String key, String valueStr, FieldOrigin origin) {
    final updated = Map<String, FieldState>.from(value.fieldValues);
    updated[key] = FieldState(value: valueStr, origin: origin);
    var count = value.genericCustomFieldCount;
    if (usesDynamicGenericFields) {
      final index = genericFieldIndex(key);
      if (index != null) {
        count = max(count, index);
        if ((updated[genericFieldKey('label', count)]?.value
                    .trim()
                    .isNotEmpty ??
                false) &&
            (updated[genericFieldKey('value', count)]?.value
                    .trim()
                    .isNotEmpty ??
                false)) {
          count++;
        }
      }
    }
    value = value.copyWith(
      fieldValues: updated,
      genericCustomFieldCount: count,
    );
  }

  void selectType(TypeDefinition type, {int? templateVersion}) {
    final typeDef = TemplateRegistry.getTemplate(type.typeKey, templateVersion);
    final initialFieldValues = <String, FieldState>{};
    if (typeDef != null) {
      for (final field in typeDef.fields) {
        initialFieldValues[field.fieldKey] = FieldState(
          value: field.valueType == FieldValueType.boolean ? 'false' : '',
          origin: FieldOrigin.unknown,
        );
      }
    }
    var newState = value.copyWith(
      selectedType: typeDef ?? type,
      selectedTemplateVersion: typeDef?.version ?? type.version,
      fieldValues: initialFieldValues,
      genericCustomFieldCount: 1,
    );
    value = newState;
  }

  void selectOwner(MemberModel owner) {
    var newState = value.copyWith(selectedOwner: owner);
    value = newState;

    if (newState.selectedType != null && enableAutoFillScaffold) {
      final autoFillMap = autoFillEngine.generateAutoFillValues(
        type: newState.selectedType!,
        owner: owner,
      );
      autoFillMap.forEach((k, v) {
        final currentField = value.fieldValues[k];
        // 仅在字段未被用户编辑过时覆盖填充
        if (currentField?.origin != FieldOrigin.user) {
          applyFieldChange(k, v, FieldOrigin.autofill);
        }
      });
    }
  }

  void updateField(String key, String valueStr) {
    applyFieldChange(key, valueStr, FieldOrigin.user);
  }

  void updateFieldWithMeta(
    String key,
    String valueStr, {
    required bool isUserEdit,
  }) {
    applyFieldChange(
      key,
      valueStr,
      isUserEdit ? FieldOrigin.user : FieldOrigin.autofill,
    );
  }

  void setFieldValues(Map<String, String> values) {
    values.forEach((k, v) {
      final current = value.fieldValues[k];
      if (current == null) {
        if (v.isNotEmpty) {
          applyFieldChange(k, v, FieldOrigin.user);
        }
      } else {
        if (current.value != v) {
          applyFieldChange(k, v, FieldOrigin.user);
        }
      }
    });
  }

  void setFieldValuesWithOrigin(
    Map<String, String> values,
    Map<String, FieldOrigin> origins,
  ) {
    values.forEach((k, v) {
      final origin = origins[k] ?? FieldOrigin.unknown;
      applyFieldChange(k, v, origin);
    });
  }

  /// 编辑页首载使用的原子初始化入口，只向监听方发送一次状态变更。
  void initializeForEdit({
    required TypeDefinition type,
    required int templateVersion,
    required MemberModel? owner,
    required Map<String, String> values,
    required Map<String, FieldOrigin> origins,
    int genericCustomFieldCount = 1,
  }) {
    final fieldValues = <String, FieldState>{
      for (final entry in values.entries)
        entry.key: FieldState(
          value: entry.value,
          origin: origins[entry.key] ?? FieldOrigin.unknown,
        ),
    };
    value = ItemEntryFlowState(
      currentStep: ItemEntryStep.editableReview,
      selectedType: type,
      selectedTemplateVersion: templateVersion,
      selectedOwner: owner,
      fieldValues: fieldValues,
      genericCustomFieldCount: genericCustomFieldCount,
    );
  }

  bool get usesDynamicGenericFields =>
      value.selectedType?.typeKey == 'generic' &&
      value.selectedType?.version == 2;

  static int? genericFieldIndex(String key) {
    final match = RegExp(
      r'^custom_field_(?:label|value)_([1-9]\d*)$',
    ).firstMatch(key);
    return match == null ? null : int.parse(match.group(1)!);
  }

  static String genericFieldKey(String kind, int index) =>
      'custom_field_${kind}_$index';

  void addGenericField() {
    if (usesDynamicGenericFields) {
      value = value.copyWith(
        genericCustomFieldCount: value.genericCustomFieldCount + 1,
      );
    }
  }

  /// 删除并紧凑排列整对字段，同时清除已不存在的旧键并保留来源。
  void removeGenericField(int index) {
    if (!usesDynamicGenericFields ||
        index < 1 ||
        index > value.genericCustomFieldCount) {
      return;
    }
    final updated = Map<String, FieldState>.from(value.fieldValues)
      ..removeWhere((key, _) => genericFieldIndex(key) != null);
    var target = 1;
    for (var current = 1; current <= value.genericCustomFieldCount; current++) {
      if (current == index) continue;
      for (final kind in ['label', 'value']) {
        final field = value.fieldValues[genericFieldKey(kind, current)];
        if (field != null) updated[genericFieldKey(kind, target)] = field;
      }
      target++;
    }
    value = value.copyWith(
      fieldValues: updated,
      genericCustomFieldCount: max(1, target - 1),
    );
  }

  List<ItemFieldDraftInput> buildDraftFields() {
    final type = value.selectedType;
    if (type == null) return const [];
    ItemFieldDraftInput draft(String key) => ItemFieldDraftInput(
      fieldKey: key,
      valueText: value.fieldValues[key]?.value ?? '',
      origin: value.fieldValues[key]?.origin ?? FieldOrigin.user,
    );
    if (!usesDynamicGenericFields) {
      return type.fields.map((field) => draft(field.fieldKey)).toList();
    }
    return [
      draft('title'),
      for (var index = 1; index <= value.genericCustomFieldCount; index++)
        if ((value.fieldValues[genericFieldKey('label', index)]?.value
                    .trim()
                    .isNotEmpty ??
                false) ||
            (value.fieldValues[genericFieldKey('value', index)]?.value
                    .trim()
                    .isNotEmpty ??
                false)) ...[
          draft(genericFieldKey('label', index)),
          draft(genericFieldKey('value', index)),
        ],
    ];
  }

  bool get hasOptionalValues =>
      value.selectedType?.fields.any((field) {
        if (field.required || field.priority == FieldPriority.p0) return false;
        final text = value.fieldValues[field.fieldKey]?.value ?? '';
        return field.valueType == FieldValueType.boolean
            ? text == 'true'
            : text.trim().isNotEmpty;
      }) ??
      false;

  /// 只还原业务值与来源，输入控制器和焦点仍由页面管理。
  void initializeFromItem(ItemWithFields item, {required MemberModel? owner}) {
    final type = item.typeKey == null
        ? null
        : TemplateRegistry.getTemplate(item.typeKey!, item.templateVersion);
    final fields = <String, String>{};
    final origins = <String, FieldOrigin>{};
    Map? storedOrigins;
    try {
      final metadata = item.metadata == null
          ? null
          : jsonDecode(item.metadata!);
      if (metadata is Map && metadata['field_origins'] is Map) {
        storedOrigins = metadata['field_origins'] as Map;
      }
    } catch (_) {
      /* 损坏来源按 unknown 还原，不推测用户输入。 */
    }
    final byKey = {for (final field in item.fields) field.fieldKey: field};
    for (final field in type?.fields ?? []) {
      fields[field.fieldKey] = byKey[field.fieldKey]?.valueText ?? '';
      origins[field.fieldKey] = FieldOrigin.values.firstWhere(
        (origin) => origin.name == storedOrigins?[field.fieldKey],
        orElse: () => FieldOrigin.unknown,
      );
    }
    var count = 1;
    if (type?.typeKey == 'generic' && type?.version == 2) {
      var lastIndex = 0;
      for (final field in item.fields) {
        final index = genericFieldIndex(field.fieldKey);
        if (index == null || (field.valueText?.trim().isEmpty ?? true)) {
          continue;
        }
        lastIndex = max(lastIndex, index);
        fields[field.fieldKey] = field.valueText!;
        origins[field.fieldKey] = FieldOrigin.values.firstWhere(
          (origin) => origin.name == storedOrigins?[field.fieldKey],
          orElse: () => FieldOrigin.unknown,
        );
      }
      count = lastIndex + 1;
    }
    if (type == null) {
      value = ItemEntryFlowState(
        currentStep: ItemEntryStep.editableReview,
        selectedTemplateVersion: item.templateVersion,
        selectedOwner: owner,
      );
    } else {
      initializeForEdit(
        type: type,
        templateVersion: item.templateVersion,
        owner: owner,
        values: fields,
        origins: origins,
        genericCustomFieldCount: count,
      );
    }
  }

  bool get hasAnyNonEmptyAutoFill {
    return value.fieldValues.values.any(
      (f) => f.origin == FieldOrigin.autofill && f.value.trim().isNotEmpty,
    );
  }

  void nextStep() {
    final index = value.currentStep.index;
    if (index < ItemEntryStep.values.length - 1) setStep(index + 1);
  }

  void prevStep() {
    final index = value.currentStep.index;
    if (index > 0) setStep(index - 1);
  }

  void setStep(int index) => setStepEnum(ItemEntryStep.values[index]);

  void setStepEnum(ItemEntryStep step) {
    value = value.copyWith(currentStep: step);
  }
}
