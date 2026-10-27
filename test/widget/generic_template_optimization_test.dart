import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/core/widgets/anch_info_field_row.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;

  setUp(() {
    runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    di = DependencyProvider.create(
      runtime: runtime,
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget(Widget child) {
    return wrapTest(
      MaterialApp(home: child),
      runtime,
      (c) => di.copyWith(child: c),
    );
  }

  Future<void> setupScreenSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  // ──────────────────────────────────────────────────
  // 1. 模板字段结构验证
  // ──────────────────────────────────────────────────
  group('generic 模板字段结构验证', () {
    test('1.1 模板存在且 label 为"其他资料"', () {
      final typeDef = TemplateRegistry.getTemplate('generic');
      expect(typeDef, isNotNull);
      expect(typeDef!.label, '其他资料');
    });

    test('1.2 新版保留基础字段键，字段值默认按普通文本保存', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final keys = typeDef.fields.map((f) => f.fieldKey).toList();
      expect(
        keys,
        containsAll([
          'title',
          'custom_field_label_1',
          'custom_field_value_1',
          'custom_field_label_2',
          'custom_field_value_2',
          'custom_field_label_3',
          'custom_field_value_3',
        ]),
      );
      expect(keys.length, 7);
      for (final index in [1, 2, 3]) {
        final valueField = typeDef.fields.firstWhere(
          (field) => field.fieldKey == 'custom_field_value_$index',
        );
        expect(valueField.valueType.name, 'text');
        expect(valueField.sensitiveLevel.name, 'low');
      }

      final legacy = TemplateRegistry.getTemplate('generic', 1)!;
      expect(legacy.supportsLegacyEditing, isTrue);
      expect(legacy.fields.map((f) => f.fieldKey), contains('owner_name'));
    });

    test('1.3 title 字段为必填', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final titleField = typeDef.fields.firstWhere(
        (f) => f.fieldKey == 'title',
      );
      expect(titleField.required, isTrue);
    });

    test('1.4 已删除字段不在模板中', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final keys = typeDef.fields.map((f) => f.fieldKey).toList();
      expect(keys, isNot(contains('issue_date')));
      expect(keys, isNot(contains('address')));
      expect(keys, isNot(contains('contact_phone')));
      expect(keys, isNot(contains('place_or_website')));
      expect(keys, isNot(contains('note')));
    });
  });

  // ──────────────────────────────────────────────────
  // 2. Step 2 录入页自定义布局验证
  // ──────────────────────────────────────────────────
  group('generic Step 2 录入自定义布局验证', () {
    testWidgets('2.1 选中"其他资料"后显示首组字段，并支持自动添加和删除', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();

      // 跳转到类型选择

      // 展开其他资料大类（默认证件展开，先收起）

      // 选择"其他资料"（generic 的 label）
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      // 初始只展示一组，填满后自动新增下一组。
      expect(find.textContaining('资料名称'), findsOneWidget);
      expect(
        find.byKey(const Key('item_field_group_generic_pair_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('item_field_group_generic_pair_2')),
        findsNothing,
      );
      expect(find.byKey(const Key('generic_custom_field_add')), findsOneWidget);
      expect(
        find.byKey(const Key('generic_custom_field_remove_1')),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_label_1')),
        '虚构字段甲',
      );
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_value_1')),
        '虚构值甲',
      );
      await tester.pump();
      expect(
        find.byKey(const Key('item_field_group_generic_pair_2')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('generic_custom_field_remove_1')));
      await tester.pumpAndSettle();
      expect(find.text('删除已填写的字段？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('本次不再提醒'), findsOneWidget);
      expect(find.text('删除字段'), findsWidgets);
      await tester.tap(find.text('删除字段').last);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('item_field_group_generic_pair_2')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('generic_custom_field_remove_1')),
        findsNothing,
      );

      // 验证无折叠块
      expect(find.text('补充信息'), findsNothing);
    });

    testWidgets('2.2 title 必填：空提交显示错误提示', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      // 直接点击下一步，不输入资料名称
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('请输入资料名称'), findsOneWidget);
    });

    testWidgets('2.3 自定义字段在输入时限制长度并显示提示', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      final labelFinder = find.byKey(
        const Key('item_field_control_custom_field_label_1'),
      );
      final valueFinder = find.byKey(
        const Key('item_field_control_custom_field_value_1'),
      );
      final labelField = tester.widget<TextField>(
        find.descendant(of: labelFinder, matching: find.byType(TextField)),
      );
      final valueField = tester.widget<TextField>(
        find.descendant(of: valueFinder, matching: find.byType(TextField)),
      );

      expect(labelField.maxLength, 32);
      expect(labelField.decoration?.hintText, '最多 32 字');
      expect(valueField.maxLength, 4000);
      expect(valueField.maxLines, 1);
      expect(valueField.minLines, 1);
      expect(valueField.keyboardType, isNot(TextInputType.multiline));
      expect(valueField.decoration?.helperText, isNull);
      expect(find.text('0/32'), findsNothing);

      await tester.enterText(labelFinder, List.filled(33, '甲').join());
      expect(labelField.controller!.text, List.filled(32, '甲').join());
      expect(find.text('32/32'), findsNothing);
    });

    testWidgets('2.4 已删除字段不出现在 Step 2', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('签发/办理日期'), findsNothing);
      expect(find.textContaining('地址'), findsNothing);
      expect(find.textContaining('联系电话'), findsNothing);
      expect(find.textContaining('地点/网址文本'), findsNothing);
      expect(find.textContaining('备注'), findsNothing);
    });

    testWidgets('2.4 新版其他资料填写标题后可进入附件步骤且不显示模板错误', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item_field_control_title')),
        '虚构资料',
      );
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('添加附件或照片'), findsOneWidget);
      expect(
        find.byKey(const Key('item_field_error_custom_field_label_1')),
        findsNothing,
      );
    });

    testWidgets('2.5 已填写的自定义字段删除后按顺序重排', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_label_1')),
        '虚构字段甲',
      );
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_value_1')),
        '虚构值甲',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_label_2')),
        '虚构字段乙',
      );
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_value_2')),
        '虚构值乙',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('generic_custom_field_remove_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除字段').last);
      await tester.pumpAndSettle();
      final labelField = tester.widget<TextFormField>(
        find.byKey(const Key('item_field_control_custom_field_label_1')),
      );
      expect(labelField.controller!.text, '虚构字段乙');
    });

    testWidgets('2.6 动态字段仅保留单条分隔线，删除提醒可取消或仅在本次编辑关闭', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      final fieldCard = tester.widget<Container>(
        find.byKey(const Key('item_field_group_generic_pair_1')),
      );
      final border = (fieldCard.decoration! as BoxDecoration).border! as Border;
      expect(border.top.style, BorderStyle.none);
      expect(border.bottom.style, BorderStyle.solid);

      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_label_1')),
        '虚构字段甲',
      );
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_value_1')),
        '虚构值甲',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_label_2')),
        '虚构字段乙',
      );
      await tester.enterText(
        find.byKey(const Key('item_field_control_custom_field_value_2')),
        '虚构值乙',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('generic_custom_field_remove_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('item_field_group_generic_pair_1')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('generic_custom_field_remove_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('本次不再提醒'));
      await tester.pumpAndSettle();

      expect(find.text('删除已填写的字段？'), findsNothing);
      expect(
        find.byKey(const Key('generic_custom_field_remove_1')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('generic_custom_field_remove_1')));
      await tester.pumpAndSettle();
      expect(find.text('删除已填写的字段？'), findsNothing);
      expect(
        find.byKey(const Key('generic_custom_field_remove_1')),
        findsNothing,
      );
    });
  });

  // ──────────────────────────────────────────────────
  // 3. 详情页自定义布局验证
  // ──────────────────────────────────────────────────
  group('generic 详情页自定义布局验证', () {
    testWidgets('3.1 头部为 compact：显示"其他资料"标签，不显示类型说明/badges/旧摘要串', (
      WidgetTester tester,
    ) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '测试其他资料'),
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('其他资料')),
        findsOneWidget,
      );
      expect(find.textContaining('类型：'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('默认脱敏'), findsNothing);
      expect(find.text('可复制字段'), findsNothing);
    });

    testWidgets('3.2 详情页显示保留字段，不渲染已删字段', (WidgetTester tester) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '我的电子证'),
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
            ItemFieldDraftInput(
              fieldKey: 'identifier',
              valueText: 'GH-20240001',
            ),
            ItemFieldDraftInput(fieldKey: 'issuer', valueText: '国家档案局'),
            ItemFieldDraftInput(
              fieldKey: 'valid_until',
              valueText: '2030-12-31',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      expect(find.text('我的电子证'), findsWidgets);
      expect(find.text('张三'), findsOneWidget);
      // identifier 字段为 high 敏感度，默认掩码显示，验证字段标签存在即可
      expect(find.textContaining('编号/账号'), findsOneWidget);
      expect(find.text('国家档案局'), findsOneWidget);
    });

    testWidgets('3.3 即使历史数据包含已删字段，详情页也不渲染它们', (WidgetTester tester) async {
      // 存入含已删字段的历史数据
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '历史资料'),
            // 以下为已删字段（来自旧备份）
            ItemFieldDraftInput(fieldKey: 'address', valueText: '历史地址不应显示'),
            ItemFieldDraftInput(
              fieldKey: 'contact_phone',
              valueText: '13800000000',
            ),
            ItemFieldDraftInput(fieldKey: 'note', valueText: '历史备注不应显示'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      expect(find.text('历史地址不应显示'), findsNothing);
      expect(find.text('13800000000'), findsNothing);
      // note 由 Step 3 通用备注处理，来自 ItemDraftInput.note，不是 generic FieldDefinition 字段
      // 所以此处期望"历史备注不应显示"（字段值）不显示
      expect(find.text('历史备注不应显示'), findsNothing);
    });

    testWidgets('3.4 新版详情以用户填写的字段名直接展示字段值', (WidgetTester tester) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 2,
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '家庭宽带'),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_label_1',
              valueText: '账号',
            ),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_value_1',
              valueText: 'demo-account-1234',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      expect(find.text('账号'), findsOneWidget);
      expect(find.text('字段值 1'), findsNothing);
      expect(find.text('demo-account-1234'), findsOneWidget);
      final rows = tester
          .widgetList<AnchInfoFieldRow>(find.byType(AnchInfoFieldRow))
          .where(
            (row) =>
                row.fieldKey == 'title' ||
                row.fieldKey == 'custom_field_value_1',
          )
          .toList();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.labelWidth).toSet(), hasLength(1));
      expect(rows.first.labelWidth, lessThan(100));
    });

    test('3.5 第四组自定义字段可保存，凭证字段名会被拦截', () async {
      final accepted = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 2,
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '虚构扩展资料'),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_label_4',
              valueText: '虚构字段丁',
            ),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_value_4',
              valueText: '虚构值丁',
            ),
          ],
        ),
      );
      expect(accepted.success, isTrue);
      final saved = await di.itemRepo.getItemWithFields(accepted.itemId!);
      expect(
        saved!.fields.map((field) => field.fieldKey),
        contains('custom_field_value_4'),
      );
      expect(
        saved.fields
            .firstWhere((field) => field.fieldKey == 'custom_field_value_4')
            .valueType,
        'text',
      );

      final rejected = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 2,
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '虚构拦截资料'),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_label_1',
              valueText: '登录密码',
            ),
            ItemFieldDraftInput(
              fieldKey: 'custom_field_value_1',
              valueText: 'not-a-real-secret',
            ),
          ],
        ),
      );
      expect(rejected.success, isFalse);
    });
  });

  // ──────────────────────────────────────────────────
  // 4. TitleSummaryBuilder 摘要/标题逻辑验证
  // ──────────────────────────────────────────────────
  group('generic 摘要与标题逻辑验证', () {
    test('4.1 buildTitle: title 有值时返回 title 值', () {
      final typeDef = TemplateRegistry.getTemplate('generic', 1)!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        title: '我的证件',
        fields: [],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '我的证件');
    });

    test('4.2 buildTitle: title 为空时兜底返回"其他资料"', () {
      final typeDef = TemplateRegistry.getTemplate('generic', 1)!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '其他资料');
    });

    test('4.3 buildPrimaryText: 拼接 owner_name、identifier、valid_until，跳过空值', () {
      final typeDef = TemplateRegistry.getTemplate('generic', 1)!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [
          ItemFieldDraftInput(fieldKey: 'title', valueText: '测试资料'),
          ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2030-12-31'),
          // identifier 为空，应被跳过
        ],
      );
      final primaryText = TitleSummaryBuilder.buildPrimaryText(
        draft: draft,
        typeDef: typeDef,
        title: '测试资料',
      );
      expect(primaryText, '张三 · 2030-12-31');
    });

    test('4.4 buildPrimaryText: 三个白名单字段均为空时返回 title', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [ItemFieldDraftInput(fieldKey: 'title', valueText: '孤独的资料')],
      );
      final primaryText = TitleSummaryBuilder.buildPrimaryText(
        draft: draft,
        typeDef: typeDef,
        title: '孤独的资料',
      );
      expect(primaryText, '孤独的资料');
    });

    test('4.5 buildSecondaryText: generic 返回 null', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [ItemFieldDraftInput(fieldKey: 'title', valueText: '测试资料')],
      );
      final secondary = TitleSummaryBuilder.buildSecondaryText(
        draft: draft,
        typeDef: typeDef,
        primaryVal: '测试资料',
      );
      expect(secondary, isNull);
    });

    test('4.6 buildSummaryText: generic 返回空字符串', () {
      final typeDef = TemplateRegistry.getTemplate('generic')!;
      final draft = ItemDraftInput(
        memberId: 'test',
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [ItemFieldDraftInput(fieldKey: 'title', valueText: '测试资料')],
      );
      final summary = TitleSummaryBuilder.buildSummaryText(
        draft: draft,
        typeDef: typeDef,
      );
      expect(summary, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────
  // 5. 银行卡回归保护验证
  // ──────────────────────────────────────────────────
  group('银行卡 compact 头部回归验证（generic 变更不影响银行卡）', () {
    testWidgets('5.1 储蓄卡详情页不显示类型说明、badges，且无复制按钮异常', (
      WidgetTester tester,
    ) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
            ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '工资卡'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ),
            ItemFieldDraftInput(fieldKey: 'account_name', valueText: '张三'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      // 储蓄卡 compact 保持不变
      expect(find.text('类型：储蓄卡'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('储蓄卡'), findsOneWidget);

      // 复制按钮正常出现
      expect(findAnchIcon(AnchIcons.copy), findsWidgets);
    });

    testWidgets('5.2 信用卡详情页不受 generic 变更影响', (WidgetTester tester) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'credit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '工商银行'),
            ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '消费卡'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '4024000012345678',
            ),
            ItemFieldDraftInput(fieldKey: 'account_name', valueText: '李四'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pumpAndSettle();

      expect(find.text('类型：信用卡'), findsNothing);
      expect(find.text('信用卡'), findsOneWidget);
      expect(findAnchIcon(AnchIcons.copy), findsWidgets);
    });
  });
}
