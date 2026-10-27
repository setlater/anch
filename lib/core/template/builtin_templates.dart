import 'category_definition.dart';
import 'field_definition.dart';
import 'field_priority.dart';
import 'field_value_type.dart';
import 'sensitive_level.dart';
import 'type_definition.dart';

/// 内置业务模板静态定义
class BuiltinTemplates {
  /// 所有资料大类的内置静态定义
  static const List<CategoryDefinition> categories = [
    CategoryDefinition(
      categoryKey: 'certificate',
      label: '证件资料',
      types: [
        'id_card',
        'household_book',
        'passport',
        'hk_macao_pass',
        'driver_license',
        'vehicle_license',
        'birth_certificate',
        'marriage_certificate',
      ],
    ),
    CategoryDefinition(
      categoryKey: 'card',
      label: '卡片资料',
      types: ['debit_card', 'credit_card'],
    ),
    CategoryDefinition(
      categoryKey: 'insurance',
      label: '保险资料',
      types: ['insurance'],
    ),
    CategoryDefinition(
      categoryKey: 'other',
      label: '其他资料',
      types: [
        'shipping_address',
        'property_certificate',
        'education_certificate',
        'generic',
      ],
    ),
  ];

  /// 内置子类型模板静态定义
  static const List<TypeDefinition> types = [
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'shipping_address',
      label: '收货地址',
      categoryKey: 'other',
      fields: [
        FieldDefinition(
          fieldKey: 'recipient_name',
          label: '收件人',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          required: true,
          searchable: true,
          summary: true,
        ),
        FieldDefinition(
          fieldKey: 'phone_number',
          label: '手机号码',
          valueType: FieldValueType.phone,
          sensitiveLevel: SensitiveLevel.medium,
          required: true,
        ),
        FieldDefinition(
          fieldKey: 'region',
          label: '所在地区',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          required: true,
          searchable: true,
          summary: true,
        ),
        FieldDefinition(
          fieldKey: 'detailed_address',
          label: '详细地址',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
        ),
      ],
    ),

