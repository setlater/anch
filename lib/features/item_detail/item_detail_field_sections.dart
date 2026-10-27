import '../../core/template/template_registry.dart';
import '../../core/template/type_definition.dart';
import '../../core/template/field_definition.dart';
import '../../core/template/field_value_type.dart';
import '../../core/security/field_render_policy.dart';
import '../../core/repository/models/item_child_entry_model.dart';
import '../../core/widgets/anch_sensitive_field_row.dart';
import '../../core/widgets/anch_sensitive_plate.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../core/repository/models/item_event_model.dart';
import '../../core/repository/models/item_with_fields.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_detail_field_row_layout.dart';
import '../../core/widgets/anch_field_group_card.dart';
import '../../core/widgets/anch_info_field_row.dart';
import '../../core/theme/anch_radius.dart';

class ItemDetailCollapsibleGroupCard extends StatelessWidget {
  const ItemDetailCollapsibleGroupCard({
    super.key,
    required this.title,
    required this.children,
    required this.isExpanded,
    required this.onToggle,
    this.description,
  });

  final String title;
  final String? description;
  final List<Widget> children;
  final bool isExpanded;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final itemsWithDividers = <Widget>[];
    if (isExpanded) {
      for (var index = 0; index < children.length; index++) {
        itemsWithDividers.add(children[index]);
        if (index < children.length - 1) {
          itemsWithDividers.add(
            Divider(height: 1, thickness: 1, color: colors.divider),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onToggle(!isExpanded),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                AnchIcon(
                  isExpanded ? AnchIcons.chevronUp : AnchIcons.chevronDown,
                  size: 20,
                  color: colors.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && children.isNotEmpty) ...[
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 1, color: colors.divider),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(AnchRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: itemsWithDividers,
            ),
          ),
        ],
      ],
    );
  }
}

/// 只负责资料字段的筛选、分组与渲染；页面拥有显隐状态和复制／生命周期控制。
class ItemDetailFieldsSection extends StatelessWidget {
  const ItemDetailFieldsSection({
    super.key,
    required this.item,
    required this.typeDef,
    required this.childEntries,
    required this.revealedFieldKeys,
    required this.revealedChildFieldIds,
    required this.onCopy,
    required this.onChildCopy,
    required this.onReveal,
    required this.onRevealChild,
    required this.onCopyPrimary,
  });
  final ItemWithFields item;
  final TypeDefinition? typeDef;
  final List<ItemChildEntryModel> childEntries;
  final Set<String> revealedFieldKeys;
  final Set<String> revealedChildFieldIds;
  final ValueChanged<String> onCopy;
  final ValueChanged<ItemChildFieldModel> onChildCopy;
  final void Function(String key, bool reveal) onReveal;
  final void Function(String key, bool reveal) onRevealChild;
  final ValueChanged<ItemFieldModel> onCopyPrimary;

  ItemFieldModel? _fieldByKey(ItemWithFields item, String key) {
    for (final field in item.fields) {
      if (field.fieldKey == key) return field;
    }
    return null;
  }

  bool _hasDisplayValue(ItemFieldModel? field) {
    return field != null &&
        field.valueText != null &&
        field.valueText!.trim().isNotEmpty;
  }

  AnchValueDisplayMode _resolveDetailValueDisplayMode(
    String fieldKey,
    FieldValueType? valueType,
  ) {
    if (fieldKey == 'address' ||
        fieldKey == 'household_address' ||
        fieldKey == 'note' ||
        fieldKey == 'remark' ||
        fieldKey == 'description') {
      return AnchValueDisplayMode.multiline;
    }

    if (valueType == FieldValueType.idNumber ||
        valueType == FieldValueType.bankCardNumber ||
        fieldKey == 'id_number' ||
        fieldKey == 'bank_card_number' ||
        fieldKey == 'card_number' ||
        fieldKey == 'certificate_number' ||
        fieldKey == 'policy_number' ||
        fieldKey == 'vin' ||
        fieldKey == 'license_number' ||
        fieldKey == 'account_number') {
      return AnchValueDisplayMode.singleLineScrollable;
    }

    if (valueType == FieldValueType.text ||
        valueType == FieldValueType.sensitiveText) {
      return AnchValueDisplayMode.multiline;
    }

    return AnchValueDisplayMode.normal;
  }

