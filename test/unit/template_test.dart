import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/template/sensitive_level.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/template/builtin_templates.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/service/models/item_draft_input.dart';

void main() {
  test('字段定义优先使用当前模板并保留历史安全兜底', () {
    final passport = TemplateRegistry.getTemplate('passport')!;
    final field = passport.fields.firstWhere(
      (field) => field.fieldKey == 'name_cn',
    );
    expect(
      TemplateRegistry.fieldDefinitionByKey(passport, 'name_cn'),
      same(field),
    );
    final idNumber = TemplateRegistry.fieldDefinitionByKey(null, 'id_number');
    expect(idNumber, isNotNull);
    expect(idNumber!.sensitiveLevel.name, 'high');
    expect(
      TemplateRegistry.fieldDefinitionByKey(null, 'fictional_unknown_key'),
      isNull,
    );
  });

  test('验证所有 15 个内置模板注册与字段安全性', () {
    final expectedKeys = [
      'debit_card',
      'credit_card',
      'id_card',
      'household_book',
      'passport',
      'hk_macao_pass',
      'driver_license',
      'vehicle_license',
      'birth_certificate',
      'marriage_certificate',
      'insurance',
      'generic',
      'property_certificate',
      'education_certificate',
      'shipping_address',
    ];

    final uniqueTypeKeys = BuiltinTemplates.types.map((t) => t.typeKey).toSet();
    expect(
      uniqueTypeKeys.length,
      expectedKeys.length,
      reason: '内置模板数量必须为 15 个',
    );

    for (final key in expectedKeys) {
      final typeDef = TemplateRegistry.getTemplate(key);
      expect(typeDef, isNotNull, reason: '必须能从注册表中检索到子类型为 $key 的模板');
      expect(typeDef!.typeKey, key);
      expect(typeDef.fields, isNotEmpty, reason: '$key 模板下必须声明有字段定义');

      // 字段防重复、安全性与防呆验证
      final seenKeys = <String>{};
      for (final field in typeDef.fields) {
        final fieldKey = field.fieldKey;

        // 1. 联合唯一防重复校验
        expect(
          seenKeys.contains(fieldKey),
          isFalse,
          reason: '$key 模板内存在重复声明的 fieldKey: $fieldKey',
        );
        seenKeys.add(fieldKey);

        // 2. 禁止保存 Forbidden 敏感分级强校验
        expect(
          field.sensitiveLevel,
          isNot(SensitiveLevel.forbidden),
          reason: '$key 模板的字段 $fieldKey 被设置为 forbidden 级别，这是非法配置，此类属性严禁设计入内！',
        );

        // 3. 敏感特征词防呆强拦截（阻断开发者后期误加密码、验证码、安全码等最高风险字段）
        final lowerKey = fieldKey.toLowerCase();
        final containsForbiddenWord =
            lowerKey.contains('cvv') ||
            lowerKey.contains('cvc') ||
            lowerKey.contains('password') ||
            lowerKey.contains('login_key') ||
            lowerKey.contains('pay_pass') ||
            lowerKey.contains('auth_token') ||
            lowerKey.contains('verify_code') ||
            lowerKey.contains('dynamic_code') ||
            lowerKey.contains('otp') ||
            lowerKey.contains('pin') ||
            lowerKey.contains('security_code');

        // 排查非冲突字段（比如 prefilled_phone/reserved_phone 是允许保存并用于详情展示的）
        if (fieldKey != 'reserved_phone') {
          expect(
            containsForbiddenWord,
            isFalse,
            reason:
                '$key 模板内发现违规或疑似最高风险敏感字段的定义: $fieldKey。系统绝不能以任何方式存储和录入支付密码、CVV/CVC/安全码、PIN码及动态验证码！',
          );
        }
      }
    }
  });

  test('验证大类元数据检索', () {
    final categories = TemplateRegistry.getCategories();
    expect(categories.length, 4, reason: '大类必须是 4 个');

    final categoryKeys = categories.map((c) => c.categoryKey).toList();
    expect(
      categoryKeys,
      containsAll(['certificate', 'card', 'insurance', 'other']),
    );
  });

  test('验证敏感词防呆强拦截辅助逻辑自身的拦截效果', () {
    bool checkContainsForbiddenWord(String fieldKey) {
      final lowerKey = fieldKey.toLowerCase();
      return lowerKey.contains('cvv') ||
          lowerKey.contains('cvc') ||
          lowerKey.contains('password') ||
          lowerKey.contains('login_key') ||
          lowerKey.contains('pay_pass') ||
          lowerKey.contains('auth_token') ||
          lowerKey.contains('verify_code') ||
          lowerKey.contains('dynamic_code') ||
          lowerKey.contains('otp') ||
          lowerKey.contains('pin') ||
          lowerKey.contains('security_code');
    }

    // 正向测试：必须被拦截的高危敏感特征词
    expect(checkContainsForbiddenWord('my_dynamic_code'), isTrue);
    expect(checkContainsForbiddenWord('card_otp_value'), isTrue);
    expect(checkContainsForbiddenWord('user_pin_code'), isTrue);
    expect(checkContainsForbiddenWord('my_security_code'), isTrue);
    expect(checkContainsForbiddenWord('cvv'), isTrue);
    expect(checkContainsForbiddenWord('cvc'), isTrue);
    expect(checkContainsForbiddenWord('password'), isTrue);
    expect(checkContainsForbiddenWord('login_key'), isTrue);
    expect(checkContainsForbiddenWord('pay_pass'), isTrue);
    expect(checkContainsForbiddenWord('auth_token'), isTrue);
    expect(checkContainsForbiddenWord('verify_code'), isTrue);

    // 负向测试：安全字段允许通过
    expect(checkContainsForbiddenWord('card_number'), isFalse);
    expect(checkContainsForbiddenWord('bank_name'), isFalse);
    expect(checkContainsForbiddenWord('holder_name'), isFalse);
    expect(checkContainsForbiddenWord('reserved_phone'), isFalse);
  });

  test('验证 TitleSummaryBuilder 定制模板标题拼装规则', () {
    // 身份证模板
    final idCardType = TemplateRegistry.getTemplate('id_card')!;

    // 1. 身份证：姓名有值 => 张三的身份证
    final title1 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [ItemFieldDraftInput(fieldKey: 'name', valueText: '张三')],
      ),
      typeDef: idCardType,
      memberName: '李四',
    );
    expect(title1, '张三的身份证');

    // 2. 身份证：姓名为空且成员不是家庭 => 李四的身份证
    final title2 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [ItemFieldDraftInput(fieldKey: 'name', valueText: '')],
      ),
      typeDef: idCardType,
      memberName: '李四',
    );
    expect(title2, '李四的身份证');

    // 3. 身份证：姓名为空且成员是家庭 => 身份证资料
    final title3 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [ItemFieldDraftInput(fieldKey: 'name', valueText: '')],
      ),
      typeDef: idCardType,
      memberName: '家庭',
    );
    expect(title3, '身份证资料');

    // 4. 身份证：姓名为空且成员为空 => 身份证资料
    final title4 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [],
      ),
      typeDef: idCardType,
      memberName: null,
    );
    expect(title4, '身份证资料');

    // 储蓄卡模板
    final debitCardType = TemplateRegistry.getTemplate('debit_card')!;

    // 5. 储蓄卡：有卡片别名 => 我的工资卡
    final title5 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '我的工资卡'),
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
        ],
      ),
      typeDef: debitCardType,
      memberName: '张三',
    );
    expect(title5, '我的工资卡');

    // 6. 储蓄卡：无别名但有银行名称 => 招商银行储蓄卡
    final title6a = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行')],
      ),
      typeDef: debitCardType,
      memberName: '张三',
    );
    expect(title6a, '招商银行储蓄卡');

    // 6b. 储蓄卡：无别名/银行但有卡号 => 尾号 7890 储蓄卡
    final title6b = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      ),
      typeDef: debitCardType,
      memberName: '张三',
    );
    expect(title6b, '尾号 7890 储蓄卡');

    // 6c. 储蓄卡：都缺失 => 储蓄卡
    final title6c = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [],
      ),
      typeDef: debitCardType,
      memberName: '张三',
    );
    expect(title6c, '储蓄卡');

    // 信用卡模板
    final creditCardType = TemplateRegistry.getTemplate('credit_card')!;

    // 7. 信用卡：银行名称有值 => 工商银行信用卡
    final title7 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '工商银行')],
      ),
      typeDef: creditCardType,
      memberName: '张三',
    );
    expect(title7, '工商银行信用卡');

    // 8. 信用卡：银行名称为空 => 信用卡
    final title8 = TitleSummaryBuilder.buildTitle(
      draft: ItemDraftInput(
        memberId: '1',
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [],
      ),
      typeDef: creditCardType,
      memberName: '张三',
    );
    expect(title8, '信用卡');
  });
}