    // 1. 储蓄卡
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'debit_card',
      label: '储蓄卡',
      categoryKey: 'card',
      defaultAttachmentRoles: ['front', 'back', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'bank_name',
          label: '银行名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
          searchable: true,
          summary: true,
        ),
        FieldDefinition(
          fieldKey: 'card_alias',
          label: '卡片别名',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'card_number',
          label: '卡号',
          valueType: FieldValueType.bankCardNumber,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'account_name',
          label: '户名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'branch_name',
          label: '开户行',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'account_type',
          label: '账户类型',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'usage',
          label: '卡片用途',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'is_closed',
          label: '是否已注销',
          valueType: FieldValueType.boolean,
          sensitiveLevel: SensitiveLevel.none, // 非敏感逻辑状态
          searchable: true,
        ),
      ],
    ),

    // 1. 储蓄卡 (v2 扩展版本)
    TypeDefinition(
      version: 2,
      usesCompactSummaryHeader: true,
      typeKey: 'debit_card',
      label: '储蓄卡',
      categoryKey: 'card',
      defaultAttachmentRoles: ['front', 'back', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'bank_name',
          label: '银行名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
          searchable: true,
          summary: true,
        ),
        FieldDefinition(
          fieldKey: 'card_alias',
          label: '卡片别名',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'card_number',
          label: '卡号',
          valueType: FieldValueType.bankCardNumber,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'account_name',
          label: '户名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'branch_name',
          label: '开户行',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'account_type',
          label: '账户类型',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'usage',
          label: '卡片用途',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'is_closed',
          label: '是否已注销',
          valueType: FieldValueType.boolean,
          sensitiveLevel: SensitiveLevel.none,
          searchable: true,
        ),
      ],
    ),

    // 2. 信用卡
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'credit_card',
      label: '信用卡',
      categoryKey: 'card',
      defaultAttachmentRoles: ['front', 'back', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'bank_name',
          label: '银行名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
          searchable: true,
          summary: true,
        ),
        FieldDefinition(
          fieldKey: 'card_alias',
          label: '卡片别名',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'card_number',
          label: '卡号',
          valueType: FieldValueType.bankCardNumber,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'account_name',
          label: '户名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'bill_day',
          label: '账单日',
          valueType: FieldValueType.dayOfMonth,
          sensitiveLevel: SensitiveLevel.none, // 仅存数字，非敏感
        ),
        FieldDefinition(
          fieldKey: 'repayment_day',
          label: '还款日',
          valueType: FieldValueType.dayOfMonth,
          sensitiveLevel: SensitiveLevel.none, // 仅存数字，非敏感
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'card_network',
          label: '卡组织',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 品牌/卡组织，非敏感
          priority: FieldPriority.p0,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'usage',
          label: '卡片用途',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'is_closed',
          label: '是否已注销',
          valueType: FieldValueType.boolean,
          sensitiveLevel: SensitiveLevel.none, // 非敏感逻辑状态
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'credit_limit',
          label: '额度',
          valueType: FieldValueType.decimal,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
        ),
        FieldDefinition(
          fieldKey: 'annual_fee_note',
          label: '年费说明',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
        ),
      ],
    ),

    // 3. 身份证
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'id_card',
      label: '身份证',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['front', 'back', 'portrait'],
      fields: [
        FieldDefinition(
          fieldKey: 'name',
          label: '姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'id_number',
          label: '身份证号',
          valueType: FieldValueType.idNumber,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'gender',
          label: '性别',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 公开的生理特征，非敏感
          required: true,
        ),
        FieldDefinition(
          fieldKey: 'ethnicity',
          label: '民族',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 公开的社会特征，非敏感
        ),
        FieldDefinition(
          fieldKey: 'birth_date',
          label: '出生日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'address',
          label: '地址',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_from',
          label: '有效期开始',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期结束',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'is_long_term',
          label: '是否长期有效',
          valueType: FieldValueType.boolean,
          sensitiveLevel: SensitiveLevel.none, // 非敏感逻辑状态
        ),
      ],
    ),

    // 4. 户口本
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'household_book',
      label: '户口本',
      categoryKey: 'certificate',
      defaultAttachmentRoles: [
        'cover',
        'home_page',
        'member_page',
        'change_page',
        'other',
      ],
      fields: [
        FieldDefinition(
          fieldKey: 'household_number',
          label: '户号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'household_type',
          label: '户别',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'household_head',
          label: '户主',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'household_address',
          label: '户籍地址',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '签发日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'page_owner',
          label: '页面成员',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
          searchable: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'relation_to_head',
          label: '与户主关系',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 仅存逻辑社会关系，非敏感
          priority: FieldPriority.p1,
        ),
        FieldDefinition(
          fieldKey: 'id_number',
          label: '身份证号',
          valueType: FieldValueType.idNumber,
          sensitiveLevel: SensitiveLevel.high,
          priority: FieldPriority.p1,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'former_name',
          label: '曾用名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'ethnicity',
          label: '民族',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 非敏感
          priority: FieldPriority.p1,
        ),
        FieldDefinition(
          fieldKey: 'native_place',
          label: '籍贯',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
        ),
        FieldDefinition(
          fieldKey: 'birth_place',
          label: '出生地',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
        ),
      ],
    ),

    // 5. 护照
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'passport',
      label: '护照',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['main_page', 'visa_page', 'other_page'],
      fields: [
        FieldDefinition(
          fieldKey: 'name_cn',
          label: '中文姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'name_en',
          label: '英文姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'passport_number',
          label: '护照号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'gender',
          label: '性别',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 非敏感
        ),
        FieldDefinition(
          fieldKey: 'birth_date',
          label: '出生日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'birth_place',
          label: '出生地',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_place',
          label: '签发地点',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '签发日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期至',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'nationality',
          label: '国籍',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 国家名称，非敏感
        ),
      ],
    ),

    // 6. 港澳通行证
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'hk_macao_pass',
      label: '港澳通行证',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['front', 'back', 'endorsement_page'],
      fields: [
        FieldDefinition(
          fieldKey: 'name',
          label: '姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'pass_number',
          label: '证件号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'gender',
          label: '性别',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 非敏感
        ),
        FieldDefinition(
          fieldKey: 'birth_date',
          label: '出生日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_place',
          label: '签发地点',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '签发日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期至',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'endorsement_note',
          label: '签注说明',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          priority: FieldPriority.p1,
        ),
      ],
    ),

    // 7. 驾驶证
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'driver_license',
      label: '驾驶证',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['front', 'back', 'secondary_page'],
      fields: [
        FieldDefinition(
          fieldKey: 'name',
          label: '姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'license_number',
          label: '驾驶证号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'gender',
          label: '性别',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 非敏感
        ),
        FieldDefinition(
          fieldKey: 'birth_date',
          label: '出生日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'address',
          label: '地址',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '初次领证日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_from',
          label: '有效期开始',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期至',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'vehicle_class',
          label: '准驾车型',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 准驾车型 (如 C1/C2)，非敏感
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'file_number',
          label: '档案编号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
      ],
    ),

    // 8. 行驶证
    TypeDefinition(
      isAvailableForCreation: false,
      usesCompactSummaryHeader: true,
      typeKey: 'vehicle_license',
      label: '行驶证',
      categoryKey: 'certificate',
      defaultAttachmentRoles: [
        'vehicle_license_front',
        'vehicle_license_back',
        'secondary_page',
      ],
      fields: [
        FieldDefinition(
          fieldKey: 'plate_number',
          label: '号牌号码',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          required: true,
          copyable: true,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'vehicle_type',
          label: '车辆类型',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 公共车型，非敏感
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'owner_name',
          label: '所有人',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'address',
          label: '地址',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'use_character',
          label: '使用性质',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 使用性质 (如 非营运)，非敏感
        ),
        FieldDefinition(
          fieldKey: 'model',
          label: '品牌型号',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.none, // 公共品牌，非敏感
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'vin',
          label: '车辆识别代号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'engine_number',
          label: '发动机号码',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'register_date',
          label: '注册日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '发证日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '发证机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'approved_passengers',
          label: '核定载人数',
          valueType: FieldValueType.number,
          sensitiveLevel: SensitiveLevel.none, // 载客数，非敏感
        ),
      ],
    ),

    // 9. 出生证明
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'birth_certificate',
      label: '出生证明',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['main', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'child_name',
          label: '新生儿姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'gender',
          label: '性别',
          valueType: FieldValueType.enumeration,
          sensitiveLevel: SensitiveLevel.none, // 非敏感
        ),
        FieldDefinition(
          fieldKey: 'birth_date',
          label: '出生日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'birth_time',
          label: '出生时间',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'birth_place',
          label: '出生地点',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'father_name',
          label: '父亲姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'mother_name',
          label: '母亲姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'certificate_number',
          label: '证件编号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '签发机构',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '签发日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
      ],
    ),

    // 10. 结婚证
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'marriage_certificate',
      label: '结婚证',
      categoryKey: 'certificate',
      defaultAttachmentRoles: ['main', 'holder_page', 'spouse_page', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'holder_name',
          label: '持证人姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'spouse_name',
          label: '配偶姓名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'certificate_number',
          label: '证件编号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'register_date',
          label: '登记日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'issuing_authority',
          label: '登记机关',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
      ],
    ),

    // 11. 保险通用模板
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'insurance',
      label: '保险资料',
      categoryKey: 'insurance',
      defaultAttachmentRoles: ['policy_pdf', 'invoice', 'claim_doc', 'other'],
      defaultReminderTypes: ['insurance_expiry', 'insurance_payment_day'],
      fields: [
        FieldDefinition(
          fieldKey: 'insurance_company',
          label: '保险公司',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'policy_name',
          label: '保单名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'policy_number',
          label: '保单号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          required: true,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'insurance_type',
          label: '保险类型',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'applicant',
          label: '投保人',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'insured_person',
          label: '保障对象',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'start_date',
          label: '起保日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'end_date',
          label: '到期日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
          reminderSource: true,
        ),
        FieldDefinition(
          fieldKey: 'premium',
          label: '保费',
          valueType: FieldValueType.decimal,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'coverage_amount',
          label: '保额',
          valueType: FieldValueType.decimal,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'service_phone',
          label: '客服电话',
          valueType: FieldValueType.phone,
          sensitiveLevel: SensitiveLevel.none, // 官方客服公开电话，非敏感
          copyable: true,
          searchable: true,
        ),
      ],
    ),

    // 13. 通用资料
    TypeDefinition(
      usesCompactSummaryHeader: true,
      supportsLegacyEditing: true,
      typeKey: 'generic',
      label: '其他资料',
      categoryKey: 'other',
      defaultAttachmentRoles: ['main', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'title',
          label: '资料名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          required: true,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'owner_name',
          label: '所属人/户名',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.medium,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'identifier',
          label: '编号/账号',
          valueType: FieldValueType.sensitiveText,
          sensitiveLevel: SensitiveLevel.high,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'issuer',
          label: '签发/办理机构',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'valid_until',
          label: '有效期至',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
      ],
    ),

    // 13. 通用资料（v2：保留前三组字段契约，录入层可按同一规则动态扩展）
    TypeDefinition(
      version: 2,
      usesCompactSummaryHeader: true,
      typeKey: 'generic',
      label: '其他资料',
      categoryKey: 'other',
      defaultAttachmentRoles: ['main', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'title',
          label: '资料名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          required: true,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_label_1',
          label: '字段名 1',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_value_1',
          label: '字段值 1',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_label_2',
          label: '字段名 2',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_value_2',
          label: '字段值 2',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_label_3',
          label: '字段名 3',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'custom_field_value_3',
          label: '字段值 3',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          copyable: true,
        ),
      ],
    ),

    // 14. 不动产权证
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'property_certificate',
      label: '不动产权证',
      categoryKey: 'other',
      defaultAttachmentRoles: ['main', 'page_info', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'owner_name',
          label: '权利人',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'ownership_status',
          label: '共有情况',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'certificate_number',
          label: '不动产权证号',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          required: true,
          copyable: true,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'registration_date',
          label: '登记日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'registration_authority',
          label: '登记机构',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'property_location',
          label: '坐落',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'property_usage',
          label: '用途',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'building_area',
          label: '建筑面积',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'land_area',
          label: '土地面积',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
      ],
    ),

    // 15. 学历/学位证书
    TypeDefinition(
      usesCompactSummaryHeader: true,
      typeKey: 'education_certificate',
      label: '学历/学位证书',
      categoryKey: 'other',
      defaultAttachmentRoles: ['front', 'back', 'other'],
      fields: [
        FieldDefinition(
          fieldKey: 'certificate_type',
          label: '证书类型',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'certificate_number',
          label: '证书编号',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          required: true,
          copyable: true,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'issue_date',
          label: '发证日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'school_name',
          label: '学校名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'major_name',
          label: '专业名称',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'degree_level',
          label: '学历 / 学位',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.low,
        ),
        FieldDefinition(
          fieldKey: 'holder_name',
          label: '姓名',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.medium,
          searchable: true,
        ),
        FieldDefinition(
          fieldKey: 'enrollment_date',
          label: '入学日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
        FieldDefinition(
          fieldKey: 'graduation_date',
          label: '毕业日期',
          valueType: FieldValueType.date,
          sensitiveLevel: SensitiveLevel.medium,
        ),
      ],
    ),
  ];
}