  /// 构建单个字段的行组件
  Widget _buildFieldWidget(
    ItemFieldModel field,
    FieldDefinition? fieldDef, {
    double? labelWidth,
  }) {
    final level = fieldDef?.sensitiveLevel ?? SensitiveLevel.none;
    if (!FieldRenderPolicy.isFieldAllowed(field.fieldKey, level)) {
      return const SizedBox.shrink();
    }

    final label = fieldDef?.label ?? field.rawFieldLabel ?? field.fieldKey;
    var value = field.valueText ?? '';
    if (fieldDef?.valueType == FieldValueType.dayOfMonth && value.isNotEmpty) {
      value = '每月 $value 日';
    } else if (fieldDef?.valueType == FieldValueType.boolean &&
        value.isNotEmpty) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true' || lower == '1') {
        value = '是';
      } else if (lower == 'false' || lower == '0') {
        value = '否';
      }
    }
    final copyable =
        (fieldDef?.copyable ?? false) &&
        value.trim().isNotEmpty &&
        level != SensitiveLevel.forbidden;

    final displayMode = _resolveDetailValueDisplayMode(
      field.fieldKey,
      fieldDef?.valueType,
    );

    if (FieldRenderPolicy.shouldMaskField(level)) {
      final isRevealed = revealedFieldKeys.contains(field.fieldKey);
      return AnchSensitiveFieldRow(
        fieldId: field.id,
        label: label,
        value: value,
        maskedValue: '******',
        isRevealed: isRevealed,
        fieldNote: field.fieldNote,
        copyable: copyable,
        onCopy: onCopy,
        valueDisplayMode: displayMode,
        fieldKey: field.fieldKey,
        labelWidth: labelWidth ?? 100,
        onToggleReveal: (reveal) {
          onReveal(field.fieldKey, reveal);
        },
      );
    } else {
      return AnchInfoFieldRow(
        fieldId: field.id,
        label: label,
        value: value,
        fieldNote: field.fieldNote,
        copyable: copyable,
        onCopy: onCopy,
        valueDisplayMode: displayMode,
        fieldKey: field.fieldKey,
        labelWidth: labelWidth ?? 100,
      );
    }
  }

  double _resolveDetailLabelWidth(
    BuildContext context,
    Iterable<String> labels,
  ) {
    var widest = 0.0;
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    for (final label in labels) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        ),
        textDirection: textDirection,
        textScaler: textScaler,
      )..layout();
      widest = painter.width > widest ? painter.width : widest;
    }
    return widest.ceilToDouble().clamp(80.0, 120.0);
  }

  String _formatDisplayValue(
    String value,
    bool isRevealed,
    String? normalizedValue,
  ) {
    if (!isRevealed) {
      final last4 =
          normalizedValue ??
          (value.length >= 4 ? value.substring(value.length - 4) : '');
      if (last4.isEmpty) return '••••';
      return '••••  ••••  ••••  $last4';
    }
    final digitsOnly = RegExp(r'^\d+$').hasMatch(value);
    if (digitsOnly && (value.length == 16 || value.length == 19)) {
      final buffer = StringBuffer();
      for (int i = 0; i < value.length; i++) {
        buffer.write(value[i]);
        if ((i + 1) % 4 == 0 && i != value.length - 1) {
          buffer.write('  ');
        }
      }
      return buffer.toString();
    }
    return value;
  }

  String? _getPrimaryNumberFieldKey(String? typeKey) {
    if (typeKey == null) return null;
    switch (typeKey) {
      case 'id_card':
        return 'id_number';
      case 'passport':
        return 'passport_number';
      case 'hk_macao_pass':
        return 'pass_number';
      case 'driver_license':
        return 'license_number';
      case 'vehicle_license':
        return 'vin';
      case 'household_book':
        return 'household_number';
      case 'debit_card':
      case 'credit_card':
        return 'card_number';
      case 'insurance':
        return 'policy_number';
      case 'birth_certificate':
      case 'marriage_certificate':
      case 'property_certificate':
      case 'education_certificate':
        return 'certificate_number';
      default:
        return null;
    }
  }

  List<Widget> _buildUnifiedFieldGroups(
    BuildContext context,
    ItemWithFields item,
    TypeDefinition? typeDef,
  ) {
    if (item.typeKey == 'generic' && typeDef?.version == 2) {
      return _buildGenericV2FieldGroups(context, item, typeDef!);
    }

    final primaryNumberKey = _getPrimaryNumberFieldKey(item.typeKey);
    final fieldsToShow = <ItemFieldModel>[];
    for (final field in item.fields) {
      final fieldDef = TemplateRegistry.fieldDefinitionByKey(
        typeDef,
        field.fieldKey,
      );
      final level = fieldDef?.sensitiveLevel ?? SensitiveLevel.none;

      if (field.fieldKey == primaryNumberKey) {
        continue;
      }
      if (typeDef != null) {
        final inTypeDef = typeDef.fields.any(
          (fd) => fd.fieldKey == field.fieldKey,
        );
        if (!inTypeDef) {
          continue;
        }
      }
      if (!_hasDisplayValue(field)) {
        continue;
      }
      if (!FieldRenderPolicy.isFieldAllowed(field.fieldKey, level)) {
        continue;
      }
      fieldsToShow.add(field);
    }

    if (typeDef != null) {
      fieldsToShow.sort((a, b) {
        final indexA = typeDef.fields.indexWhere(
          (f) => f.fieldKey == a.fieldKey,
        );
        final indexB = typeDef.fields.indexWhere(
          (f) => f.fieldKey == b.fieldKey,
        );

        final resolvedIndexA = indexA == -1 ? 999 : indexA;
        final resolvedIndexB = indexB == -1 ? 999 : indexB;

        if (resolvedIndexA == 999 && resolvedIndexB == 999) {
          return a.sortOrder.compareTo(b.sortOrder);
        }
        return resolvedIndexA.compareTo(resolvedIndexB);
      });
    }

    final labelWidth = _resolveDetailLabelWidth(
      context,
      fieldsToShow.map(
        (field) => _resolveDisplayFieldLabel(
          item,
          field,
          TemplateRegistry.fieldDefinitionByKey(typeDef, field.fieldKey),
        ),
      ),
    );
    final children = <Widget>[];
    for (final field in fieldsToShow) {
      final fieldDef = TemplateRegistry.fieldDefinitionByKey(
        typeDef,
        field.fieldKey,
      );
      if (field.fieldKey == 'is_long_term') {
        final valText = field.valueText?.trim().toLowerCase() ?? '';
        if (valText != 'true' && valText != '1') {
          continue;
        }
        final mappedField = ItemFieldModel(
          id: field.id,
          itemId: field.itemId,
          fieldKey: field.fieldKey,
          valueType: field.valueType,
          valueText: '长期有效',
          normalizedValue: field.normalizedValue,
          fieldNote: field.fieldNote,
          templateFieldKnown: true,
          isArchivedField: false,
          rawFieldLabel: field.rawFieldLabel,
          sortOrder: field.sortOrder,
          createdAt: field.createdAt,
          updatedAt: field.updatedAt,
        );
        children.add(
          _buildFieldWidget(mappedField, fieldDef, labelWidth: labelWidth),
        );
      } else {
        children.add(
          _buildFieldWidget(field, fieldDef, labelWidth: labelWidth),
        );
      }
    }

    return children;
  }

  List<Widget> _buildGenericV2FieldGroups(
    BuildContext context,
    ItemWithFields item,
    TypeDefinition typeDef,
  ) {
    final fieldsToShow = <(ItemFieldModel, FieldDefinition)>[];
    final title = _fieldByKey(item, 'title');
    final titleDef = TemplateRegistry.fieldDefinitionByKey(typeDef, 'title');
    if (_hasDisplayValue(title)) {
      fieldsToShow.add((title!, titleDef!));
    }

    final indexes =
        item.fields
            .map((field) => _genericCustomFieldIndex(field.fieldKey))
            .whereType<int>()
            .toSet()
            .toList()
          ..sort();
    for (final index in indexes) {
      final valueKey = 'custom_field_value_$index';
      final valueField = _fieldByKey(item, valueKey);
      if (!_hasDisplayValue(valueField)) continue;

      final labelField = _fieldByKey(item, 'custom_field_label_$index');
      final customLabel = labelField?.valueText?.trim();
      final displayDef = FieldDefinition(
        fieldKey: valueKey,
        label: customLabel == null || customLabel.isEmpty
            ? '字段 $index'
            : customLabel,
        valueType: FieldValueType.text,
        sensitiveLevel: SensitiveLevel.low,
        copyable: true,
      );
      fieldsToShow.add((valueField!, displayDef));
    }
    final labelWidth = _resolveDetailLabelWidth(
      context,
      fieldsToShow.map((field) => field.$2.label),
    );
    return fieldsToShow
        .map(
          (field) =>
              _buildFieldWidget(field.$1, field.$2, labelWidth: labelWidth),
        )
        .toList();
  }

  String _resolveDisplayFieldLabel(
    ItemWithFields item,
    ItemFieldModel field,
    FieldDefinition? fieldDef,
  ) {
    if (item.typeKey == 'generic' && item.templateVersion == 2) {
      final index = _genericCustomFieldIndex(field.fieldKey);
      if (index != null && field.fieldKey.startsWith('custom_field_value_')) {
        final labelField = _fieldByKey(item, 'custom_field_label_$index');
        final customLabel = labelField?.valueText?.trim();
        if (customLabel != null && customLabel.isNotEmpty) {
          return customLabel;
        }
        return '字段 $index';
      }
    }
    return fieldDef?.label ?? field.rawFieldLabel ?? field.fieldKey;
  }

  int? _genericCustomFieldIndex(String fieldKey) {
    final match = RegExp(
      r'^custom_field_(?:label|value)_([1-9]\d*)$',
    ).firstMatch(fieldKey);
    return match == null ? null : int.parse(match.group(1)!);
  }

  List<Widget> _buildHouseholdBookMembersSectionList(
    BuildContext context,
    ItemWithFields item,
    TypeDefinition? typeDef,
  ) {
    final List<Widget> groups = [];
    if (childEntries.isEmpty) return groups;

    for (int entryIdx = 0; entryIdx < childEntries.length; entryIdx++) {
      final entry = childEntries[entryIdx];

      ItemChildFieldModel? nameField;
      for (final f in entry.fields) {
        if (f.fieldKey == 'member_name') {
          nameField = f;
          break;
        }
      }
      final nameVal = nameField?.valueText?.trim() ?? '';
      final cardTitle = nameVal.isNotEmpty ? nameVal : '第 ${entryIdx + 1} 位成员';

      final List<Widget> memberFieldsWidgets = [];
      final visibleFields = entry.fields
          .where((field) => (field.valueText ?? '').trim().isNotEmpty)
          .toList();
      final labelWidth = _resolveDetailLabelWidth(
        context,
        visibleFields.map((field) => field.label),
      );

      for (int fieldIdx = 0; fieldIdx < visibleFields.length; fieldIdx++) {
        final f = visibleFields[fieldIdx];
        final val = f.valueText ?? '';

        final label = f.label;
        final isSensitive =
            f.sensitiveLevel == 'high' || f.sensitiveLevel == 'medium';
        final copyable =
            f.copyable &&
            val.trim().isNotEmpty &&
            f.sensitiveLevel != 'forbidden';
        final displayMode = _resolveDetailValueDisplayMode(f.fieldKey, null);

        if (isSensitive) {
          final childFieldUniqueId = '${entry.id}_${f.fieldKey}';
          final isRevealed = revealedChildFieldIds.contains(childFieldUniqueId);
          final testKey = 'member_${entryIdx}_${f.fieldKey}';

          memberFieldsWidgets.add(
            AnchSensitiveFieldRow(
              fieldId: childFieldUniqueId,
              label: label,
              value: val,
              maskedValue: '******',
              isRevealed: isRevealed,
              copyable: copyable,
              onCopy: (id) => onChildCopy(f),
              valueDisplayMode: displayMode,
              fieldKey: testKey,
              labelWidth: labelWidth,
              onToggleReveal: (reveal) {
                onRevealChild(childFieldUniqueId, reveal);
              },
            ),
          );
        } else {
          final testKey = 'member_${entryIdx}_${f.fieldKey}';
          memberFieldsWidgets.add(
            AnchInfoFieldRow(
              fieldId: '${entry.id}_${f.fieldKey}',
              label: label,
              value: val,
              copyable: copyable,
              onCopy: (id) => onChildCopy(f),
              valueDisplayMode: displayMode,
              fieldKey: testKey,
              labelWidth: labelWidth,
            ),
          );
        }
      }

      if (memberFieldsWidgets.isNotEmpty) {
        groups.add(
          AnchFieldGroupCard(
            key: Key('household_member_card_$entryIdx'),
            title: cardTitle,
            children: memberFieldsWidgets,
          ),
        );
        groups.add(const SizedBox(height: AnchSpacing.sectionGap));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final fields = _buildUnifiedFieldGroups(context, item, typeDef);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        (() {
          final primaryKey = _getPrimaryNumberFieldKey(item.typeKey);
          if (primaryKey == null) {
            return const SizedBox.shrink();
          }

          final field = _fieldByKey(item, primaryKey);
          if (field == null || !_hasDisplayValue(field)) {
            return const SizedBox.shrink();
          }

          final fieldDef = TemplateRegistry.fieldDefinitionByKey(
            typeDef,
            primaryKey,
          );
          final label = fieldDef?.label ?? field.rawFieldLabel ?? primaryKey;
          final value = field.valueText ?? '';
          final isRevealed = revealedFieldKeys.contains(primaryKey);
          final displayValue = _formatDisplayValue(
            value,
            isRevealed,
            field.normalizedValue,
          );

          return AnchSensitivePlate(
            fieldKey: primaryKey,
            label: label,
            displayValue: displayValue,
            valueLength: value.length,
            isRevealed: isRevealed,
            copyButtonKey: item.typeKey == 'debit_card'
                ? const Key('debit_card_header_copy')
                : (item.typeKey == 'credit_card'
                      ? const Key('credit_card_header_copy')
                      : const Key('primary_sensitive_copy_button')),
            onToggleReveal: () {
              onReveal(primaryKey, !isRevealed);
            },
            onCopy: () => onCopyPrimary(field),
          );
        })(),
        if (fields.isNotEmpty) ItemDetailUnifiedFieldsCard(children: fields),
        if (item.typeKey == 'household_book' && childEntries.isNotEmpty)
          ..._buildHouseholdBookMembersSectionList(context, item, typeDef),
      ],
    );
  }
}

