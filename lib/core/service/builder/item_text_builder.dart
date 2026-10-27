// This layer must NOT contain UI logic or widget dependencies.
// Only string/data transformation is allowed.

import '../../template/field_definition.dart';
import '../../template/field_value_type.dart';
import '../../template/type_definition.dart';
import '../models/item_draft_input.dart';
import '../../security/field_render_policy.dart';
import '../../repository/models/item_child_entry_model.dart';
import '../../repository/models/item_with_fields.dart';

/// 敏感字段安全加工处理器（SensitiveFieldGuard）
class SensitiveFieldGuard {
  /// 高敏字段的脱敏标识关键字名单
  static const List<String> highSensitiveKeys = [
    'card_number',
    'id_number',
    'reserved_phone',
    'vin',
    'engine_number',
    'passport_number',
    'pass_number',
    'driver_license_number',
    'license_number',
    'household_number',
    'file_number',
  ];

  /// 根据字段敏感级别，对高敏数据加工生成低敏的 normalizedValue（标准化值）
  /// - High 敏字段：明文长度 >= 4 时取最后 4 位；若长度 < 4，强制返回 null 彻底防泄露。
  /// - 非 High 敏字段：不需要 normalizedValue，返回 null。
  static String? normalizeSensitiveField({
    required String fieldKey,
    required String? valueText,
    required SensitiveLevel level,
  }) {
    if (!FieldRenderPolicy.shouldMaskField(level) || valueText == null) {
      return null;
    }

    final trimmed = valueText.trim();
    if (trimmed.length >= 4) {
      return trimmed.substring(trimmed.length - 4);
    }

    // 长度小于 4 时，强制设为 null，绝不保留完整高敏值，防止泄露
    return null;
  }
}

/// 列表展示文本拼装器（TitleSummaryBuilder）
class TitleSummaryBuilder {
  static String buildDetailTitle({
    required ItemWithFields item,
    required String typeLabel,
    required String ownerName,
  }) {
    if (item.typeKey == 'debit_card') {
      String? cardAlias;
      String? bankName;
      String? cardNumber;
      for (final f in item.fields) {
        if (f.fieldKey == 'card_alias' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          cardAlias = f.valueText;
        }
        if (f.fieldKey == 'bank_name' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          bankName = f.valueText;
        }
        if (f.fieldKey == 'card_number' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          cardNumber = f.valueText!.trim();
        }
      }
      String? last4;
      if (cardNumber != null && cardNumber.length >= 4) {
        last4 = cardNumber.substring(cardNumber.length - 4);
      }
      if (cardAlias != null && last4 != null) {
        return '$cardAlias（$last4）';
      } else if (cardAlias != null) {
        return cardAlias;
      } else if (bankName != null && last4 != null) {
        return '$bankName（$last4）';
      } else if (bankName != null) {
        return '$bankName储蓄卡';
      } else if (last4 != null) {
        return '储蓄卡（$last4）';
      } else {
        return '储蓄卡';
      }
    }

    if (item.title != null && item.title!.trim().isNotEmpty) {
      return item.title!;
    }
    return '${ownerName == '我' ? '我' : ownerName}的$typeLabel';
  }

  /// 标识性字段白名单，用于自动生成资料标题
  static const List<String> identifierFieldKeys = [
    'name',
    'holder_name',
    'child_name',
    'owner_name',
    'bank_name',
    'plate_number',
    'name_cn',
  ];

  static String? _fieldValue(ItemDraftInput draft, String fieldKey) {
    for (final field in draft.fields) {
      if (field.fieldKey != fieldKey) continue;
      final value = field.valueText?.trim();
      return value == null || value.isEmpty ? null : value;
    }
    return null;
  }

  static String? _lastFieldValue(ItemDraftInput draft, String fieldKey) {
    String? value;
    for (final field in draft.fields) {
      if (field.fieldKey != fieldKey) continue;
      final candidate = field.valueText?.trim();
      if (candidate != null && candidate.isNotEmpty) {
        value = candidate;
      }
    }
    return value;
  }

