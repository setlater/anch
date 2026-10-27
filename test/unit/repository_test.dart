import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/template/field_value_type.dart';
import '../support/test_bootstrap.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;

  setUp(() {
    final context = createTestRepositoryContext();
    db = context.db;
    memberRepo = context.memberRepository;
    itemRepo = context.itemRepository;
  });

  test('验证 MemberRepository 能拉取内置家庭成员并能支持保存新成员', () async {
    // 1. 验证默认初始化后的“家庭”和“我”内置成员
    var members = await memberRepo.getActiveMembers();
    expect(members.length, 2);
    expect(members[0].id, systemFamilyMemberId);
    expect(members[0].name, '家庭');
    expect(members[0].memberType, 'family');
    expect(members[1].id, systemMeMemberId);
    expect(members[1].name, '我');
    expect(members[1].memberType, 'person');

    // 2. 验证写入新成员
    final saveInput = SaveMemberInput(memberType: 'person', name: '父亲');

    final newMemberId = await memberRepo.saveMember(saveInput);
    expect(newMemberId, isNotEmpty);

    // 3. 再次获取列表
    members = await memberRepo.getActiveMembers();
    expect(members.length, 3);

    final father = members.firstWhere((m) => m.id == newMemberId);
    expect(father.name, '父亲');
    expect(father.isSystem, false);
  });

  test('验证 MemberRepository 对系统内置属性的保存安全性拦截防护', () async {
    // 1. 测试传入 isSystem: true，应当抛出 UnsupportedError
    final systemInput = SaveMemberInput(
      memberType: 'person',
      name: '系统注入人',
      isSystem: true,
    );
    expect(
      () => memberRepo.saveMember(systemInput),
      throwsA(isA<UnsupportedError>()),
    );

    // 2. 测试传入 memberType: 'family'，应当抛出 UnsupportedError
    final familyInput = SaveMemberInput(memberType: 'family', name: '又一个家庭');
    expect(
      () => memberRepo.saveMember(familyInput),
      throwsA(isA<UnsupportedError>()),
    );
  });

  test('验证 ItemRepository 的完整 CRUD 骨架与级联 CASCADE 删除效果', () async {
    // 1. 保存一条测试资料身份证信息及 2 个子字段属性（配合强类型 FieldValueType）
    final saveInput = SaveItemInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      title: '张三的身份证',
      primaryText: '张三',
      secondaryText: '身份证',
      fields: [
        SaveItemFieldInput(
          fieldKey: 'name',
          valueType: FieldValueType.sensitiveText,
          valueText: '张三',
        ),
        SaveItemFieldInput(
          fieldKey: 'id_number',
          valueType: FieldValueType.idNumber,
          valueText: '110101199003072345',
          normalizedValue: '2345',
        ),
      ],
    );

    final itemId = await itemRepo.saveItemWithFields(saveInput);
    expect(itemId, isNotEmpty);

    // 2. 查询组装还原验证
    final retrieved = await itemRepo.getItemWithFields(itemId);
    expect(retrieved, isNotNull);
    expect(retrieved!.id, itemId);
    expect(retrieved.title, '张三的身份证');
    expect(retrieved.fields.length, 2);

    final nameField = retrieved.fields.firstWhere((f) => f.fieldKey == 'name');
    expect(nameField.valueText, '张三');
    expect(nameField.valueType, 'sensitive_text'); // 验证底层物理数据库中保存的是转义后字符串

    final idNumberField = retrieved.fields.firstWhere(
      (f) => f.fieldKey == 'id_number',
    );
    expect(idNumberField.valueText, '110101199003072345');
    expect(idNumberField.normalizedValue, '2345');

    // 3. 验证物理删除 items 记录时数据库外键级联 Cascade 自动清理下挂的字段信息
    var allFields = await db.select(db.itemFields).get();
    expect(allFields.length, 2);

    // 物理删除主记录
    await itemRepo.deleteItem(itemId);

    // 再次查询原记录为空
    final checkItem = await itemRepo.getItemWithFields(itemId);
    expect(checkItem, isNull);

    // 验证下挂字段已被级联自动清空
    allFields = await db.select(db.itemFields).get();
    expect(
      allFields,
      isEmpty,
      reason: '物理删除 item 主记录后，SQLite 外键级联 CASCADE 必须将其下挂的所有字段自动清除',
    );
  });

  test('验证 repaymentDay / billDay 从 metadata 中解析，且异常 metadata 不崩溃', () async {
    // 1. 验证正常 metadata 解析 与 fields 提取
    final normalInput = SaveItemInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'credit_card',
      title: '信用卡正常',
      fields: [
        SaveItemFieldInput(
          fieldKey: 'repayment_day',
          valueType: FieldValueType.text,
          valueText: '10',
        ),
      ],
      metadata:
          '{"raw_state": {"fields": {"repayment_day": "10", "bill_day": "20"}}}',
    );
    final itemId1 = await itemRepo.saveItemWithFields(normalInput);
    final item1 = await itemRepo.getItemWithFields(itemId1);
    expect(item1, isNotNull);
    expect(item1!.repaymentDay, '10');
    // 验证 ItemModel 中的 repaymentDay / billDay
    final activeItems = await itemRepo.getActiveItems();
    final model1 = activeItems.firstWhere((i) => i.id == itemId1);
    expect(model1.repaymentDay, '10');
    expect(model1.billDay, '20');

    // 2. 验证非法 metadata 不崩溃且返回 null
    final badInput = SaveItemInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'credit_card',
      title: '信用卡异常metadata',
      fields: const [],
      metadata: '{invalid_json',
    );
    final itemId2 = await itemRepo.saveItemWithFields(badInput);
    final item2 = await itemRepo.getItemWithFields(itemId2);
    expect(item2, isNotNull);
    expect(item2!.repaymentDay, isNull);
    final model2 = (await itemRepo.getActiveItems()).firstWhere(
      (i) => i.id == itemId2,
    );
    expect(model2.repaymentDay, isNull);
    expect(model2.billDay, isNull);

    // 3. 验证缺少 metadata 不崩溃且返回 null
    final missingInput = SaveItemInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'credit_card',
      title: '信用卡缺少metadata',
      fields: const [],
      metadata: null,
    );
    final itemId3 = await itemRepo.saveItemWithFields(missingInput);
    final item3 = await itemRepo.getItemWithFields(itemId3);
    expect(item3, isNotNull);
    expect(item3!.repaymentDay, isNull);
  });

  test('活跃资料分组数量与归档数量直接查询保持状态和关键词边界', () async {
    final customMemberId = await memberRepo.saveMember(
      SaveMemberInput(memberType: 'person', name: '虚构成员'),
    );
    await itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: '虚构证件',
        fields: const [],
      ),
    );
    await itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: customMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '虚构卡片',
        fields: const [],
      ),
    );
    await itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '匹配归档资料',
        summaryText: '归档摘要',
        status: 'archived',
        fields: const [],
      ),
    );
    await itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '已删除资料',
        status: 'deleted',
        deletedAt: DateTime.now().millisecondsSinceEpoch,
        statusBeforeDeletion: 'active',
        fields: const [],
      ),
    );

    expect(await itemRepo.getActiveMemberCounts(), {
      systemFamilyMemberId: 1,
      customMemberId: 1,
    });
    expect(await itemRepo.getActiveCategoryCounts(), {
      'certificate': 1,
      'card': 1,
    });
    expect(await itemRepo.getActiveTypeCounts(), {
      'id_card': 1,
      'debit_card': 1,
    });
    expect(await itemRepo.getArchivedItemCount(), 1);
    expect(await itemRepo.getArchivedItemCount(keyword: '匹配'), 1);
    expect(await itemRepo.getArchivedItemCount(keyword: '不存在'), 0);
  });
}
