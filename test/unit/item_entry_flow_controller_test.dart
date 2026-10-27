import 'dart:convert';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/field/field_origin.dart';
import 'package:anch/core/repository/models/member_model.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/features/item_entry/controllers/item_entry_flow_controller.dart';
import 'package:anch/features/item_entry/controllers/item_entry_flow_state.dart';
import 'package:anch/features/item_entry/controllers/item_auto_fill_engine.dart';

ItemWithFields storedItem(
  String type,
  int version,
  Map<String, String> values, {
  String? metadata,
}) => ItemWithFields(
  id: 'mock',
  typeKey: type,
  templateVersion: version,
  isFavorite: false,
  isPinned: false,
  sortOrder: 0,
  status: 'active',
  createdAt: 0,
  updatedAt: 0,
  metadata: metadata,
  fields: [
    for (final entry in values.entries)
      ItemFieldModel(
        id: entry.key,
        itemId: 'mock',
        fieldKey: entry.key,
        valueType: 'text',
        valueText: entry.value,
        templateFieldKnown: true,
        isArchivedField: false,
        sortOrder: 0,
        createdAt: 0,
        updatedAt: 0,
      ),
  ],
);

ItemEntryFlowController newController() {
  final controller = ItemEntryFlowController(
    enableAutoFillScaffold: false,
    autoFillEngine: const ItemAutoFillEngine(
      timeDomainSource: SystemTimeDomainSource(),
    ),
  );
  addTearDown(controller.dispose);
  return controller;
}