class ItemDetailUnifiedFieldsCard extends StatelessWidget {
  const ItemDetailUnifiedFieldsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final itemsWithDividers = <Widget>[];
    for (var index = 0; index < children.length; index++) {
      itemsWithDividers.add(children[index]);
      if (index < children.length - 1) {
        itemsWithDividers.add(
          Divider(height: 1, thickness: 1, color: colors.divider),
        );
      }
    }

    return Container(
      key: const Key('unified_fields_card'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AnchSpacing.sectionGap),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: itemsWithDividers,
      ),
    );
  }
}

class ItemDetailHeaderSection extends StatelessWidget {
  const ItemDetailHeaderSection({
    super.key,
    required this.title,
    required this.icon,
    required this.tags,
  });

  final String title;
  final AnchIconData icon;
  final List<Widget> tags;

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 24,
      height: 1.2,
      fontWeight: FontWeight.w600,
    );
    final titleLineHeight =
        MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) *
        titleStyle.height!;
    return Container(
      key: const Key('detail_header_section'),
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: AnchSpacing.sectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: const Key('detail_title_icon_line_box'),
                height: titleLineHeight,
                child: Center(
                  child: AnchIcon(
                    icon,
                    key: const Key('detail_title_type_icon'),
                    size: 24,
                    color: context.anchColors.documentIcon,
                  ),
                ),
              ),
              const SizedBox(width: AnchSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: titleStyle.fontSize,
                    height: titleStyle.height,
                    fontWeight: titleStyle.fontWeight,
                    color: context.anchColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(spacing: AnchSpacing.sm, runSpacing: 6, children: tags),
        ],
      ),
    );
  }
}

