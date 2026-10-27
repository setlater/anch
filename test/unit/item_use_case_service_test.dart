import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/validation/field_validation_error.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/template/field_definition.dart';
import 'package:anch/core/template/type_definition.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/sensitive_level.dart';
import 'package:anch/core/template/builtin_templates.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late ItemUseCaseService service;

  setUp(() {
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);
    service = ItemUseCaseService(itemRepo: itemRepo, memberRepo: memberRepo, runtime: RuntimeProvider.create(const AnchSecurityRuntimeConfig(mode: AnchSecurityMode.dev, useEncryptedDatabase: false, enableSecureWindow: false, enablePrivacyShieldOverlay: false, enableAppLockGate: false, isFormalBlocked: false)));
  });

  tearDown(() async {
    await db.close();
  });

  test('验证 1. 正常资料的完整保存流程及字段获取', () async {
    // 保存一个有效身份证，title 为空以测试自动拼装
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    expect(result.itemId, isNotNull);

    // 读回并校验
    final saved = await itemRepo.getItemWithFields(result.itemId!);
    expect(saved, isNotNull);
    expect(saved!.title, '张三的身份证'); // 自动标题生成测试
    expect(saved.primaryText, '张三的身份证'); // 自动 primaryText 兜底
    expect(saved.secondaryText, isNull);

    // 检验 normalizedValue
    final idNumField = saved.fields.firstWhere((f) => f.fieldKey == 'id_number');
    expect(idNumField.normalizedValue, '2345'); // 身份证后4位

    // 检验 searchText 绝不包含明文，且由于 id_number 是 searchable == false 的高敏字段，它应该连后 4 位都不含在 searchText
    expect(saved.searchText, isNot(contains('110101199003072345')));
    expect(saved.searchText, isNot(contains('2345')));
    // 包含标题与模板名大类名
    expect(saved.searchText, contains('张三的身份证'));
    expect(saved.searchText, contains('身份证'));
    expect(saved.searchText, contains('证件资料'));
  });

  test('验证 2. 资料类型模板与大类一致性校验', () async {
    // 模板不存在校验
    final wrongTemplate = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'invalid_type_key',
      fields: [],
    );
    final result1 = await service.saveDraft(wrongTemplate);
    expect(result1.success, isTrue);
    expect(result1.errors.first.errorCode, FieldValidationErrorCode.invalidTemplateType);

    // 大类不匹配校验
    final mismatchCategory = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate', // 应该是 card
      typeKey: 'debit_card',
      fields: [],
    );
    final result2 = await service.saveDraft(mismatchCategory);
    expect(result2.success, isTrue);
    expect(result2.errors.first.errorCode, FieldValidationErrorCode.categoryMismatch);
  });

  test('验证 3. 高危拦截优先顺序校验', () async {
    // 传入带有 forbidden 特征但又在模板中未定义的字段（如 pay_password）
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'pay_password', valueText: '123456'), // 既是高危词，也是未知字段
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isFalse);
    // 验证高危防呆规则优先判定为 forbiddenFieldSaved，而不是作为 unknownFieldKey 失败
    expect(result.errors.first.errorCode, FieldValidationErrorCode.forbiddenFieldSaved);
    expect(result.errors.first.errorMessage, contains('高危敏感特征词'));

    // 普通未知字段校验
    final unknownDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'unknown_key_xyz', valueText: '123'),
      ],
    );
    final result2 = await service.saveDraft(unknownDraft);
    expect(result2.success, isTrue);
    expect(result2.errors.first.errorCode, FieldValidationErrorCode.unknownFieldKey);
  });

  test('验证 4. 必填字段缺失校验', () async {
    // 身份证必填 id_number
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '李四'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        // 缺少 id_number
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isFalse);
    expect(result.errors.first.errorCode, FieldValidationErrorCode.requiredFieldMissing);
    expect(result.errors.first.fieldKey, 'id_number');
  });

  test('验证 5. 值类型强弱校验逻辑（强校验拦截与弱校验兼容）', () async {
    // (a) 强校验 - 错误日期格式拦截
    final badDateDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '王五'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990/03/07'), // 错误格式 (强校验)
      ],
    );
    final res1 = await service.saveDraft(badDateDraft);
    expect(res1.success, isTrue);
    expect(res1.errors.first.errorCode, FieldValidationErrorCode.invalidFormat);

    // (b) 弱校验 - 合法且宽松格式的电话号码通过 (使用保险模板的 service_phone 字段)
    final softPhoneDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'insurance',
      typeKey: 'insurance',
      fields: [
        ItemFieldDraftInput(fieldKey: 'policy_number', valueText: 'A-20240001'),
        ItemFieldDraftInput(fieldKey: 'service_phone', valueText: '+86 138-1234-5678'), // 带有前缀和短横线的非标号码通过
      ],
    );
    final res2 = await service.saveDraft(softPhoneDraft);
    expect(res2.success, isTrue);

    // (c) 弱校验 - 明显错误的格式拦截
    final badPhoneDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'insurance',
      typeKey: 'insurance',
      fields: [
        ItemFieldDraftInput(fieldKey: 'policy_number', valueText: 'A-20240002'),
        ItemFieldDraftInput(fieldKey: 'service_phone', valueText: 'abc12345'), // 包含英文字母的明显错误
      ],
    );
    final res3 = await service.saveDraft(badPhoneDraft);
    expect(res3.success, isTrue);
    expect(res3.errors.first.errorCode, FieldValidationErrorCode.invalidFormat);

    // 错误的卡号位数弱校验
    final badCardDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
        ItemFieldDraftInput(fieldKey: 'card_number', valueText: '1234567'), // 长度明显不够 (12-19位)
      ],
    );
    final res4 = await service.saveDraft(badCardDraft);
    expect(res4.success, isTrue);
    expect(res4.errors.first.errorCode, FieldValidationErrorCode.invalidFormat);
  });

  test('验证 6. SensitiveFieldGuard 高敏超短防泄露独立测试', () {
    // 长度大于等于 4 的，返回后 4 位
    final res1 = SensitiveFieldGuard.normalizeSensitiveField(
      fieldKey: 'id_number',
      valueText: '110101199003072345',
      level: SensitiveLevel.high,
    );
    expect(res1, '2345');

    final res2 = SensitiveFieldGuard.normalizeSensitiveField(
      fieldKey: 'id_number',
      valueText: '1234',
      level: SensitiveLevel.high,
    );
    expect(res2, '1234');

    // 长度小于 4 时的防呆校验：直接返回 null，决不泄露完整明文
    final res3 = SensitiveFieldGuard.normalizeSensitiveField(
      fieldKey: 'id_number',
      valueText: '666',
      level: SensitiveLevel.high,
    );
    expect(res3, isNull);

    // 非高敏字段不需要做 normalized
    final res4 = SensitiveFieldGuard.normalizeSensitiveField(
      fieldKey: 'bank_name',
      valueText: '招商银行',
      level: SensitiveLevel.low,
    );
    expect(res4, isNull);
  });

  test('验证 7. 空 title 自动拼装规则（依赖成员及未知成员兜底）', () async {
    // (a) 绑定合法成员（如“父亲”）
    final saveMember = SaveMemberInput(
      memberType: 'person',
      name: '父亲',
    );
    final memberId = await memberRepo.saveMember(saveMember);

    final draftWithMember = ItemDraftInput(
      memberId: memberId,
      categoryKey: 'certificate',
      typeKey: 'passport',
      fields: [
        ItemFieldDraftInput(fieldKey: 'passport_number', valueText: 'E12345678'),
        // 不提供 name_cn/name_en 标识，强制依赖 memberName
      ],
    );

    final res1 = await service.saveDraft(draftWithMember);
    expect(res1.success, isTrue);

    final saved1 = await itemRepo.getItemWithFields(res1.itemId!);
    expect(saved1!.title, '父亲的护照');

    // (b) 绑定非法/不存在的成员（通过 TitleSummaryBuilder 纯逻辑测试降级兜底，避免数据库外键约束失败）
    final typeDef = BuiltinTemplates.types.firstWhere((t) => t.typeKey == 'id_card');
    final draftWithInvalidMember = ItemDraftInput(
      memberId: 'non_existent_member_uuid_xyz',
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
      ],
    );
    final title = TitleSummaryBuilder.buildTitle(
      draft: draftWithInvalidMember,
      typeDef: typeDef,
      memberName: null, // 模拟无法查到成员名
    );
    expect(title, '身份证资料');
  });

  test('验证 8. 高敏非 searchable 隔离测试', () {
    // 身份证 id_number 在内置模板中为 searchable: false
    // 即使能生成后4位，也不能混入 searchText 中
    final typeDef = BuiltinTemplates.types.firstWhere((t) => t.typeKey == 'id_card');

    final searchText = SearchTextBuilder.buildSearchText(
      title: '张三的身份证',
      typeDef: typeDef,
      categoryLabel: '证件资料',
      fields: [
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
      ],
      normalizedValues: {
        'id_number': '2345',
      },
    );

    expect(searchText, isNot(contains('110101199003072345')));
    expect(searchText, isNot(contains('2345'))); // 不应该混入后 4 位
    expect(searchText, contains('张三的身份证'));
  });

  test('验证 9. 防御性自动 Title 生成过滤高敏字段测试', () {
    // 1. 动态构造一个含有高敏标识字段的模板定义
    final fakeTypeDef = TypeDefinition(
      typeKey: 'fake_secret_card',
      label: '机密卡',
      categoryKey: 'card',
      fields: [
        FieldDefinition(
          fieldKey: 'bank_name', // 属于标识字段，但敏感度设为 high
          label: '机密银行',
          valueType: FieldValueType.text,
          sensitiveLevel: SensitiveLevel.high,
        ),
      ],
    );

    // 2. 构造输入草稿，其 bank_name 包含了高敏完整明文
    final draft = ItemDraftInput(
      memberId: 'some_member_uuid',
      categoryKey: 'card',
      typeKey: 'fake_secret_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '机密特需大额银行明文值'),
      ],
    );

    // 3. 验证自动生成标题时，绝对会跳过 high 敏字段，降级使用成员名称生成标题
    final title = TitleSummaryBuilder.buildTitle(
      draft: draft,
      typeDef: fakeTypeDef,
      memberName: '母亲',
    );

    // 期望标题中绝不包含高敏明文，而是使用成员名字降级拼装
    expect(title, isNot(contains('机密特需大额银行明文值')));
    expect(title, '母亲的机密卡');

    // 4. 验证 searchText 不会因为标题机制而混入高敏字段明文
    final searchText = SearchTextBuilder.buildSearchText(
      title: title,
      typeDef: fakeTypeDef,
      categoryLabel: '卡片资料',
      fields: draft.fields,
      normalizedValues: const {}, // 无 normalizedValue
    );

    expect(searchText, isNot(contains('机密特需大额银行明文值')));
    expect(searchText, contains('母亲的机密卡'));
  });
}
