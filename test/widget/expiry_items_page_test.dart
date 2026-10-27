import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/features/expiry/expiry_items_page.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/core/theme/anch_colors.dart';
import '../support/test_bootstrap.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;

  setUp(() {
    TemplateRegistry.showAllTemplatesForTesting = true;
    ItemGlobalRegistry.instance.clear();
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
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 7, 3)),
      child: Container(),
    );
    db = di.db;
  });

  tearDown(() async {
    TemplateRegistry.showAllTemplatesForTesting = false;
    await db.close();
  });

  Widget buildTestWidget() {
    return wrapTest(
      const AnchApp(),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  testWidgets(
    'Expiry Overview Card and ExpiryItemsPage UI Flow & Privacy Safety Test',
    (WidgetTester tester) async {
      // 1. 无任何资料到期时，首页不应展示概览卡片
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('资料需要关注'), findsNothing);

      // 2. 插入一条已过期的护照资料和一条未过期的护照资料
      final members = await di.memberRepo.getActiveMembers();
      final familyMemberId = members.first.id;

      // 已过期护照资料 (带有测试高敏感词和备注)
      final expiredDraft = ItemDraftInput(
        memberId: familyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '家庭护照',
        note: '绝密内部备注NOTE12345，含有密钥秘密TOPSECRET',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-EXP-99999',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-07-02',
          ), // 相比 2026-07-03 已过期 1 天
        ],
      );
      await di.itemUseCaseService.saveDraft(expiredDraft);

      // 远期未到期护照资料
      final normalDraft = ItemDraftInput(
        memberId: familyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '普通护照',
        note: '无敏感备注',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-NORM-00000',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-08-30',
          ), // 远期正常
        ],
      );
      await di.itemUseCaseService.saveDraft(normalDraft);

      // 3. 再次泵入首页，检查概览卡片出现，并验证文案只显示数量，无敏感信息泄露
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expiry_overview_card')), findsOneWidget);
      expect(find.textContaining('已过期 1 条'), findsOneWidget);

      // 严格安全断言：首页概览卡片不能泄露标题、备注、卡号字段值
      final homeOverviewCardFinder = find.byKey(
        const Key('expiry_overview_card'),
      );
      expect(
        find.descendant(
          of: homeOverviewCardFinder,
          matching: find.textContaining('绝密个人护照'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: homeOverviewCardFinder,
          matching: find.textContaining('TOPSECRET'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: homeOverviewCardFinder,
          matching: find.textContaining('NOTE12345'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: homeOverviewCardFinder,
          matching: find.textContaining('GALAXY-EXP'),
        ),
        findsNothing,
      );

      // 4. 点击概览卡片，跳转到到期资料列表页
      await tester.tap(find.byKey(const Key('expiry_overview_card')));
      await tester.pumpAndSettle();

      // 验证到达“到期资料”页
      expect(find.text('到期资料'), findsOneWidget);
      expect(find.text('到期状态仅在安册内显示，不会发送系统通知。'), findsOneWidget);
      expect(find.text('已过期'), findsNWidgets(2));

      // 5. 严格安全断言：到期列表页复用现有卡片，也必须不展示 note、高敏字段明文、完整卡号/证件号、密钥等高敏隐私信息
      expect(find.textContaining('NOTE12345'), findsNothing);
      expect(find.textContaining('绝密内部备注'), findsNothing);
      expect(
        find.textContaining('GALAXY-EXP-99999'),
        findsNothing,
      ); // 不能出现完整证件号
      expect(find.textContaining('TOPSECRET'), findsNothing);

      // 6. 点击列表中的卡片，进入详情页
      await tester.tap(find.byType(AnchUnifiedDataCard));
      await tester.pumpAndSettle();

      // 应该顺利到达详情页；头部保留简洁状态标签，不再重复展示整条提示
      expect(find.text('已过期'), findsOneWidget);
      expect(find.text('已过期，请更新有效期'), findsNothing);

      // 7. 返回到期列表页
      Navigator.of(tester.element(find.text('已过期'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('到期资料'), findsOneWidget);
    },
  );

  testWidgets('ExpiryItemsPage Empty State Rendering Test', (
    WidgetTester tester,
  ) async {
    // 渲染没有到期资料下的 ExpiryItemsPage，验证空状态文案
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpiryItemsPage(
            items: const [],
            memberNameById: const {},
            now: DateTime(2026, 7, 3),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('暂无到期资料'), findsOneWidget);
    expect(find.text('暂无即将到期的资料'), findsOneWidget);
  });

  testWidgets(
    'Visual Expiry Levels Test: 2 days vs 20 days vs expired colors',
    (WidgetTester tester) async {
      final members = await di.memberRepo.getActiveMembers();
      final familyMemberId = members.first.id;

      // 1. 只有即将到期，20天内到期 -> 首页概览卡片应为 warning 金黄色风格
      final upcoming20Draft = ItemDraftInput(
        memberId: familyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '即将到期20天',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-EXP-20202',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-07-23',
          ), // 相比 2026-07-03 为 20 天
        ],
      );
      await di.itemUseCaseService.saveDraft(upcoming20Draft);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final homeCardFinder = find.byKey(const Key('expiry_overview_card'));
      expect(homeCardFinder, findsOneWidget);
      final overviewButton = tester.widget<TextButton>(
        find.descendant(of: homeCardFinder, matching: find.byType(TextButton)),
      );
      final colors = tester.element(homeCardFinder).anchColors;
      expect(
        overviewButton.style?.foregroundColor?.resolve({}),
        colors.textSecondary,
      );
      expect(find.text('1 份将到期'), findsOneWidget);

      // 进入到期列表页
      await tester.tap(homeCardFinder);
      await tester.pumpAndSettle();

      // 列表中此 20 天到期卡片 Badge 检查：应使用 warningSoft 背景和 warning 文字
      final card20Finder = find.byType(AnchUnifiedDataCard);
      expect(card20Finder, findsOneWidget);

      final badgeContainerFinder = find.descendant(
        of: card20Finder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == colors.warningSoft,
        ),
      );
      expect(badgeContainerFinder, findsOneWidget);

      final badgeTextFinder = find.descendant(
        of: badgeContainerFinder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text && w.style?.color == colors.warning && w.data == '即将到期',
        ),
      );
      expect(badgeTextFinder, findsOneWidget);
      expect(find.text('30 天内到期'), findsOneWidget);

      // 返回首页
      Navigator.of(tester.element(find.text('到期资料'))).pop();
      await tester.pumpAndSettle();

      // 清空数据库重新写入
      await db.delete(db.items).go();
      ItemGlobalRegistry.instance.clear();

      // 2. 只有即将到期，2天内到期 -> 首页概览卡片应为 error 红色风格
      final upcoming2Draft = ItemDraftInput(
        memberId: familyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '即将到期2天',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-EXP-02020',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-07-05',
          ), // 相比 2026-07-03 为 2 天
        ],
      );
      await di.itemUseCaseService.saveDraft(upcoming2Draft);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final homeCardFinder2 = find.byKey(const Key('expiry_overview_card'));
      final overviewButton2 = tester.widget<TextButton>(
        find.descendant(of: homeCardFinder2, matching: find.byType(TextButton)),
      );
      expect(
        overviewButton2.style?.foregroundColor?.resolve({}),
        colors.danger,
      );

      // 进入到期列表页
      await tester.tap(homeCardFinder2);
      await tester.pumpAndSettle();

      // 列表中此 2 天到期卡片 Badge 检查：应使用 warnSoft 背景和 warn 文字
      final card2Finder = find.byType(AnchUnifiedDataCard);
      final badgeContainerFinder2 = find.descendant(
        of: card2Finder,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == colors.dangerSoft,
        ),
      );
      expect(badgeContainerFinder2, findsOneWidget);

      final badgeTextFinder2 = find.descendant(
        of: badgeContainerFinder2,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.style?.color == colors.danger &&
              w.data == '剩余 2 天',
        ),
      );
      expect(badgeTextFinder2, findsOneWidget);
      expect(find.text('7 天内到期'), findsOneWidget);
    },
  );
}