  /// 生成资料标题
  /// 1. 若草稿中提供了标题，直接使用
  /// 2. 若无标题，从关键标识字段提取有值的内容拼接为：`[值]的[模板Label]`
  /// 3. 若均无，采用从 Service 传入的成员名称：`[成员名称]的[模板Label]`
  /// 4. 最终兜底：`家庭的[模板Label]`
  static String buildTitle({
    required ItemDraftInput draft,
    required TypeDefinition? typeDef,
    required String? memberName,
  }) {
    if (draft.title != null && draft.title!.trim().isNotEmpty) {
      return draft.title!.trim();
    }

    if (typeDef == null) {
      if (memberName != null && memberName.trim().isNotEmpty) {
        return '${memberName.trim()}的资料';
      }
      return '未命名资料';
    }

    // 身份证、储蓄卡、信用卡的定制规则
    final typeKey = typeDef.typeKey;
    if (typeKey == 'id_card') {
      final nameInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'name'),
      );
      final nameVal = nameInput.valueText?.trim();
      if (nameVal != null && nameVal.isNotEmpty) {
        return '$nameVal的身份证';
      }
      if (memberName != null &&
          memberName.trim().isNotEmpty &&
          memberName.trim() != '家庭') {
        return '${memberName.trim()}的身份证';
      }
      return '身份证资料';
    } else if (typeKey == 'debit_card') {
      final aliasInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'card_alias',
        orElse: () => ItemFieldDraftInput(fieldKey: 'card_alias'),
      );
      final aliasVal = aliasInput.valueText?.trim();
      if (aliasVal != null && aliasVal.isNotEmpty) {
        return aliasVal;
      }

      final bankInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'bank_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'bank_name'),
      );
      final bankVal = bankInput.valueText?.trim();
      if (bankVal != null && bankVal.isNotEmpty) {
        return '$bankVal储蓄卡';
      }

      final numberInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'card_number',
        orElse: () => ItemFieldDraftInput(fieldKey: 'card_number'),
      );
      final numberVal = numberInput.valueText?.trim();
      if (numberVal != null && numberVal.length >= 4) {
        final last4 = numberVal.substring(numberVal.length - 4);
        return '尾号 $last4 储蓄卡';
      }

      return '储蓄卡';
    } else if (typeKey == 'credit_card') {
      final aliasInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'card_alias',
        orElse: () => ItemFieldDraftInput(fieldKey: 'card_alias'),
      );
      final aliasVal = aliasInput.valueText?.trim();

      final bankInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'bank_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'bank_name'),
      );
      final bankVal = bankInput.valueText?.trim();

      final numberInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'card_number',
        orElse: () => ItemFieldDraftInput(fieldKey: 'card_number'),
      );
      final numberVal = numberInput.valueText?.trim();
      String? last4;
      if (numberVal != null && numberVal.length >= 4) {
        last4 = numberVal.substring(numberVal.length - 4);
      }

      if (aliasVal != null && aliasVal.isNotEmpty && last4 != null) {
        return '$aliasVal（$last4）';
      } else if (aliasVal != null && aliasVal.isNotEmpty) {
        return aliasVal;
      } else if (bankVal != null && bankVal.isNotEmpty && last4 != null) {
        return '$bankVal（$last4）';
      } else if (bankVal != null && bankVal.isNotEmpty) {
        return '$bankVal信用卡';
      } else if (last4 != null) {
        return '信用卡（$last4）';
      }
      return '信用卡';
    } else if (typeKey == 'insurance') {
      final nameInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'policy_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'policy_name'),
      );
      final nameVal = nameInput.valueText?.trim();
      if (nameVal != null && nameVal.isNotEmpty) {
        return nameVal;
      }

      final companyInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'insurance_company',
        orElse: () => ItemFieldDraftInput(fieldKey: 'insurance_company'),
      );
      final companyVal = companyInput.valueText?.trim();
      if (companyVal != null && companyVal.isNotEmpty) {
        return '$companyVal保险资料';
      }

      return '保险资料';
    } else if (typeKey == 'shipping_address') {
      final recipient = _fieldValue(draft, 'recipient_name');
      if (recipient != null) return '$recipient的收货地址';
      return '收货地址';
    } else if (typeKey == 'property_certificate') {
      final locationInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'property_location',
        orElse: () => ItemFieldDraftInput(fieldKey: 'property_location'),
      );
      final locationVal = locationInput.valueText?.trim();
      if (locationVal != null && locationVal.isNotEmpty) {
        return locationVal;
      }

      final ownerInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'owner_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'owner_name'),
      );
      final ownerVal = ownerInput.valueText?.trim();
      if (ownerVal != null && ownerVal.isNotEmpty) {
        return '$ownerVal的不动产权证';
      }

      return '不动产权证';
    } else if (typeKey == 'education_certificate') {
      final schoolInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'school_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'school_name'),
      );
      final schoolVal = schoolInput.valueText?.trim();

      final certTypeInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'certificate_type',
        orElse: () => ItemFieldDraftInput(fieldKey: 'certificate_type'),
      );
      final certTypeVal = certTypeInput.valueText?.trim();

      if (schoolVal != null && schoolVal.isNotEmpty) {
        final typeStr = (certTypeVal != null && certTypeVal.isNotEmpty)
            ? certTypeVal
            : '';
        return '$schoolVal$typeStr';
      }

      final holderInput = draft.fields.firstWhere(
        (f) => f.fieldKey == 'holder_name',
        orElse: () => ItemFieldDraftInput(fieldKey: 'holder_name'),
      );
      final holderVal = holderInput.valueText?.trim();
      if (holderVal != null && holderVal.isNotEmpty) {
        return '$holderVal的学历/学位证书';
      }

      return '学历/学位证书';
    } else if (typeKey == 'generic') {
      final titleVal = _fieldValue(draft, 'title');
      if (titleVal != null && titleVal.isNotEmpty) {
        return titleVal;
      }
      return '其他资料';
    }

    // 尝试寻找标识字段
    for (final key in identifierFieldKeys) {
      // 1. 查找当前模板中对应的 FieldDefinition
      final fieldDef = typeDef.fields.firstWhere(
        (f) => f.fieldKey == key,
        orElse: () => const FieldDefinition(
          fieldKey: '',
          label: '',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.forbidden,
        ),
      );

      // 2. 如果当前模板中不存在该字段，或者其敏感等级是 high/forbidden，或者为隐藏字段，直接跳过
      if (fieldDef.fieldKey.isEmpty ||
          !FieldRenderPolicy.isFieldAllowed(
            fieldDef.fieldKey,
            fieldDef.sensitiveLevel,
          ) ||
          FieldRenderPolicy.shouldMaskField(fieldDef.sensitiveLevel)) {
        continue;
      }

      final inputField = draft.fields.firstWhere(
        (f) => f.fieldKey == key,
        orElse: () => ItemFieldDraftInput(fieldKey: key),
      );
      final value = inputField.valueText;
      if (value != null && value.trim().isNotEmpty) {
        return '${value.trim()}的${typeDef.label}';
      }
    }

    // 无法从字段提取，利用传入的成员名字
    if (memberName != null && memberName.trim().isNotEmpty) {
      return '${memberName.trim()}的${typeDef.label}';
    }

    // 终极兜底
    return '家庭的${typeDef.label}';
  }

  static String buildPrimaryText({
    required ItemDraftInput draft,
    required TypeDefinition? typeDef,
    required String title,
  }) {
    if (typeDef?.typeKey == 'debit_card') {
      String? bankName;
      String? tailNumber;
      String? usage;
      bool isClosed = false;

      for (final f in draft.fields) {
        if (f.fieldKey == 'bank_name' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          bankName = f.valueText;
        }
        if (f.fieldKey == 'card_number' && f.valueText != null) {
          final val = f.valueText!.trim();
          if (val.length >= 4) {
            tailNumber = '尾号 ${val.substring(val.length - 4)}';
          }
        }
        if (f.fieldKey == 'usage' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          usage = f.valueText;
        }
        if (f.fieldKey == 'is_closed') {
          isClosed = f.valueText == 'true' || f.valueText == '1';
        }
      }

      final parts = <String>[
        ?bankName,
        ?tailNumber,
        ?usage,
        if (isClosed) '已注销',
      ];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef?.typeKey == 'credit_card') {
      String? bankName;
      String? cardNetwork;
      bool isClosed = false;

      for (final f in draft.fields) {
        if (f.fieldKey == 'bank_name' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          bankName = f.valueText;
        }
        if (f.fieldKey == 'card_network' &&
            f.valueText != null &&
            f.valueText!.isNotEmpty) {
          cardNetwork = f.valueText;
        }
        if (f.fieldKey == 'is_closed') {
          isClosed = f.valueText == 'true' || f.valueText == '1';
        }
      }

      final parts = <String>[?bankName, ?cardNetwork, if (isClosed) '已注销'];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef?.typeKey == 'insurance') {
      String? insuranceType;
      String? insuredPerson;
      String? endDate;

      for (final f in draft.fields) {
        if (f.fieldKey == 'insurance_type' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          insuranceType = f.valueText!.trim();
        }
        if (f.fieldKey == 'insured_person' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          insuredPerson = f.valueText!.trim();
        }
        if (f.fieldKey == 'end_date' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          endDate = f.valueText!.trim();
        }
      }

      final parts = <String>[
        if (insuranceType != null && insuranceType.isNotEmpty) insuranceType,
        if (insuredPerson != null && insuredPerson.isNotEmpty) insuredPerson,
        if (endDate != null && endDate.isNotEmpty) endDate,
      ];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef?.typeKey == 'property_certificate') {
      String? ownerName;
      String? certNumber;
      String? buildingArea;

      for (final f in draft.fields) {
        if (f.fieldKey == 'owner_name' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          ownerName = f.valueText!.trim();
        }
        if (f.fieldKey == 'certificate_number' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          certNumber = f.valueText!.trim();
        }
        if (f.fieldKey == 'building_area' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          buildingArea = f.valueText!.trim();
        }
      }

      final parts = <String>[?ownerName, ?certNumber, ?buildingArea];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef?.typeKey == 'education_certificate') {
      String? holderName;
      String? majorName;
      String? degreeLevel;
      String? graduationDate;

      for (final f in draft.fields) {
        if (f.fieldKey == 'holder_name' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          holderName = f.valueText!.trim();
        }
        if (f.fieldKey == 'major_name' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          majorName = f.valueText!.trim();
        }
        if (f.fieldKey == 'degree_level' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          degreeLevel = f.valueText!.trim();
        }
        if (f.fieldKey == 'graduation_date' &&
            f.valueText != null &&
            f.valueText!.trim().isNotEmpty) {
          graduationDate = f.valueText!.trim();
        }
      }

      final parts = <String>[
        ?holderName,
        ?majorName,
        ?degreeLevel,
        ?graduationDate,
      ];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef?.typeKey == 'generic') {
      final parts = <String>[
        ?_lastFieldValue(draft, 'owner_name'),
        ?_lastFieldValue(draft, 'identifier'),
        ?_lastFieldValue(draft, 'valid_until'),
      ];
      return parts.isEmpty ? title : parts.join(' · ');
    }

    if (typeDef == null) {
      return title;
    }
    for (final fieldDef in typeDef.fields) {
      if (fieldDef.summary &&
          FieldRenderPolicy.isFieldAllowed(
            fieldDef.fieldKey,
            fieldDef.sensitiveLevel,
          ) &&
          !FieldRenderPolicy.shouldMaskField(fieldDef.sensitiveLevel)) {
        final input = draft.fields.firstWhere(
          (f) => f.fieldKey == fieldDef.fieldKey,
          orElse: () => ItemFieldDraftInput(fieldKey: fieldDef.fieldKey),
        );
        if (input.valueText != null && input.valueText!.trim().isNotEmpty) {
          return input.valueText!.trim();
        }
      }
    }
    return title;
  }

  /// 提取副列表展示文本
  /// 获取第二个 `summary: true` 且敏感度非高/禁的字段值。
  static String? buildSecondaryText({
    required ItemDraftInput draft,
    required TypeDefinition? typeDef,
    required String? primaryVal,
  }) {
    if (typeDef?.typeKey == 'debit_card' ||
        typeDef?.typeKey == 'credit_card' ||
        typeDef?.typeKey == 'insurance' ||
        typeDef?.typeKey == 'property_certificate' ||
        typeDef?.typeKey == 'education_certificate' ||
        typeDef?.typeKey == 'generic') {
      return null;
    }
    if (typeDef == null) {
      return null;
    }
    for (final fieldDef in typeDef.fields) {
      if (fieldDef.summary &&
          FieldRenderPolicy.isFieldAllowed(
            fieldDef.fieldKey,
            fieldDef.sensitiveLevel,
          ) &&
          !FieldRenderPolicy.shouldMaskField(fieldDef.sensitiveLevel)) {
        final input = draft.fields.firstWhere(
          (f) => f.fieldKey == fieldDef.fieldKey,
          orElse: () => ItemFieldDraftInput(fieldKey: fieldDef.fieldKey),
        );
        final val = input.valueText?.trim();
        if (val != null && val.isNotEmpty && val != primaryVal) {
          return val;
        }
      }
    }
    return null;
  }

  /// 构建摘要说明文本 (Label: 字段值 | Label: 字段值)
  static String? buildSummaryText({
    required ItemDraftInput draft,
    required TypeDefinition? typeDef,
    List<SaveItemChildEntryInput>? childEntries,
  }) {
    if (typeDef == null) {
      return null;
    }
    if (typeDef.typeKey == 'generic') {
      return '';
    }
    final parts = <String>[];
    for (final fieldDef in typeDef.fields) {
      if (fieldDef.summary &&
          FieldRenderPolicy.isFieldAllowed(
            fieldDef.fieldKey,
            fieldDef.sensitiveLevel,
          ) &&
          !FieldRenderPolicy.shouldMaskField(fieldDef.sensitiveLevel)) {
        final input = draft.fields.firstWhere(
          (f) => f.fieldKey == fieldDef.fieldKey,
          orElse: () => ItemFieldDraftInput(fieldKey: fieldDef.fieldKey),
        );
        final val = input.valueText?.trim();
        if (val != null && val.isNotEmpty) {
          parts.add('${fieldDef.label}: $val');
        }
      }
    }
    if (childEntries != null && childEntries.isNotEmpty) {
      parts.add('已记录 ${childEntries.length} 位成员');
    }
    return parts.isEmpty ? null : parts.join(' | ');
  }
}

