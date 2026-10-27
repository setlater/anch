import 'package:anch/widgets/card_contract/anch_card_builder.dart';
import 'dart:convert';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/time/time_domain_source.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemRepository itemRepo;
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
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> setupScreenSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  group('保险资料优化专项测试 - 第二阶段', () {
    testWidgets('1. 编辑/录入页展示 11 个核心字段，不展示折叠区及已删除字段(含缴费日、保单状态)', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);

      // 渲染编辑页面 (新增模式)
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: ItemEntryFlowPage()),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 前往资料类型选择并选择保险资料
      await openEntryFields(tester, find.text('保险资料').last);
      await tester.pumpAndSettle();

      // 验证 11 个核心字段的标签都被渲染在页面上
      expect(find.textContaining('保险公司'), findsOneWidget);
      expect(find.textContaining('保单名称'), findsOneWidget);
      expect(find.textContaining('保单号'), findsOneWidget);
      expect(find.textContaining('保险类型'), findsOneWidget);
      expect(find.textContaining('投保人'), findsOneWidget);
      expect(find.textContaining('保障对象'), findsOneWidget);
      expect(find.textContaining('起保日期'), findsOneWidget);
      expect(find.textContaining('到期日期'), findsOneWidget);
      expect(find.textContaining('保费'), findsOneWidget);
      expect(find.textContaining('保额'), findsOneWidget);
      expect(find.textContaining('客服电话'), findsOneWidget);

      // 验证没有“补充信息”折叠区
      expect(find.text('补充信息'), findsNothing);

      // 验证已被删除的历史字段不显示，特别是新增的 缴费日、保单状态
      expect(find.textContaining('缴费日'), findsNothing);
      expect(find.textContaining('保单状态'), findsNothing);
      expect(find.textContaining('受益人'), findsNothing);
      expect(find.textContaining('缴费期间'), findsNothing);
      expect(find.textContaining('缴费频率'), findsNothing);
      expect(find.textContaining('代理人'), findsNothing);
    });

    testWidgets('2. 详情页四组显示、头部 compact 清理与历史旧数据防御过滤', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);

      // 1. 模拟写入一个包含所有废弃旧字段的历史数据
      final serviceResult = await service.saveDraft(
        ItemDraftInput(
          memberId: '00000000-0000-4000-8000-000000000001',
          categoryKey: 'insurance',
          typeKey: 'insurance',
          fields: [
            ItemFieldDraftInput(
              fieldKey: 'policy_name',
              valueText: 'TEST-POLICY-OLD',
            ),
            ItemFieldDraftInput(
              fieldKey: 'policy_number',
              valueText: 'TEST-NUMBER-OLD',
            ),
            ItemFieldDraftInput(
              fieldKey: 'beneficiary',
              valueText: 'TEST-BENEFICIARY-OLD',
            ),
            ItemFieldDraftInput(
              fieldKey: 'agent_name',
              valueText: 'TEST-AGENT-OLD',
            ),
            ItemFieldDraftInput(
              fieldKey: 'insurance_company',
              valueText: 'TEST-COMPANY',
            ),
            ItemFieldDraftInput(
              fieldKey: 'insured_person',
              valueText: 'TEST-INSURED',
            ),
            ItemFieldDraftInput(
              fieldKey: 'coverage_amount',
              valueText: '100000.00',
            ),
            ItemFieldDraftInput(fieldKey: 'payment_day', valueText: '15'),
            ItemFieldDraftInput(fieldKey: 'policy_status', valueText: '有效'),
          ],
        ),
      );
      expect(serviceResult.success, isTrue);
      final itemId = serviceResult.itemId!;

      // 2. 渲染详情页
      final loadedItem = await itemRepo.getItemWithFields(itemId);
      expect(loadedItem, isNotNull);

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: ItemDetailPage(itemId: itemId)),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 3. 验证详情页呈现了有效的核心字段
      // TEST-POLICY-OLD 只出现在详情页头部标题，不会在字段行中重复出现（因为 policy_name 是标识字段不作为行字段展示，或只在 header 展示）
      // 实际上，policy_name 会展示在保单名称行，所以头部标题一次 + 字段行一次 = 2次。
      expect(find.text('TEST-POLICY-OLD'), findsNWidgets(2));
      expect(find.text('TEST-COMPANY'), findsOneWidget);
      // TEST-INSURED 现在由于头部取消了副标题摘要串，仅在字段行出现一次！
      expect(find.text('TEST-INSURED'), findsOneWidget);

      // 5. 验证详情页已成功过滤并隐藏历史旧字段（含新增删除的缴费日、保单状态）
      expect(find.text('TEST-BENEFICIARY-OLD'), findsNothing);
      expect(find.text('TEST-AGENT-OLD'), findsNothing);
      expect(find.text('15'), findsNothing);
      expect(find.text('有效'), findsNothing);

      // 6. 验证详情页头部 compact 渲染
      // 保留：左上角类型标签和成员归属，主标题
      expect(find.text('保险资料'), findsOneWidget); // 类型小标签
      expect(find.textContaining('家庭'), findsOneWidget); // 成员归属
      // 移除：技术标签、类型 subtitle、副标题摘要串、低敏摘要容器
      expect(find.text('类型：保险资料'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('默认脱敏'), findsNothing);
      expect(find.text('可复制字段'), findsNothing);
      expect(find.text('可在详情页查看完整资料'), findsNothing);
    });

    test('3. TitleSummaryBuilder 保存时的低敏摘要拼接规则（仅限3项）', () {
      final typeDef = TemplateRegistry.getTemplate('insurance');

      // 验证 Title 生成规则
      final draft = ItemDraftInput(
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'insurance',
        typeKey: 'insurance',
        fields: [
          ItemFieldDraftInput(fieldKey: 'policy_name', valueText: '意外健康险'),
          ItemFieldDraftInput(fieldKey: 'insurance_company', valueText: '平安保险'),
        ],
      );
      final title1 = TitleSummaryBuilder.buildTitle(
        draft: draft,
        typeDef: typeDef,
        memberName: '',
      );
      expect(title1, '意外健康险');

      final draft2 = ItemDraftInput(
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'insurance',
        typeKey: 'insurance',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'insurance_company',
            valueText: '太平洋保险',
          ),
        ],
      );
      final title2 = TitleSummaryBuilder.buildTitle(
        draft: draft2,
        typeDef: typeDef,
        memberName: '',
      );
      expect(title2, '太平洋保险保险资料');

      // 验证 PrimaryText（低敏摘要）只使用 3 项白名单字段，且过滤 policy_status 等已删除字段
      final draft3 = ItemDraftInput(
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'insurance',
        typeKey: 'insurance',
        fields: [
          ItemFieldDraftInput(fieldKey: 'insurance_type', valueText: '寿险'),
          ItemFieldDraftInput(fieldKey: 'insured_person', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'end_date', valueText: '2026-12-31'),
          ItemFieldDraftInput(
            fieldKey: 'policy_status',
            valueText: '有效',
          ), // 已删除
          ItemFieldDraftInput(fieldKey: 'payment_day', valueText: '10'), // 已删除
        ],
      );
      final primaryText = TitleSummaryBuilder.buildPrimaryText(
        draft: draft3,
        typeDef: typeDef,
        title: '保险资料',
      );
      expect(primaryText, '寿险 · 张三 · 2026-12-31');
    });

    test('4. 实际保险卡片只展示低敏摘要，排除保障对象与历史废弃字段', () {
      // 模拟一个包含所有历史已删除字段的旧数据（包括 primaryText）
      final oldItem = ItemModel(
        id: 'old-item-1',
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'insurance',
        typeKey: 'insurance',
        templateVersion: 1,
        title: '测试保单',
        // 数据库旧 primaryText 包含已删除的字段
        primaryText: '受益人: 李四 · 代理人: 王五 · 状态: 有效 · 缴费日: 15日 · 2026-06-01',
        secondaryText: null,
        summaryText: null,
        searchText: '',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        metadata: jsonEncode({
          'raw_state': {
            'fields': {
              'insurance_type': '意外险',
              'insured_person': '赵六',
              'end_date': '2027-01-01',
              'policy_status': '有效',
              'payment_day': '15',
              'beneficiary': '李四',
            },
          },
        }),
      );

      final displayModel = AnchCardBuilder.item(
        oldItem,
        now: DateTime(2026, 7, 3),
        memberName: '王小二',
      );

      // 验证卡片副标题已丢弃旧 primaryText，只提取低敏险种与结束日期
      expect(displayModel.description, '王小二 · 保险资料 · 意外险 · 2027-01-01');
      expect(displayModel.description, isNot(contains('有效')));
      expect(displayModel.description, isNot(contains('15')));
      expect(displayModel.description, isNot(contains('李四')));

      // 验证 rawState 结构异常/为空时防灾处理：不抛异常且返回空摘要，不回退
      final malformedItem = ItemModel(
        id: 'malformed-item-1',
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'insurance',
        typeKey: 'insurance',
        templateVersion: 1,
        title: '异常保单',
        primaryText: '旧文本',
        secondaryText: null,
        summaryText: null,
        searchText: '',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        metadata: jsonEncode({
          'raw_state': 'not_a_map_but_a_string', // 结构异常
        }),
      );

      final malformedModel = AnchCardBuilder.item(
        malformedItem,
        now: DateTime(2026, 7, 3),
        memberName: '王小二',
      );
      expect(malformedModel.description, '王小二 · 保险资料');
    });
  });
}
