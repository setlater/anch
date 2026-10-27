import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/search/search_page.dart';
import 'package:anch/core/template/type_definition.dart';
import 'package:anch/core/template/field_definition.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/sensitive_level.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/widgets/anch_subpage_app_bar.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late ItemUseCaseService service;

  setUp(() {
    ItemGlobalRegistry.instance.clear();
    final context = createTestRepositoryContext(
      config: const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    runtime = context.runtime;
    di = context.di;
    service = context.itemUseCaseService;
  });

  Widget buildTestWidget() {
    return wrapTest(
      const AnchApp(),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('安册搜索功能单元/用例层测试', () {
    test('1. 关键字为空时返回空列表；可通过 title, summaryText/searchText 搜索到资料', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
        note: 'TEST-note-secret-keyword',
      );

      final result = await service.saveDraft(draft);
      expect(result.persisted, isTrue);

      // 空白搜索校验
      final searchEmpty = await service.searchItems('  ');
      expect(searchEmpty.isEmpty, isTrue);

      // Title 搜索校验
      final searchTitle = await service.searchItems('张三');
      expect(searchTitle.length, equals(1));
      expect(searchTitle.first.title, equals('张三的身份证'));

      // SearchText / 类别/类型展示名搜索校验 (searchText 含 身份证/证件资料 等)
      final searchCategory = await service.searchItems('证件资料');
      expect(searchCategory.length, equals(1));

      // 备注不再参与搜索校验
      final searchNote = await service.searchItems('TEST-note-secret-keyword');
      expect(searchNote.isEmpty, isTrue);
    });

    test('2. 搜索结果不得包含高敏字段完整值 (只包含低敏摘要)', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      await service.saveDraft(draft);

      // 搜索返回的是 ItemModel，只包含了低敏的主表数据
      final results = await service.searchItems('张三');
      expect(results.length, equals(1));

      final item = results.first;
      // 检验：ItemModel 本身不具有高敏的完整身份证号
      // 主表各字段中应无明文身份证号
      expect(item.title!.contains('110101199003072345'), isFalse);
      expect(
        item.primaryText?.contains('110101199003072345') ?? false,
        isFalse,
      );
      expect(item.searchText?.contains('110101199003072345') ?? false, isFalse);
      expect(
        item.summaryText?.contains('110101199003072345') ?? false,
        isFalse,
      );
    });

    test('3. 编辑与删除资料后，搜索结果同步刷新', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '李四'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003079999',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      // 确认可以搜到李四
      final res1 = await service.searchItems('李四');
      expect(res1.length, equals(1));

      // 编辑资料
      final editDraft = ItemDraftInput(
        id: itemId,
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '小李'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003079999',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );
      await service.saveDraft(editDraft);

      // 李四关键字应当搜不到，小李关键字可以搜到
      final res2 = await service.searchItems('李四');
      expect(res2.isEmpty, isTrue);

      final res3 = await service.searchItems('小李');
      expect(res3.length, equals(1));

      // 删除资料
      await service.deleteItem(itemId);
      final res4 = await service.searchItems('小李');
      expect(res4.isEmpty, isTrue);
    });

    test(
      '4. End-to-End search normalisation, interception and suffix matching rules',
      () async {
        // 1. Create a bank card with card number 6225881234567890 (tail 7890)
        final bankCardDraft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'debit_card',
          typeKey: 'debit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ),
          ],
        );
        await service.saveDraft(bankCardDraft);

        // 2. Create an ID card with id_number 110101199003072345 (tail 2345)
        final idCardDraft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'certificate',
          typeKey: 'id_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'name', valueText: '赵六'),
            ItemFieldDraftInput(
              fieldKey: 'id_number',
              valueText: '110101199003072345',
            ),
            ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ],
        );
        await service.saveDraft(idCardDraft);

        // 3. Create a bank card with tail 2345 (e.g. 6225881234562345)
        final bankCardWithSameTailDraft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'debit_card',
          typeKey: 'debit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '工商银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234562345',
            ),
          ],
        );
        await service.saveDraft(bankCardWithSameTailDraft);

        // 4. Create a 17-digit bank card (e.g. 62258812345678901)
        final bankCard17DigitDraft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'debit_card',
          typeKey: 'debit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '建设银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '62258812345678901',
            ),
          ],
        );
        await service.saveDraft(bankCard17DigitDraft);

        // Verify warmup / rebuild index to make sure everything is in index
        await service.searchItems('warmup');

        // Test 4.1: searchItems('6225881234567890') -> matches bank card (normalized to 7890)
        final searchFullCard = await service.searchItems('6225881234567890');
        expect(searchFullCard.length, equals(1));
        expect(searchFullCard.first.title, contains('招商银行'));

        // Test 4.2: searchItems('7890') -> matches bank card
        final searchCardTail = await service.searchItems('7890');
        expect(searchCardTail.length, equals(1));
        expect(searchCardTail.first.title, contains('招商银行'));

        // Test 4.3: searchItems('110101199003072345') -> returns [] (valid ID card intercepted)
        final searchFullId = await service.searchItems('110101199003072345');
        expect(searchFullId.isEmpty, isTrue);

        // Test 4.4: searchItems('2345') -> does not match the ID card, but matches the bank card with tail 2345
        final searchTail2345 = await service.searchItems('2345');
        expect(searchTail2345.length, equals(1));
        expect(
          searchTail2345.first.title,
          contains('工商银行'),
        ); // matches bank card, not ID card

        // Test 4.5: If exists bank card with same tail, searchItems('110101199003072345') still returns [] (does not match bank card)
        final searchFullIdAgain = await service.searchItems(
          '110101199003072345',
        );
        expect(searchFullIdAgain.isEmpty, isTrue);

        // Test 4.6: 17-digit bank card search by full number (e.g. 62258812345678901) -> matches bank card (normalized to 8901)
        final searchFull17Card = await service.searchItems('62258812345678901');
        expect(searchFull17Card.length, equals(1));
        expect(searchFull17Card.first.title, contains('建设银行'));

        // Test 4.7: 17-digit bank card search by tail '8901' -> matches bank card
        final searchCard17Tail = await service.searchItems('8901');
        expect(searchCard17Tail.length, equals(1));
        expect(searchCard17Tail.first.title, contains('建设银行'));
      },
    );
  });

  group('安册搜索页面 Widget 交互测试', () {
    testWidgets('4. 首页点击搜索框 -> 初始状态 -> 输入搜索 -> 卡片展示 -> 详情删除 -> 返回结果页刷新为空', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 新建一条身份证资料以作检索
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '张三');
      await tester.enterText(textFields.at(1), '110101199003072345');
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      // 退回首页
      await tester.tap(findAnchIcon(AnchIcons.home));
      await tester.pumpAndSettle();

      // 点击搜索入口
      final searchEntry = find.byKey(const Key('home_search_entry'));
      expect(searchEntry, findsOneWidget);
      await tester.tap(searchEntry);
      await tester.pumpAndSettle();

      // 验证已进入 SearchPage 搜索页面
      expect(find.text('搜索资料'), findsOneWidget);
      expect(find.text('输入关键词，查找已整理的资料'), findsOneWidget);

      // 输入名字搜索张三
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, '张三');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // 等待 debounce 完成

      // 检验展示了张三的记录
      expect(find.text('张三的身份证'), findsOneWidget);

      // 点击该卡片进入详情页
      await tester.tap(find.text('张三的身份证'));
      await tester.pumpAndSettle();
      expect(find.text('身份证'), findsOneWidget);

      // 执行删除
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移入最近删除'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // 验证返回到了搜索页，并且由于删除联动刷新，结果展示为了空状态
      expect(find.text('张三的身份证'), findsNothing);
      expect(find.text('暂无资料'), findsOneWidget);
    });

    testWidgets('5. 键盘弹出时搜索无结果空状态可滚动且不溢出', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapTest(
          const MaterialApp(home: SearchPage()),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 420);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      // 输入一个根本不存在的词
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, '不存在的关键词');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // 等待 debounce 完成

      // 校验无结果空状态文案
      expect(find.text('暂无资料'), findsOneWidget);
      expect(find.textContaining('开发验证模式'), findsOneWidget);
      expect(find.text('去添加资料'), findsOneWidget);
      expect(
        find.byKey(const Key('search_empty_results_scroll')),
        findsOneWidget,
      );
    });

    testWidgets('6. 搜索页显式适配浅色系统栏，焦点只强化整条搜索框', (WidgetTester tester) async {
      await tester.pumpWidget(
        wrapTest(
          const MaterialApp(home: SearchPage()),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AnchSubpageAppBar>(
        find.byType(AnchSubpageAppBar),
      );
      expect(
        appBar.systemOverlayStyle?.statusBarIconBrightness,
        Brightness.dark,
      );

      double borderWidth() {
        final field = tester.widget<AnimatedContainer>(
          find.byKey(const Key('search_input_container')),
        );
        final decoration = field.decoration! as BoxDecoration;
        return (decoration.border! as Border).top.width;
      }

      FocusScope.of(
        tester.element(find.byKey(const Key('search_input_container'))),
      ).unfocus();
      await tester.pumpAndSettle();
      expect(borderWidth(), 1);

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(borderWidth(), 2);
    });
  });

  group('SearchTextBuilder 安全边界与安全规则锁定测试', () {
    test('1. Forbidden 字段必须绝对排除，无论是何键名或类型', () {
      final mockFields = [
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '1234567890123456',
        ),
        ItemFieldDraftInput(
          fieldKey: 'some_forbidden_field',
          valueText: 'super_secret',
        ),
      ];
      final typeDef = TypeDefinition(
        typeKey: 'test_forbidden_type',
        label: '测试禁止类型',
        categoryKey: 'other',
        fields: [
          FieldDefinition(
            fieldKey: 'card_number',
            label: '卡号',
            valueType: FieldValueType.bankCardNumber,
            sensitiveLevel: SensitiveLevel.forbidden,
            searchable: true,
          ),
          FieldDefinition(
            fieldKey: 'some_forbidden_field',
            label: '禁止字段',
            valueType: FieldValueType.text,
            sensitiveLevel: SensitiveLevel.forbidden,
            searchable: true,
          ),
        ],
      );

      final searchText = SearchTextBuilder.buildSearchText(
        title: '测试标题',
        typeDef: typeDef,
        categoryLabel: '测试分类',
        fields: mockFields,
        normalizedValues: {'card_number': '3456', 'some_forbidden_field': null},
      );

      // Verify that no values or tail numbers of forbidden fields enter searchText
      expect(searchText.contains('1234567890123456'), isFalse);
      expect(searchText.contains('3456'), isFalse);
      expect(searchText.contains('super_secret'), isFalse);
      expect(searchText, equals('测试标题 测试禁止类型 测试分类'));
    });

    test('2. High 字段默认排除，唯一例外是 bank_card_number / card_number 只写入 4 位低敏尾号', () {
      final mockFields = [
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'vin', valueText: 'LSG12345678901234'),
      ];
      final typeDef = TypeDefinition(
        typeKey: 'test_high_type',
        label: '测试高敏类型',
        categoryKey: 'other',
        fields: [
          FieldDefinition(
            fieldKey: 'card_number',
            label: '卡号',
            valueType: FieldValueType.bankCardNumber,
            sensitiveLevel: SensitiveLevel.high,
            searchable: true,
          ),
          FieldDefinition(
            fieldKey: 'id_number',
            label: '身份证号',
            valueType: FieldValueType.idNumber,
            sensitiveLevel: SensitiveLevel.high,
            searchable: true,
          ),
          FieldDefinition(
            fieldKey: 'vin',
            label: '车架号',
            valueType: FieldValueType.sensitiveText,
            sensitiveLevel: SensitiveLevel.high,
            searchable: true,
          ),
        ],
      );

      final searchText = SearchTextBuilder.buildSearchText(
        title: '测试标题',
        typeDef: typeDef,
        categoryLabel: '测试分类',
        fields: mockFields,
        normalizedValues: {
          'card_number': '7890',
          'id_number': '2345',
          'vin': '1234',
        },
      );

      // Verify bank card tail enters
      expect(searchText.contains('7890'), isTrue);
      expect(searchText.contains('6225881234567890'), isFalse);

      // Verify ID card, VIN are completely excluded (neither full value nor tail enters)
      expect(searchText.contains('110101199003072345'), isFalse);
      expect(searchText.contains('2345'), isFalse);
      expect(searchText.contains('LSG12345678901234'), isFalse);
      expect(searchText.contains('1234'), isFalse);
    });

    test(
      '3. Medium 字段不可为 identifier-like，否则即使 searchable=true 也绝不进入 searchText',
      () {
        final mockFields = [
          ItemFieldDraftInput(
            fieldKey: 'policy_number',
            valueText: 'POL12345678',
          ),
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'E12345678',
          ),
          ItemFieldDraftInput(
            fieldKey: 'engine_number',
            valueText: 'ENG987654',
          ),
          ItemFieldDraftInput(
            fieldKey: 'some_normal_medium',
            valueText: 'MediumValue',
          ),
        ];
        final typeDef = TypeDefinition(
          typeKey: 'test_medium_type',
          label: '测试中敏类型',
          categoryKey: 'other',
          fields: [
            FieldDefinition(
              fieldKey: 'policy_number',
              label: '保单号',
              valueType: FieldValueType.sensitiveText,
              sensitiveLevel: SensitiveLevel.medium,
              searchable: true,
            ),
            FieldDefinition(
              fieldKey: 'passport_number',
              label: '护照号',
              valueType: FieldValueType.sensitiveText,
              sensitiveLevel: SensitiveLevel.medium,
              searchable: true,
            ),
            FieldDefinition(
              fieldKey: 'engine_number',
              label: '发动机号',
              valueType: FieldValueType.sensitiveText,
              sensitiveLevel: SensitiveLevel.medium,
              searchable: true,
            ),
            FieldDefinition(
              fieldKey: 'some_normal_medium',
              label: '常规中敏',
              valueType: FieldValueType.text,
              sensitiveLevel: SensitiveLevel.medium,
              searchable: true,
            ),
          ],
        );

        final searchText = SearchTextBuilder.buildSearchText(
          title: '测试标题',
          typeDef: typeDef,
          categoryLabel: '测试分类',
          fields: mockFields,
          normalizedValues: {},
        );

        // Verify that identifier-like fields (policy_number, passport_number, engine_number) are excluded
        expect(searchText.contains('POL12345678'), isFalse);
        expect(searchText.contains('E12345678'), isFalse);
        expect(searchText.contains('ENG987654'), isFalse);

        // Verify that non-identifier medium field enters
        expect(searchText.contains('MediumValue'), isTrue);
      },
    );

    test('4. Low/None 级别字段且 searchable=true 正常进入 searchText', () {
      final mockFields = [
        ItemFieldDraftInput(fieldKey: 'some_low_field', valueText: 'LowValue'),
        ItemFieldDraftInput(
          fieldKey: 'some_none_field',
          valueText: 'NoneValue',
        ),
        // searchable is false
        ItemFieldDraftInput(
          fieldKey: 'not_searchable_low',
          valueText: 'HiddenLow',
        ),
      ];
      final typeDef = TypeDefinition(
        typeKey: 'test_low_none_type',
        label: '测试低非敏感类型',
        categoryKey: 'other',
        fields: [
          FieldDefinition(
            fieldKey: 'some_low_field',
            label: '低敏字段',
            valueType: FieldValueType.text,
            sensitiveLevel: SensitiveLevel.low,
            searchable: true,
          ),
          FieldDefinition(
            fieldKey: 'some_none_field',
            label: '非敏感字段',
            valueType: FieldValueType.text,
            sensitiveLevel: SensitiveLevel.none,
            searchable: true,
          ),
          FieldDefinition(
            fieldKey: 'not_searchable_low',
            label: '不搜索低敏',
            valueType: FieldValueType.text,
            sensitiveLevel: SensitiveLevel.low,
            searchable: false,
          ),
        ],
      );

      final searchText = SearchTextBuilder.buildSearchText(
        title: '测试标题',
        typeDef: typeDef,
        categoryLabel: '测试分类',
        fields: mockFields,
        normalizedValues: {},
      );

      expect(searchText.contains('LowValue'), isTrue);
      expect(searchText.contains('NoneValue'), isTrue);
      expect(searchText.contains('HiddenLow'), isFalse);
    });
  });
}