/// 模糊搜索文本拼装器（SearchTextBuilder）
class SearchTextBuilder {
  /// 判断字段键名是否属于标识符类（如身份证号、护照号、保单号、车架号、发动机号、证件号类等）
  static bool isIdentifierLikeField(String fieldKey) {
    final key = fieldKey.toLowerCase();
    final identifierKeys = [
      'id_number',
      'identity_card_number',
      'identity_number',
      'passport',
      'passport_number',
      'policy_number',
      'policy_no',
      'vin',
      'car_frame_number',
      'engine_number',
      'engine_no',
      'license_number',
      'driver_license_number',
      'pass_number',
      'certificate_number',
      'household_number',
      'file_number',
      'identifier',
    ];
    return identifierKeys.any((k) => key.contains(k));
  }

  /// 收紧的低敏搜索词拼接规则：
  /// - 包含：title、模板 label、分类 label。
  /// - 针对 forbidden 级别字段：完整值、normalizedValue、尾号均不进入 searchText，绝无例外。
  /// - 针对 high 级别字段：默认排除。唯一例外是 bank_card_number / card_number，它们只允许拼入4位低敏尾号。
  /// - 针对 medium 级别字段：必须满足 searchable=true 且不是 identifier-like 字段（排除身份证号、护照号、保单号、车架号、发动机号、证件号类），才允许拼入完整值。
  /// - 针对 low/none 级别字段：满足 searchable=true 即可拼入完整值。
  static String buildSearchText({
    required String title,
    required TypeDefinition? typeDef,
    required String categoryLabel,
    required List<ItemFieldDraftInput> fields,
    required Map<String, String?> normalizedValues,
    List<SaveItemChildEntryInput>? childEntries,
  }) {
    final searchTokens = <String>{};

    // 基础关键字
    searchTokens.add(title.trim());
    if (typeDef != null) {
      searchTokens.add(typeDef.label.trim());
    }
    searchTokens.add(categoryLabel.trim());

    if (typeDef == null) {
      // 拼接所有字段的值 (安全兜底)
      for (final f in fields) {
        final val = f.valueText?.trim();
        if (val == null || val.isEmpty) continue;

        final key = f.fieldKey.toLowerCase();
        if (key == 'card_number' || key == 'bank_card_number') {
          if (val.length >= 4) {
            searchTokens.add(val.substring(val.length - 4));
          }
          continue;
        }
        if (SensitiveFieldGuard.highSensitiveKeys.contains(key) ||
            isIdentifierLikeField(key)) {
          continue;
        }
        searchTokens.add(val);
      }
      // 拼接所有子表项的姓名 (只允许拼接特定 childType 且特定 key 的低敏字段)
      if (childEntries != null) {
        for (final entry in childEntries) {
          if (entry.childType == 'household_member') {
            for (final field in entry.fields) {
              if (field.fieldKey == 'member_name') {
                final val = field.valueText?.trim();
                if (val != null && val.isNotEmpty) {
                  searchTokens.add(val);
                }
              }
            }
          }
        }
      }
      return searchTokens.join(' ');
    }

    // 字段关键字
    for (final fieldDef in typeDef.fields) {
      final input = fields.firstWhere(
        (f) => f.fieldKey == fieldDef.fieldKey,
        orElse: () => ItemFieldDraftInput(fieldKey: fieldDef.fieldKey),
      );
      final valueText = input.valueText?.trim();

      if (valueText == null || valueText.isEmpty) {
        continue;
      }

      if (!FieldRenderPolicy.isFieldAllowed(
        fieldDef.fieldKey,
        fieldDef.sensitiveLevel,
      )) {
        continue;
      }

      final level = fieldDef.sensitiveLevel;

      if (level == SensitiveLevel.forbidden) {
        // forbidden 字段必须绝对排除
        continue;
      }

      if (level == SensitiveLevel.high) {
        // high 字段默认排除；唯一例外是 bank_card_number / card_number 只允许写入 4 位低敏尾号
        final isBankCard =
            fieldDef.fieldKey == 'card_number' ||
            fieldDef.fieldKey == 'bank_card_number' ||
            fieldDef.valueType == FieldValueType.bankCardNumber;
        if (isBankCard) {
          final normalized = normalizedValues[fieldDef.fieldKey];
          if (normalized != null && normalized.isNotEmpty) {
            searchTokens.add(normalized);
          }
        }
        continue;
      }

      if (level == SensitiveLevel.medium) {
        // medium 字段只有在模板明确 searchable=true 且不是 identifier-like 字段时，才允许进入 searchText
        if (fieldDef.searchable && !isIdentifierLikeField(fieldDef.fieldKey)) {
          searchTokens.add(valueText);
        }
        continue;
      }

      // low / none 字段：searchable=true 即可正常进入
      if (fieldDef.searchable) {
        searchTokens.add(valueText);
      }
    }

    // 拼接所有子表项的姓名 (只允许拼接特定 childType 且特定 key 的低敏字段)
    if (childEntries != null) {
      for (final entry in childEntries) {
        if (entry.childType == 'household_member') {
          for (final field in entry.fields) {
            if (field.fieldKey == 'member_name') {
              final val = field.valueText?.trim();
              if (val != null && val.isNotEmpty) {
                searchTokens.add(val);
              }
            }
          }
        }
      }
    }

    return searchTokens.join(' ');
  }
}
