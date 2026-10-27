@Tags(['security'])
library;

import 'package:anch/widgets/card_contract/anch_card_builder.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/search/search_page.dart';
import 'package:anch/features/member/member_page.dart';
import 'package:anch/features/type/type_page.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/widgets/anch_empty_state.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemUseCaseService service;

  setUp(() async {
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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    memberRepo = di.memberRepo;
    service = di.itemUseCaseService;

    // 录入一个包含完整高敏数据与 note 备注的测试资料（储蓄卡）
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId, // 系统默认成员，对应名字一般渲染为“家庭”
      categoryKey: 'card',
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-MOCK-BANK'),
        ItemFieldDraftInput(
          fieldKey: 'card_alias',
          valueText: 'TEST-MOCK-ALIAS',
        ),
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225882088881234',
        ), // 高敏字段
        ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '1234'),
        ItemFieldDraftInput(
          fieldKey: 'account_name',
          valueText: 'TEST-ACC-NAME',
        ),
        ItemFieldDraftInput(fieldKey: 'branch_name', valueText: ''),
        ItemFieldDraftInput(fieldKey: 'usage', valueText: 'TEST-LONG-USAGE'),
        ItemFieldDraftInput(fieldKey: 'is_closed', valueText: 'true'),
        ItemFieldDraftInput(
          fieldKey: 'reserved_phone',
          valueText: '13800000000',
        ), // 高敏字段
      ],
      note: 'TEST-note-secret-value', // 备注敏感字段
    );

    final res = await service.saveDraft(draft);
    expect(res.success, isTrue);
    final summary = (await di.itemRepo.getActiveItems()).single;
    expect(summary.fieldValues, {
      'bank_name': 'TEST-MOCK-BANK',
      'is_closed': 'true',
    });
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget home) {
    return wrapTest(
      MaterialApp(home: home),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  void verifyCardSafetyAndContents(WidgetTester tester) {
    // 1. 验证卡片展示了 title, 类型标签以及低敏摘要信息（如银行名与尾号）
    expect(find.byType(AnchUnifiedDataCard), findsOneWidget);

    // 详情卡片中包含 of: find.byType(AnchUnifiedDataCard)
    expect(find.textContaining('TEST-MOCK-BANK'), findsAtLeastNWidgets(1));
    expect(find.textContaining('1234'), findsAtLeastNWidgets(1));
    final card = tester.widget<AnchUnifiedDataCard>(
      find.byType(AnchUnifiedDataCard),
    );
    expect(card.title, 'TEST-MOCK-ALIAS（1234）');
    expect(card.description, '家庭 · TEST-MOCK-BANK');
    expect(find.text('已注销'), findsOneWidget);
    expect(find.textContaining('TEST-LONG-USAGE'), findsNothing);
    expect(card.description, isNot(contains('TEST-MOCK-ALIAS')));
    expect(card.description, isNot(contains('1234')));

    // 2. 验证高敏测试数据和 note 决不能出现在卡片文本中
    final List<String> allCardTexts = find
        .descendant(
          of: find.byType(AnchUnifiedDataCard),
          matching: find.byType(Text),
        )
        .evaluate()
        .map((e) => (e.widget as Text).data ?? '')
        .toList();

    final forbiddenTexts = [
      '6225882088881234',
      '13800000000',
      'TEST-note-secret-value',
    ];

    for (final cardText in allCardTexts) {
      for (final forbidden in forbiddenTexts) {
        expect(
          cardText.contains(forbidden),
          isFalse,
          reason: '卡片文案不小心泄漏了高敏信息: "$forbidden" 出现在段落 "$cardText" 中',
        );
      }
    }
  }

  group('列表卡片信息层级与低敏摘要安全性测试', () {
    testWidgets('1. 首页卡片安全性与归属名校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
      await tester.pumpAndSettle();

      // 验证卡片正常显示且包含低敏与归属
      verifyCardSafetyAndContents(tester);

      // 首页卡片 subtitle 应包含归属“家庭”
      expect(find.textContaining('家庭'), findsAtLeastNWidgets(1));
    });

    testWidgets('2. 搜索结果卡片安全性与归属名校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const SearchPage()));
      await tester.pumpAndSettle();

      // 输入关键词进行低敏搜索
      await tester.enterText(find.byType(TextField), 'TEST');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      // 验证卡片内容安全性
      verifyCardSafetyAndContents(tester);
    });

    testWidgets('3. 成员详情列表卡片安全性校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const MemberPage(isActive: true)));
      await tester.pumpAndSettle();

      // 点击进入成员下资料列表页，精确寻找 Text('家庭')
      await tester.tap(find.text('家庭'));
      await tester.pumpAndSettle();

      // 验证卡片安全性
      verifyCardSafetyAndContents(tester);
    });

    testWidgets('4. 类型详情列表卡片安全性与归属名校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const TypePage(isActive: true)));
      await tester.pumpAndSettle();

      // 点击卡片类型分类
      await tester.tap(find.text('储蓄卡'));
      await tester.pumpAndSettle();

      // 验证卡片安全性
      verifyCardSafetyAndContents(tester);

      // 包含归属“家庭”
      expect(find.textContaining('家庭'), findsAtLeastNWidgets(1));
    });

    testWidgets('5. 验证卡片上决无任何误导宣传及敏感技术名词露出', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
      await tester.pumpAndSettle();

      final List<String> allTexts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .toList();

      final forbiddenClaims = [
        '正式安全模式已启用',
        '银行级',
        '绝对安全',
        '永不泄露',
        '无法破解',
        '放心录入真实敏感',
      ];

      final forbiddenTechTerms = [
        'databaseKey',
        'backupKey',
        'Secure Storage',
        'Keystore',
        'salt',
        'verifier',
        'token',
        '/data/data/',
        'content://',
        'file://',
      ];

      for (final text in allTexts) {
        for (final claim in forbiddenClaims) {
          expect(text.contains(claim), isFalse, reason: '首页卡片中含有不合规承诺: $claim');
        }
        for (final term in forbiddenTechTerms) {
          expect(
            text.toLowerCase().contains(term.toLowerCase()),
            isFalse,
            reason: '首页卡片泄露了技术高敏词: $term',
          );
        }
      }
    });
  });

  for (final width in [320.0, 600.0, 900.0]) {
    testWidgets('实际资料卡片在 $width 宽度与大字体下保留标题、置顶和低敏摘要', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = AnchCardBuilder.item(
        ItemModel(
          id: 'mock-layout',
          templateVersion: 1,
          typeKey: 'id_card',
          title: '超长虚构标题' * 8,
          summaryText: '测试低敏摘要',
          note: 'MOCK private note',
          fieldValues: {'id_number': 'MOCK private number'},
          isPinned: true,
          isFavorite: false,
          sortOrder: 0,
          status: 'active',
          createdAt: 0,
          updatedAt: 0,
        ),
        memberName: '家庭',
        now: DateTime(2026, 7, 3),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: AnchUnifiedDataCard(model: model, onTap: () {}),
            ),
          ),
        ),
      );
      expect(find.text('超长虚构标题' * 8), findsOneWidget);
      expect(find.text('家庭 · 身份证 · 测试低敏摘要'), findsOneWidget);
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('常用'), findsNothing);
      expect(find.textContaining('MOCK private'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  group('列表多页面一致性测试', () {
    testWidgets('1. 验证 HomePage 列表展示与三层结构一致性', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '测试信用卡',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      expect(find.text('测试信用卡'), findsOneWidget);
      expect(find.text('家庭 · 测试银行'), findsOneWidget);
    });

    testWidgets('2. 验证 TypeItemsPage 列表展示一致性', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '测试信用卡 2',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行 2'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567892',
          ),
        ],
      );
      await service.saveDraft(draft);

      final catDef = TemplateRegistry.getTemplate('credit_card')!;
      await tester.pumpWidget(buildTestApp(TypeItemsPage(type: catDef)));
      await tester.pumpAndSettle();

      expect(find.text('测试信用卡 2'), findsOneWidget);
      expect(find.text('家庭 · 测试银行 2'), findsOneWidget);
    });

    testWidgets('3. 验证 MemberItemsPage 列表展示一致性', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '测试信用卡 3',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行 3'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567893',
          ),
        ],
      );
      await service.saveDraft(draft);

      final members = await memberRepo.getActiveMembers();
      final member = members.first;

      await tester.pumpWidget(buildTestApp(MemberItemsPage(member: member)));
      await tester.pumpAndSettle();

      expect(find.text('测试信用卡 3'), findsOneWidget);
      expect(find.text('家庭 · 测试银行 3'), findsOneWidget);
    });

    testWidgets('4. 验证 SearchPage 高亮与解耦展示一致性', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '搜索关键字ABC',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试关键字XYZ'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567894',
          ),
        ],
      );
      await service.saveDraft(draft);

      await tester.pumpWidget(buildTestApp(const SearchPage()));
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, '关键字');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));

      Finder findTextOrRichText(String text) {
        return find.byWidgetPredicate((widget) {
          if (widget is Text) {
            if (widget.data?.contains(text) == true) return true;
            if (widget.textSpan?.toPlainText().contains(text) == true) {
              return true;
            }
          }
          return false;
        });
      }

      expect(findTextOrRichText('搜索关键字ABC'), findsOneWidget);
      expect(findTextOrRichText('测试关键字XYZ'), findsOneWidget);
      expect(find.text('家庭 · 测试关键字XYZ'), findsOneWidget);
    });

    testWidgets('5. 验证空状态文案与安全说明边界，不诱导录入真实敏感数据', (WidgetTester tester) async {
      final activeItems = await service.itemRepo.getActiveItems();
      for (final item in activeItems) {
        await service.deleteItem(item.id);
      }

      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      expect(find.text('暂无资料'), findsOneWidget);
      expect(find.textContaining('开发验证模式'), findsOneWidget);
      expect(find.textContaining('通过搜索或添加资料开始使用'), findsOneWidget);
      expect(find.textContaining('放心录入'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AnchEmptyState),
          matching: find.textContaining('真实敏感资料'),
        ),
        findsNothing,
      );
    });

    testWidgets('6. 卡片到期 Badge 渲染与安全校验：即将到期、已过期、正常不显示，低敏不泄露', (
      WidgetTester tester,
    ) async {
      final expiredDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '我的过期护照',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-PASSPORT-EXP-999',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-07-01',
          ), // 过期
        ],
      );
      final expiredRes = await service.saveDraft(expiredDraft);
      expect(expiredRes.success, isTrue);

      final upcomingDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '我的即将到期护照',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-PASSPORT-UPC-888',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-07-15',
          ), // 即将到期
        ],
      );
      final upcomingRes = await service.saveDraft(upcomingDraft);
      expect(upcomingRes.success, isTrue);

      final normalDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'passport',
        title: '我的正常护照',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'passport_number',
            valueText: 'GALAXY-PASSPORT-NOR-777',
          ),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: '2026-09-01',
          ), // 正常
        ],
      );
      final normalRes = await service.saveDraft(normalDraft);
      expect(normalRes.success, isTrue);

      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      // 过期护照卡片验证
      expect(find.text('我的过期护照'), findsOneWidget);
      expect(find.text('已过期'), findsOneWidget);

      // 即将到期护照卡片验证
      expect(find.text('我的即将到期护照'), findsOneWidget);
      expect(find.text('即将到期'), findsOneWidget);

      // 正常护照卡片验证
      expect(find.text('我的正常护照'), findsOneWidget);
      // 不应渲染出即将到期/已过期/今日到期的 badge
      final listTextFinders = find
          .descendant(
            of: find.ancestor(
              of: find.text('我的正常护照'),
              matching: find.byType(AnchUnifiedDataCard),
            ),
            matching: find.byType(Text),
          )
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '');
      expect(listTextFinders.contains('已过期'), isFalse);
      expect(listTextFinders.contains('即将到期'), isFalse);

      // 安全校验：到期 badge 不应泄露护照号码高敏值
      final allCardTextList = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '');
      for (final txt in allCardTextList) {
        expect(txt.contains('GALAXY-PASSPORT'), isFalse);
      }
    });
  });
}