class ItemDetailActionTraceSection extends StatelessWidget {
  const ItemDetailActionTraceSection({
    super.key,
    required this.events,
    required this.isExpanded,
    required this.onExpandedChanged,
  });

  final Future<List<ItemEventModel>> events;
  final bool isExpanded;
  final ValueChanged<bool> onExpandedChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ItemEventModel>>(
      future: events,
      builder: (context, snapshot) {
        final traces = snapshot.data ?? const <ItemEventModel>[];
        final children = <Widget>[];
        for (final trace in traces) {
          final colors = context.anchColors;
          final (actionLabel, actionColor) = switch (trace.eventType) {
            ItemEventType.created => ('已创建', colors.success),
            ItemEventType.updated => ('已更新', colors.accentDeep),
            ItemEventType.archived => ('已归档', colors.accentDeep),
            ItemEventType.unarchived => ('已取消归档', colors.success),
            ItemEventType.movedToTrash => ('移入最近删除', colors.danger),
            ItemEventType.restored => ('已恢复', colors.accentDeep),
            ItemEventType.imported => ('已导入', colors.accentDeep),
          };
          final time = DateTime.fromMillisecondsSinceEpoch(trace.occurredAt);
          final timeText =
              '${time.year.toString().padLeft(4, '0')}-'
              '${time.month.toString().padLeft(2, '0')}-'
              '${time.day.toString().padLeft(2, '0')} '
              '${time.hour.toString().padLeft(2, '0')}:'
              '${time.minute.toString().padLeft(2, '0')}';
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: actionColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          actionLabel,
                          style: TextStyle(
                            color: actionColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          timeText,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.anchColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  for (final change in trace.changes)
                    Padding(
                      padding: const EdgeInsets.only(top: 5, left: 2),
                      child: Text(
                        _changeText(change),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: context.anchColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }
        if (children.isEmpty) {
          children.add(
            Padding(
              padding: EdgeInsets.symmetric(vertical: AnchSpacing.sm),
              child: Text(
                '暂无操作记录',
                style: TextStyle(
                  fontSize: 12,
                  color: context.anchColors.textMuted,
                ),
              ),
            ),
          );
        }
        return ItemDetailCollapsibleGroupCard(
          title: '操作记录',
          isExpanded: isExpanded,
          onToggle: onExpandedChanged,
          children: children,
        );
      },
    );
  }

  String _changeText(ItemEventChangeModel change) {
    return switch (change.changeKind) {
      ItemEventChangeKind.valueChanged =>
        '${change.subjectLabel}由「${change.oldValue}」修改为「${change.newValue}」',
      ItemEventChangeKind.fieldChanged => '${change.subjectLabel}已修改',
      ItemEventChangeKind.attachmentCountChanged => _attachmentChangeText(
        change,
      ),
    };
  }

  String _attachmentChangeText(ItemEventChangeModel change) {
    final removed = int.tryParse(change.oldValue ?? '') ?? 0;
    final added = int.tryParse(change.newValue ?? '') ?? 0;
    final parts = <String>[];
    if (added > 0) parts.add('添加 $added 个');
    if (removed > 0) parts.add('移除 $removed 个');
    return '${change.subjectLabel}${parts.join('，')}';
  }
}

class ItemDetailNoteSection extends StatelessWidget {
  const ItemDetailNoteSection({super.key, required this.item});

  final ItemWithFields item;

  @override
  Widget build(BuildContext context) {
    final note = item.note?.trim();
    if (note == null || note.isEmpty) return const SizedBox.shrink();
    return AnchFieldGroupCard(
      key: const Key('note_card'),
      title: '备注',
      children: [
        AnchInfoFieldRow(
          fieldId: 'note',
          label: '备注内容',
          value: note,
          valueDisplayMode: AnchValueDisplayMode.multiline,
        ),
      ],
    );
  }
}