void main() {
  test('录入校验区分长期证件、缺失字段和自定义凭证标签', () {
    final controller = newController();
    controller.selectType(TemplateRegistry.getTemplate('id_card')!);
    controller.updateField('name', '虚构成员');
    controller.updateField('id_number', '110101199003072345');
    controller.updateField('gender', '男');
    controller.updateField('is_long_term', 'true');
    expect(
      controller.requiredFieldErrors().containsKey('valid_until'),
      isFalse,
    );
    controller.updateField('name', '');
    expect(controller.requiredFieldErrors().containsKey('name'), isTrue);
    controller.selectType(TemplateRegistry.getTemplate('generic', 2)!);
    controller.updateField('title', '虚构资料');
    controller.updateField('custom_field_value_1', '虚构内容');
    expect(controller.requiredFieldErrors()['custom_field_label_1'], '请填写字段名');
    controller.updateField('custom_field_label_1', '登录密码');
    expect(
      controller.requiredFieldErrors()['custom_field_label_1'],
      '此字段涉及高危凭证，安册不会保存',
    );
  });

  test('字段联动原子更新并保留用户已编辑值及来源', () {
    final controller = newController();
    controller.selectType(TemplateRegistry.getTemplate('id_card')!);
    controller.updateField('gender', '女');
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updateFieldWithInteractions('id_number', '110101199003072345');
    expect(notifications, 1);
    expect(controller.value.fieldValues['gender']!.value, '女');
    expect(controller.value.fieldValues['gender']!.origin, FieldOrigin.user);
    expect(controller.value.fieldValues['birth_date']!.value, '1990-03-07');
    expect(
      controller.value.fieldValues['birth_date']!.origin,
      FieldOrigin.autofill,
    );
  });

  test('身份资料建议只返回当前模板可用且为空的字段', () {
    final controller = newController();
    controller.selectType(TemplateRegistry.getTemplate('passport')!);
    controller.updateField('name_cn', '手动姓名');
    final suggestions = controller.identitySuggestions({
      'name': '虚构成员',
      'gender': '男',
      'birth_date': '1990-03-07',
      'id_number': '110101199003072345',
    });
    expect(suggestions.containsKey('name_cn'), isFalse);
    expect(suggestions['gender'], '男');
    expect(suggestions.containsKey('id_number'), isFalse);
  });

  group('FieldState, applyFieldChange, and AutoFill Switch Tests', () {
    test('initializeForEdit 以单次通知完成编辑状态初始化', () {
      final controller = ItemEntryFlowController(
        enableAutoFillScaffold: true,
        autoFillEngine: ItemAutoFillEngine(
          timeDomainSource: const SystemTimeDomainSource(),
        ),
      );
      final owner = MemberModel(
        id: 'member',
        memberType: 'person',
        name: '测试成员',
        sortOrder: 0,
        isSystem: false,
        isArchived: false,
        createdAt: 0,
        updatedAt: 0,
      );
      final intent = TemplateRegistry.getCreatableTypes().firstWhere(
        (candidate) => candidate.typeKey == 'id_card',
      );
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.initializeForEdit(
        type: intent,
        templateVersion: 1,
        owner: owner,
        values: const {'name': '测试成员', 'id_number': '0000'},
        origins: const {
          'name': FieldOrigin.user,
          'id_number': FieldOrigin.unknown,
        },
      );

      expect(notifications, 1);
      expect(controller.value.currentStep, ItemEntryStep.editableReview);
      expect(controller.value.selectedOwner, owner);
      expect(controller.value.fieldValues['name']?.value, '测试成员');
      controller.dispose();
    });

    test(
      'applyFieldChange should set FieldState correctly and update value notifier',
      () {
        final controller = ItemEntryFlowController(
          enableAutoFillScaffold: true,
          autoFillEngine: ItemAutoFillEngine(
            timeDomainSource: const SystemTimeDomainSource(),
          ),
        );

        // 1. 模拟自动填充写入
        controller.applyFieldChange('name', '家庭', FieldOrigin.autofill);
        expect(controller.value.fieldValues['name']?.value, '家庭');
        expect(
          controller.value.fieldValues['name']?.origin,
          FieldOrigin.autofill,
        );

        // 2. 模拟用户输入写入
        controller.applyFieldChange('name', '张三', FieldOrigin.user);
        expect(controller.value.fieldValues['name']?.value, '张三');
        expect(controller.value.fieldValues['name']?.origin, FieldOrigin.user);

        // 3. 模拟 unknown fallback 写入
        controller.applyFieldChange('name', '未知', FieldOrigin.unknown);
        expect(controller.value.fieldValues['name']?.value, '未知');
        expect(
          controller.value.fieldValues['name']?.origin,
          FieldOrigin.unknown,
        );
      },
    );

    test(
      'selectOwner with enableAutoFillScaffold = false should not trigger AutoFill',
      () {
        final controller = ItemEntryFlowController(
          enableAutoFillScaffold: false, // 关闭自动填充
          autoFillEngine: ItemAutoFillEngine(
            timeDomainSource: const SystemTimeDomainSource(),
          ),
        );

        final intent = TemplateRegistry.getCreatableTypes().first;
        final owner = MemberModel(
          id: '1',
          memberType: 'person',
          name: '测试人员',
          sortOrder: 0,
          isSystem: false,
          isArchived: false,
          createdAt: 0,
          updatedAt: 0,
        );

        controller.selectType(intent);
        controller.selectOwner(owner);

        // 自动填充应该为空（没有字段具有 autofill 状态）
        final hasAutofill = controller.value.fieldValues.values.any(
          (f) => f.origin == FieldOrigin.autofill,
        );
        expect(hasAutofill, isFalse);
      },
    );

    test(
      'selectOwner with enableAutoFillScaffold = true should trigger AutoFill',
      () {
        final controller = ItemEntryFlowController(
          enableAutoFillScaffold: true, // 开启自动填充
          autoFillEngine: ItemAutoFillEngine(
            timeDomainSource: const SystemTimeDomainSource(),
          ),
        );

        final intent = TemplateRegistry.getCreatableTypes().firstWhere(
          (i) => i.typeKey == 'id_card',
        );
        final owner = MemberModel(
          id: '1',
          memberType: 'person',
          name: '测试人员',
          sortOrder: 0,
          isSystem: false,
          isArchived: false,
          createdAt: 0,
          updatedAt: 0,
        );

        controller.selectType(intent);
        controller.selectOwner(owner);

        // 自动填充不应该为空，并且 origin 应为 autofill
        expect(controller.value.fieldValues, isNotEmpty);
        expect(controller.value.fieldValues['name']?.value, '测试人员');
        expect(
          controller.value.fieldValues['name']?.origin,
          FieldOrigin.autofill,
        );
      },
    );
  });

  test('录入只有一种顺序，首尾返回和推进不越界', () {
    final controller = ItemEntryFlowController(
      enableAutoFillScaffold: false,
      autoFillEngine: const ItemAutoFillEngine(
        timeDomainSource: SystemTimeDomainSource(),
      ),
    );
    addTearDown(controller.dispose);
    controller.prevStep();
    expect(controller.value.currentStep, ItemEntryStep.type);
    for (final step in ItemEntryStep.values.skip(1)) {
      controller.nextStep();
      expect(controller.value.currentStep, step);
    }
    controller.nextStep();
    expect(controller.value.currentStep, ItemEntryStep.supplement);
    for (final step in ItemEntryStep.values.reversed.skip(1)) {
      controller.prevStep();
      expect(controller.value.currentStep, step);
    }
  });
  test('动态字段只在末对填满时扩展，删除时清除旧键并紧凑重排', () {
    final controller = newController();
    controller.selectType(TemplateRegistry.getTemplate('generic', 2)!);
    controller.updateField('custom_field_label_1', 'MOCK removed label');
    expect(controller.value.genericCustomFieldCount, 1);
    controller.updateField('custom_field_value_1', 'MOCK removed value');
    expect(controller.value.genericCustomFieldCount, 2);
    controller.updateField(
      'custom_field_value_1',
      'MOCK changed removed value',
    );
    expect(controller.value.genericCustomFieldCount, 2);
    controller.addGenericField();
    controller.applyFieldChange(
      'custom_field_label_3',
      'MOCK kept label',
      FieldOrigin.autofill,
    );
    controller.updateField('custom_field_value_3', 'MOCK kept value');
    expect(controller.value.genericCustomFieldCount, 4);
    controller.removeGenericField(1);
    expect(controller.value.genericCustomFieldCount, 3);
    expect(
      controller.value.fieldValues.keys,
      isNot(contains('custom_field_value_4')),
    );
    expect(
      controller.value.fieldValues['custom_field_label_2']?.origin,
      FieldOrigin.autofill,
    );
    final fields = controller.buildDraftFields();
    expect(fields.map((field) => field.fieldKey), [
      'title',
      'custom_field_label_2',
      'custom_field_value_2',
    ]);
    expect(
      fields.map((field) => field.valueText),
      isNot(contains('MOCK changed removed value')),
    );
    expect(fields.last.valueText, 'MOCK kept value');
  });

  test('编辑动态字段单次还原，保留来源并留出末尾空对', () {
    final controller = newController();
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.initializeFromItem(
      storedItem(
        'generic',
        2,
        {
          'title': 'MOCK item',
          'custom_field_label_2': 'MOCK label',
          'custom_field_value_2': 'MOCK value',
        },
        metadata: jsonEncode({
          'field_origins': {
            'custom_field_label_2': 'user',
            'custom_field_value_2': 'autofill',
          },
        }),
      ),
      owner: null,
    );
    expect(notifications, 1);
    expect(controller.value.genericCustomFieldCount, 3);
    expect(controller.value.currentStep, ItemEntryStep.editableReview);
    controller.removeGenericField(1);
    expect(
      controller.value.fieldValues['custom_field_label_1']?.value,
      'MOCK label',
    );
    expect(
      controller.value.fieldValues['custom_field_value_1']?.origin,
      FieldOrigin.autofill,
    );
    expect(
      controller.value.fieldValues.keys,
      isNot(contains('custom_field_label_3')),
    );
  });

  test('编辑保留历史模板版本，损坏来源按 unknown 还原，长期日期原值不变', () {
    final controller = newController();
    controller.initializeFromItem(
      storedItem('debit_card', 1, {
        'bank_name': 'MOCK bank',
        'branch_name': 'MOCK branch',
      }, metadata: '{broken'),
      owner: null,
    );
    expect(controller.value.selectedTemplateVersion, 1);
    expect(controller.value.selectedType?.version, 1);
    expect(
      controller.value.fieldValues['bank_name']?.origin,
      FieldOrigin.unknown,
    );
    expect(controller.hasOptionalValues, isFalse);
    controller.initializeFromItem(
      storedItem('credit_card', 1, {'credit_limit': '200'}),
      owner: null,
    );
    expect(controller.hasOptionalValues, isTrue);
    controller.initializeFromItem(
      storedItem('id_card', 1, {
        'valid_until': '2029-01-02',
        'is_long_term': 'true',
      }, metadata: jsonEncode({'field_origins': []})),
      owner: null,
    );
    final draft = {
      for (final field in controller.buildDraftFields())
        field.fieldKey: field.valueText,
    };
    expect(draft['valid_until'], '2029-01-02');
    expect(draft['is_long_term'], 'true');
    expect(
      controller.value.fieldValues['valid_until']?.origin,
      FieldOrigin.unknown,
    );
  });

  test('类型切换清理旧动态字段，删除最后一对保留空输入位置', () {
    final controller = newController();
    controller.selectType(TemplateRegistry.getTemplate('generic', 2)!);
    controller.updateField('custom_field_label_1', 'MOCK label');
    controller.removeGenericField(1);
    expect(controller.value.genericCustomFieldCount, 1);
    expect(
      controller.value.fieldValues.keys.where(
        (key) => ItemEntryFlowController.genericFieldIndex(key) != null,
      ),
      isEmpty,
    );
    controller.addGenericField();
    controller.selectType(TemplateRegistry.getTemplate('id_card')!);
    expect(controller.value.genericCustomFieldCount, 1);
    expect(
      controller.value.fieldValues.keys.where(
        (key) => ItemEntryFlowController.genericFieldIndex(key) != null,
      ),
      isEmpty,
    );
  });
}
