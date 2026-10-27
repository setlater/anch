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
import 'package:anch/features/search/search_page.dart';
import '../contracts/contract_extractor.dart';
import '../contracts/contract_test_runner.dart';

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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return wrapTest(
      const MaterialApp(home: SearchPage()),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  testWidgets('验证搜索关键词命中高亮及各项合规边界', (WidgetTester tester) async {
    // 1. 保存一条测试数据
    // 包含 title (张三的测试储蓄卡), primaryText (招商银行), secondaryText (7890), note (秘密备注)
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      title: '张三的测试储蓄卡',
      note: '秘密备注，不应公开展示于搜索页',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
        ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);

    // 2. 渲染搜索页
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 初始状态，展示引导信息
    expect(find.text('输入关键词，查找已整理的资料'), findsOneWidget);

    // 3. 搜索 "测试" (命中 title "张三的测试储蓄卡")
    await tester.enterText(find.byType(TextField), '测试');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract1 = ContractExtractor.fromListItem(tester);
    ContractTestRunner.verify(
      contract1,
      expectedHasHighlight: true,
      expectedHasEmptyState: false,
    );

    // 4. 搜索 "招商" (命中 primaryText "招商银行")
    await tester.enterText(find.byType(TextField), '招商');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract2 = ContractExtractor.fromListItem(tester);
    ContractTestRunner.verify(
      contract2,
      expectedHasHighlight: true,
      expectedHasEmptyState: false,
    );

    // 5. 搜索 "7890" (命中 secondaryText "7890")
    await tester.enterText(find.byType(TextField), '7890');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract3 = ContractExtractor.fromListItem(tester);
    ContractTestRunner.verify(
      contract3,
      expectedHasHighlight: true,
      expectedHasEmptyState: false,
    );

    // 6. 不命中字段不高亮校验：搜索 "五六" (无命中)
    await tester.enterText(find.byType(TextField), '五六');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract4 = ContractExtractor.fromListItem(tester);
    ContractTestRunner.verify(
      contract4,
      expectedHasHighlight: false,
      expectedHasEmptyState: true,
      expectedEmptyStateType: '暂无资料',
    );

    // 7. 防错断言：搜索 "家庭" (命中 memberName) 或 "储蓄卡" (类型名)
    // 即使被模糊匹配，但由于 memberName / typeLabel 不参与高亮匹配判定，它们的段落不应发生高亮
    await tester.enterText(find.byType(TextField), '家庭');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract5 = ContractExtractor.fromListItem(tester);
    if (!contract5.hasEmptyState) {
      ContractTestRunner.verify(contract5, expectedHasHighlight: false);
    }

    // 8. 确保 note / 高敏字段在搜索结果中完全不可渲染，并且不能被高亮
    // 我们搜索关键字 "秘密"
    await tester.enterText(find.byType(TextField), '秘密');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract6 = ContractExtractor.fromListItem(tester);
    expect(contract6.hasEmptyState, isTrue);

    // 我们搜索高敏身份证字段里的 "1234"
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    final contract7 = ContractExtractor.fromListItem(tester);
    expect(contract7.hasEmptyState, isTrue);

    // 9. 确保没有误导性安全文案
    final allWidgets = tester.allWidgets;
    for (final widget in allWidgets) {
      if (widget is Text) {
        final text = widget.data ?? '';
        expect(text.contains('正式安全模式'), isFalse);
        expect(text.contains('绝对安全'), isFalse);
        expect(text.contains('银行级安全'), isFalse);
      }
    }
  });

  testWidgets('搜索结果可按本地状态、成员与类型收窄', (WidgetTester tester) async {
    final pinned = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '筛选用置顶储蓄卡',
        isPinned: true,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '筛选银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6222000012345678',
          ),
        ],
      ),
    );
    final selfCreditCard = await service.saveDraft(
      ItemDraftInput(
        memberId: systemMeMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '筛选用本人信用卡',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '筛选信用银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6222000012341234',
          ),
        ],
      ),
    );
    expect(pinned.success, isTrue);
    expect(selfCreditCard.success, isTrue);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '筛选用');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('search_filter_toggle')));
    await tester.pumpAndSettle();

    final pinnedFilter = find.widgetWithText(FilterChip, '已置顶');
    final familyFilter = find.widgetWithText(FilterChip, '家庭');
    final selfFilter = find.widgetWithText(FilterChip, '我');
    expect(pinnedFilter, findsOneWidget);
    expect(find.widgetWithText(FilterChip, '常用'), findsNothing);
    expect(familyFilter, findsOneWidget);
    expect(selfFilter, findsOneWidget);
    expect(find.widgetWithText(FilterChip, '储蓄卡'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, '信用卡'), findsOneWidget);

    await tester.tap(pinnedFilter);
    await tester.pumpAndSettle();
    expect(find.text('筛选用置顶储蓄卡（5678）'), findsOneWidget);
    expect(find.text('筛选用本人信用卡'), findsNothing);

    await tester.tap(pinnedFilter);
    await tester.tap(selfFilter);
    await tester.pumpAndSettle();
    expect(find.text('筛选用置顶储蓄卡（5678）'), findsNothing);
    expect(find.text('筛选用本人信用卡'), findsOneWidget);
  });

  testWidgets('搜索结果可按已到期状态收窄', (WidgetTester tester) async {
    final expired = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '到期筛选护照',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'TEST-EXPIRED',
          ),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2020-01-01'),
        ],
      ),
    );
    final normal = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '有效筛选护照',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'TEST-NORMAL',
          ),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2099-01-01'),
        ],
      ),
    );
    expect(expired.success, isTrue);
    expect(normal.success, isTrue);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '筛选护照');
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('search_filter_toggle')));
    await tester.pumpAndSettle();

    final expiredFilter = find.widgetWithText(FilterChip, '已到期');
    expect(expiredFilter, findsOneWidget);
    await tester.tap(expiredFilter);
    await tester.pumpAndSettle();
    expect(find.text('到期筛选护照'), findsOneWidget);
    expect(find.text('有效筛选护照'), findsNothing);
  });
}
