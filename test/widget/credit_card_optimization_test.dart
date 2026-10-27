import 'package:anch/widgets/card_contract/anch_card_builder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/template/builtin_templates.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/widgets/card_contract/anch_card_model.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/core/theme/anch_colors.dart';

import '../support/anch_icon_finder.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;
  String? copiedText;

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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
    copiedText = null;
  });

  tearDown(() async {
    await db.close();
  });

  void setupMockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = methodCall.arguments['text'] as String?;
          return null;
        }
        return null;
      },
    );
  }

  Widget buildEntryPage() {
    return wrapTest(
      MaterialApp(home: const ItemEntryFlowPage()),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Widget buildDetailPage(String itemId) {
    return wrapTest(
      MaterialApp(home: ItemDetailPage(itemId: itemId)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Widget buildHomePage() {
    return wrapTest(
      MaterialApp(home: const HomePage(isActive: true)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('信用卡 TitleSummaryBuilder 规则测试', () {
    final typeDef = BuiltinTemplates.types.firstWhere(
      (t) => t.typeKey == 'credit_card',
    );

    test('1. CardAlias and CardNumber -> CardAlias(last4)', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '我的小黑卡'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '我的小黑卡（7890）');
    });

    test('2. CardAlias only -> CardAlias', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '我的小黑卡'),
        ],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '我的小黑卡');
    });

    test('3. BankName and CardNumber -> BankName(last4)', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '招商银行（7890）');
    });

    test('4. BankName only -> BankName信用卡', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行')],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '招商银行信用卡');
    });

    test('5. CardNumber only -> 信用卡(last4)', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '信用卡（7890）');
    });

    test('6. Neither -> 信用卡', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );
      expect(title, '信用卡');
    });

    test('7. Primary text format', () {
      final item = ItemModel(
        id: 'test-id',
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        templateVersion: 1,
        isPinned: false,
        isFavorite: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        title: '招商银行',
        primaryText: '招商银行 · Visa',
        secondaryText: null,
        repaymentDay: '25',
      );
      final model = AnchCardBuilder.item(
        item,
        now: DateTime(2026, 7, 3),
        memberName: '家庭',
      );
      expect(model.title, '招商银行');
      expect(model.description, '家庭 · Visa');
      expect(model.repaymentDayBadge, '还款 25日');
    });
  });

  group('信用卡录入页表单布局与 Helper 提示测试', () {
    testWidgets('1. card_network 提示可换行且与输入框左边对齐', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildEntryPage());
      await tester.pumpAndSettle();

      await openEntryFields(tester, find.text('信用卡'));
      await tester.pumpAndSettle();

      // 验证表单填写页
      expect(find.text('填写核心信息'), findsOneWidget);

      for (final fieldKey in ['bill_day', 'repayment_day', 'valid_until']) {
        final calendar = find.descendant(
          of: find.byKey(Key('item_field_control_$fieldKey')),
          matching: findAnchIcon(AnchIcons.calendar),
        );
        expect(calendar, findsOneWidget);
        expect(tester.widget<AnchIcon>(calendar).size, 16);
      }

      // 验证三大旧分组不显示
      expect(find.text('卡片信息'), findsNothing);
      expect(find.text('账单与还款'), findsNothing);
      expect(find.text('额度与状态'), findsNothing);

      // 验证已删除废弃字段没有显示
      expect(find.textContaining('尾号'), findsNothing);
      expect(find.textContaining('预留手机'), findsNothing);
      expect(find.textContaining('还款账户'), findsNothing);

      final inputFinder = find.byKey(
        const Key('item_field_control_card_network'),
      );
      final helperFinder = find.byKey(
        const Key('item_field_helper_card_network'),
      );
      final helperText = tester.widget<Text>(helperFinder);

      expect(helperText.data, equals('银联、Visa、Mastercard 等'));
      expect(helperText.softWrap, isTrue);
      expect(helperText.maxLines, isNull);
      expect(helperText.style?.fontSize, 12);
      expect(
        tester.getRect(helperFinder).left,
        equals(tester.getRect(inputFinder).left),
      );
    });
  });

  group('信用卡详情页分组、复制动作与 Compact Header 测试', () {
    testWidgets('1. 详情页三分组、删除防御过滤及头部复制按钮选项测试', (WidgetTester tester) async {
      setupMockClipboard(tester);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '我的测试信用卡',
        note: '这是测试信用卡详情',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '金卡'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'account_name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'card_network',
            valueText: 'Mastercard',
          ),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2030-05'),
          ItemFieldDraftInput(fieldKey: 'bill_day', valueText: '5'),
          ItemFieldDraftInput(fieldKey: 'repayment_day', valueText: '23'),
          ItemFieldDraftInput(fieldKey: 'credit_limit', valueText: '100000'),
          ItemFieldDraftInput(fieldKey: 'annual_fee_note', valueText: '终身免年费'),
          // 历史废弃字段 (测试防御过滤)
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13988888888',
          ),
          ItemFieldDraftInput(
            fieldKey: 'repayment_account',
            valueText: '123456',
          ),
        ],
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildDetailPage(itemId));
      await tester.pumpAndSettle();

      // 验证 compact header 属性
      expect(find.text('我的测试信用卡'), findsOneWidget);
      expect(find.textContaining('家庭'), findsOneWidget);
      expect(find.text('信用卡'), findsOneWidget);
      expect(find.text('类型：信用卡'), findsNothing);

      // 验证防爆/防漏过滤
      expect(find.text('预留手机号'), findsNothing);
      expect(find.text('还款账户'), findsNothing);
      expect(find.text('尾号'), findsNothing);

      // 验证 dayOfMonth 转换
      expect(find.text('每月 23 日'), findsOneWidget);

      // 验证头部复制按钮交互
      final copyBtn = find.byKey(const Key('credit_card_header_copy'));
      expect(copyBtn, findsOneWidget);

      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      // 验证底部菜单弹出
      expect(find.text('选择复制内容'), findsNothing);
      expect(find.text('仅复制卡号'), findsOneWidget);
      expect(find.text('复制完整信息'), findsOneWidget);

      // 测试复制完整信息只包含特定字段
      await tester.tap(find.text('复制完整信息'));
      await tester.pumpAndSettle();

      // 触发高敏复制弹窗
      expect(find.text('确认复制敏感字段？'), findsOneWidget);
      // 确认弹窗有预览值
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('户名：张三'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('卡号：6225881234567890'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('银行：招商银行'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('有效期：2030-05'), findsNothing);
      // 不应包含额度或卡组织或年费
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('100000'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Mastercard'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('终身免年费'),
        ),
        findsNothing,
      );

      // 确认复制
      await tester.tap(find.text('确认复制'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final expectedCopyText = '户名：张三\n卡号：6225881234567890\n银行：招商银行';
      expect(copiedText, equals(expectedCopyText));
    });
  });

  group('信用卡卡片徽标及双标签展示测试', () {
    testWidgets('已注销信用卡详情优先展示已注销状态且不再提示已过期', (tester) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'credit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '虚构银行'),
            ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '虚构历史卡'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ),
            ItemFieldDraftInput(
              fieldKey: 'valid_until',
              valueText: '2020-01-01',
            ),
            ItemFieldDraftInput(fieldKey: 'is_closed', valueText: 'true'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(buildDetailPage(result.itemId!));
      await tester.pumpAndSettle();

      expect(find.text('已注销'), findsWidgets);
      expect(find.text('已过期'), findsNothing);
      expect(find.text('已过期，请更新有效期'), findsNothing);
      expect(find.text('6225881234567890'), findsNothing);
    });

    testWidgets('0. 已保存信用卡在列表卡片中间展示账单日和还款日', (WidgetTester tester) async {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'credit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '虚构银行'),
            ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '虚构日常信用卡'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ),
            ItemFieldDraftInput(fieldKey: 'bill_day', valueText: '8'),
            ItemFieldDraftInput(fieldKey: 'repayment_day', valueText: '12'),
          ],
        ),
      );
      expect(result.success, isTrue);

      await tester.pumpWidget(buildHomePage());
      await tester.pumpAndSettle();

      expect(find.text('虚构日常信用卡（7890）'), findsOneWidget);
      expect(find.text('账单 8日'), findsOneWidget);
      expect(find.text('还款 12日'), findsOneWidget);
      expect(find.byKey(const Key('bank_card_day_badges')), findsOneWidget);
    });

    testWidgets('1. 账单日与还款日双全：在标题与描述之间展示双标签，副标题无日期', (
      WidgetTester tester,
    ) async {
      final cardModel = AnchCardModel(
        title: 'TEST-招商银行（7890）',
        description: '家庭 · TEST-招商银行 · Visa',
        icon: AnchIcons.creditCard,
        tag: '信用卡',
        billDayBadge: '账单 8日',
        repaymentDayBadge: '还款 12日',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchUnifiedDataCard(model: cardModel, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证双标签并排渲染
      expect(find.text('账单 8日'), findsOneWidget);
      expect(find.text('还款 12日'), findsOneWidget);
      expect(find.byKey(const Key('bank_card_day_badges')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('TEST-招商银行（7890）')).dy,
        lessThan(tester.getTopLeft(find.text('账单 8日')).dy),
      );
      expect(
        tester.getTopLeft(find.text('账单 8日')).dy,
        lessThan(tester.getTopLeft(find.text('家庭 · TEST-招商银行 · Visa')).dy),
      );

      final colors = tester.element(find.text('账单 8日')).anchColors;
      final billText = tester.widget<Text>(find.text('账单 8日'));
      expect(billText.style?.color, equals(colors.accentDeep));

      final repaymentText = tester.widget<Text>(find.text('还款 12日'));
      expect(repaymentText.style?.color, equals(colors.danger));

      // 验证副标题
      expect(find.text('家庭 · TEST-招商银行 · Visa'), findsOneWidget);
      expect(find.textContaining('还款日'), findsNothing);
      expect(find.textContaining('账单日'), findsNothing);
    });

    testWidgets('2. 只有账单日时只显示账单标签，不显示还款标签', (WidgetTester tester) async {
      final cardModel = AnchCardModel(
        title: 'TEST-招商银行（7890）',
        description: '家庭 · TEST-招商银行 · Visa',
        icon: AnchIcons.creditCard,
        billDayBadge: '账单 8日',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchUnifiedDataCard(model: cardModel, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('账单 8日'), findsOneWidget);
      expect(find.textContaining('还款'), findsNothing);
    });

    testWidgets('3. 只有还款日时只显示还款标签，不显示账单标签', (WidgetTester tester) async {
      final cardModel = AnchCardModel(
        title: 'TEST-招商银行（7890）',
        description: '家庭 · TEST-招商银行 · Visa',
        icon: AnchIcons.creditCard,
        repaymentDayBadge: '还款 12日',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchUnifiedDataCard(model: cardModel, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('还款 12日'), findsOneWidget);
      expect(find.textContaining('账单'), findsNothing);
    });

    testWidgets('4. 两者皆无时不展示任何标签区域', (WidgetTester tester) async {
      final cardModel = AnchCardModel(
        title: 'TEST-招商银行（7890）',
        description: '家庭 · TEST-招商银行 · Visa',
        icon: AnchIcons.creditCard,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnchUnifiedDataCard(model: cardModel, onTap: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('账单'), findsNothing);
      expect(find.textContaining('还款'), findsNothing);
    });

    test('5. 标题物理防泄露校验：不泄露完整卡号且不带“尾号”字样', () {
      final typeDef = BuiltinTemplates.types.firstWhere(
        (t) => t.typeKey == 'credit_card',
      );
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final title = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '家庭',
      );

      expect(title, equals('TEST-招商银行（7890）'));
      expect(title.contains('6225881234567890'), isFalse);
      expect(title.contains('尾号'), isFalse);
    });
  });
}
