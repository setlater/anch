import 'package:anch/core/widgets/anch_step_indicator.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;

  setUp(() {
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
    di = DependencyProvider.create(runtime: runtime, child: Container());
    db = di.db;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget(Widget page) {
    return wrapTest(
      MaterialApp(home: page),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('新类型模板与注册完整性测试', () {
    test('1. 新增的两个类型在模板中正确存在', () {
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
      ];

      for (final key in expectedKeys) {
        final typeDef = TemplateRegistry.getTemplate(key);
        expect(typeDef, isNotNull);
        expect(typeDef!.typeKey, key);
      }
    });

    test('2. 字段必填属性与 Searchable 正确性校验', () {
      // 2.1 property_certificate 不动产权证号必填
      final propertyTemplate = TemplateRegistry.getTemplate(
        'property_certificate',
      )!;
      final certNumField = propertyTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'certificate_number',
      );
      expect(certNumField.required, isTrue);
      expect(certNumField.searchable, isTrue);
      expect(certNumField.copyable, isTrue);

      final ownerNameField = propertyTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'owner_name',
      );
      expect(ownerNameField.searchable, isTrue);
      expect(ownerNameField.required, isFalse);

      final locationField = propertyTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'property_location',
      );
      expect(locationField.searchable, isTrue);
      expect(locationField.required, isFalse);

      // 2.2 education_certificate 证书编号必填
      final eduTemplate = TemplateRegistry.getTemplate(
        'education_certificate',
      )!;
      final eduCertNumField = eduTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'certificate_number',
      );
      expect(eduCertNumField.required, isTrue);
      expect(eduCertNumField.searchable, isTrue);
      expect(eduCertNumField.copyable, isTrue);

      final schoolField = eduTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'school_name',
      );
      expect(schoolField.searchable, isTrue);

      final majorField = eduTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'major_name',
      );
      expect(majorField.searchable, isTrue);

      final holderField = eduTemplate.fields.firstWhere(
        (f) => f.fieldKey == 'holder_name',
      );
      expect(holderField.searchable, isTrue);
    });
  });

  group('新建录入页 Step 2 与分类入口测试', () {
    testWidgets('1. 类型选择页大类 "其他" 中能看到 "不动产权证" 和 "学历/学位证书"，且 "通用资料" 依旧存在', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);

      final controller = di.createEntryFlowController(
        enableAutoFillScaffold: false,
      );

      await tester.pumpWidget(
        buildTestWidget(ItemEntryFlowPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 点击 "下一步：选择资料类型"

      // Scroll down to make the "其他" category visible in the lazy ListView
      final listFinder = find.byType(GridView);
      await tester.drag(listFinder, const Offset(0, -1500));
      await tester.pumpAndSettle();

      // 验证新增的两种子类型及原有 generic 子类型存在
      expect(find.text('不动产权证'), findsOneWidget);
      expect(find.text('学历/学位证书'), findsOneWidget);
      expect(find.text('其他资料'), findsWidgets);
    });

    testWidgets('2. 录入页 "不动产权证" Step 2 分组布局与补充折叠块隐藏测试', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);

      final controller = di.createEntryFlowController(
        enableAutoFillScaffold: false,
      );

      await tester.pumpWidget(
        buildTestWidget(ItemEntryFlowPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Scroll down the lazy ListView to bring "不动产权证" into view
      final listFinder = find.byType(GridView);
      await tester.drag(listFinder, const Offset(0, -1500));
      await tester.pumpAndSettle();

      await openEntryFields(tester, find.text('不动产权证'));
      await tester.pumpAndSettle();

      // 校验三个旧分组 Header 不存在
      expect(find.text('权属信息'), findsNothing);
      expect(find.text('证书信息'), findsNothing);
      expect(find.text('房屋信息'), findsNothing);

      // 不应包含补充信息折叠卡片（"补充信息"文字只出现在下一步按钮中，而不是单独的折叠块/可展开卡片）
      expect(find.textContaining('补充信息 (选填)'), findsNothing);

      // 直接点击 "下一步" 应该触发必填校验校验不动产权证号
      final nextStep = find.text('下一步');
      expect(nextStep, findsOneWidget);
      await tester.tap(nextStep);
      await tester.pumpAndSettle();

      // 必填项 certificate_number 报错
      expect(find.text('请输入不动产权证号'), findsOneWidget);

      // 输入 TEST-123 证号后再次点击应该能进入 Step 3 (显示可以上传证件或附件照片)
      final numberInput = find.byKey(
        const Key('item_field_control_certificate_number'),
      );
      expect(numberInput, findsOneWidget);
      await tester.enterText(numberInput, 'TEST-123');
      await tester.pumpAndSettle();

      await tester.tap(nextStep);
      await tester.pumpAndSettle();

      // 成功跨越到 Step 3 界面 (Progress step 4, counter 4 / 4)
      expect(
        tester
            .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
            .currentStep,
        3,
      );
    });

    testWidgets('3. 录入页 "学历/学位证书" Step 2 布局与输入提示测试', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 3000);

      final controller = di.createEntryFlowController(
        enableAutoFillScaffold: false,
      );

      await tester.pumpWidget(
        buildTestWidget(ItemEntryFlowPage(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Scroll down the lazy ListView to bring "学历/学位证书" into view
      final listFinder = find.byType(GridView);
      await tester.drag(listFinder, const Offset(0, -1500));
      await tester.pumpAndSettle();

      await openEntryFields(tester, find.text('学历/学位证书'));
      await tester.pumpAndSettle();

      // 验证三个旧分组不存在
      expect(find.text('证书信息'), findsNothing);
      expect(find.text('学校与专业'), findsNothing);
      expect(find.text('持有人信息'), findsNothing);

      // 验证 helper 提示文案
      expect(find.text('毕业证、学位证等'), findsOneWidget);
      expect(find.text('本科、硕士、学士等'), findsOneWidget);

      // 验证必填拦截
      final nextStep = find.text('下一步');
      await tester.tap(nextStep);
      await tester.pumpAndSettle();
      expect(find.text('请输入证书编号'), findsOneWidget);

      // 输入 TEST-DEGREE-456 后进入 Step 3
      final numberInput = find.byKey(
        const Key('item_field_control_certificate_number'),
      );
      await tester.enterText(numberInput, 'TEST-DEGREE-456');
      await tester.pumpAndSettle();

      await tester.tap(nextStep);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
            .currentStep,
        3,
      );
    });
  });

  group('详情页分组与摘要生成规则测试', () {
    test('1. 标题与摘要生成测试', () {
      final propertyType = TemplateRegistry.getTemplate(
        'property_certificate',
      )!;
      final eduType = TemplateRegistry.getTemplate('education_certificate')!;

      // 1.1 不动产权证标题兜底及自定义逻辑
      final draft1 = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'property_certificate',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'property_location',
            valueText: '北京市海淀区',
          ),
          ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'building_area', valueText: '100㎡'),
        ],
      );
      expect(
        TitleSummaryBuilder.buildTitle(
          draft: draft1,
          typeDef: propertyType,
          memberName: '家庭',
        ),
        '北京市海淀区',
      );

      final draft2 = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'property_certificate',
        fields: [
          ItemFieldDraftInput(fieldKey: 'property_location', valueText: ''),
          ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
        ],
      );
      expect(
        TitleSummaryBuilder.buildTitle(
          draft: draft2,
          typeDef: propertyType,
          memberName: '家庭',
        ),
        '张三的不动产权证',
      );

      final draft3 = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'property_certificate',
        fields: [],
      );
      expect(
        TitleSummaryBuilder.buildTitle(
          draft: draft3,
          typeDef: propertyType,
          memberName: '家庭',
        ),
        '不动产权证',
      );

      // 1.2 不动产权证主副摘要与多余点号过滤
      final primaryText1 = TitleSummaryBuilder.buildPrimaryText(
        draft: ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'property_certificate',
          fields: [
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
            ItemFieldDraftInput(
              fieldKey: 'certificate_number',
              valueText: 'TEST-123',
            ),
            ItemFieldDraftInput(fieldKey: 'building_area', valueText: ''),
          ],
        ),
        typeDef: propertyType,
        title: '不动产权证',
      );
      expect(primaryText1, '张三 · TEST-123'); // 跳过空值建筑面积，且无多余分隔符

      final secondaryText1 = TitleSummaryBuilder.buildSecondaryText(
        draft: draft1,
        typeDef: propertyType,
        primaryVal: '张三 · TEST-123',
      );
      expect(secondaryText1, isNull);

      // 1.3 学历学位证书标题自定义逻辑
      final draftEdu1 = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'education_certificate',
        fields: [
          ItemFieldDraftInput(fieldKey: 'school_name', valueText: '清华大学'),
          ItemFieldDraftInput(fieldKey: 'certificate_type', valueText: '毕业证书'),
          ItemFieldDraftInput(fieldKey: 'holder_name', valueText: '李四'),
        ],
      );
      expect(
        TitleSummaryBuilder.buildTitle(
          draft: draftEdu1,
          typeDef: eduType,
          memberName: '家庭',
        ),
        '清华大学毕业证书',
      );

      final draftEdu2 = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'education_certificate',
        fields: [
          ItemFieldDraftInput(fieldKey: 'school_name', valueText: ''),
          ItemFieldDraftInput(fieldKey: 'certificate_type', valueText: ''),
          ItemFieldDraftInput(fieldKey: 'holder_name', valueText: '李四'),
        ],
      );
      expect(
        TitleSummaryBuilder.buildTitle(
          draft: draftEdu2,
          typeDef: eduType,
          memberName: '家庭',
        ),
        '李四的学历/学位证书',
      );

      // 1.4 学历证书 primaryText 拼接及空值跳过
      final primaryEduText = TitleSummaryBuilder.buildPrimaryText(
        draft: ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'education_certificate',
          fields: [
            ItemFieldDraftInput(fieldKey: 'holder_name', valueText: '李四'),
            ItemFieldDraftInput(fieldKey: 'major_name', valueText: ''),
            ItemFieldDraftInput(fieldKey: 'degree_level', valueText: '学士'),
            ItemFieldDraftInput(
              fieldKey: 'graduation_date',
              valueText: '2026-07-01',
            ),
          ],
        ),
        typeDef: eduType,
        title: '学历证书',
      );
      expect(primaryEduText, '李四 · 学士 · 2026-07-01');
    });

    testWidgets('2. 详情页渲染与卡片分组结构测试', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // 写入并保存不动产权证数据
      final result = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'property_certificate',
          title: '北京市朝阳区的不动产权证',
          fields: [
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '王五'),
            ItemFieldDraftInput(
              fieldKey: 'ownership_status',
              valueText: '单独所有',
            ),
            ItemFieldDraftInput(
              fieldKey: 'certificate_number',
              valueText: 'NO-123',
            ),
            ItemFieldDraftInput(
              fieldKey: 'property_location',
              valueText: '北京市朝阳区',
            ),
            ItemFieldDraftInput(fieldKey: 'building_area', valueText: '89㎡'),
          ],
        ),
      );
      expect(result.persisted, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: result.itemId!)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 验证详情页顶部卡片 compact 特征
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('不动产权证')),
        findsOneWidget,
      );
      expect(find.text('其他资料'), findsNothing);
      expect(find.textContaining('类型：'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('默认脱敏'), findsNothing);
      expect(find.text('可复制字段'), findsNothing);
      expect(find.textContaining('王五 · NO-123'), findsNothing);
    });

    testWidgets('3. 详情页学历证书与通用/银行卡头部策略对照测试', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      // 3.1 学历证书 compact 头部验证
      final eduResult = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'education_certificate',
          title: '李四的学历证书',
          fields: [
            ItemFieldDraftInput(fieldKey: 'holder_name', valueText: '李四'),
            ItemFieldDraftInput(fieldKey: 'major_name', valueText: '软件工程'),
            ItemFieldDraftInput(fieldKey: 'degree_level', valueText: '学士'),
            ItemFieldDraftInput(
              fieldKey: 'graduation_date',
              valueText: '2026-07-01',
            ),
            ItemFieldDraftInput(
              fieldKey: 'certificate_number',
              valueText: 'TEST-EDU-999',
            ),
          ],
        ),
      );
      expect(eduResult.persisted, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: eduResult.itemId!)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('学历/学位证书'),
        ),
        findsOneWidget,
      );
      expect(find.text('其他资料'), findsNothing);
      expect(find.textContaining('类型：'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('默认脱敏'), findsNothing);
      expect(find.text('可复制字段'), findsNothing);
      expect(find.textContaining('李四 · 软件工程'), findsNothing);

      // 3.2 通用资料 (其他资料) compact 验证
      final genericResult = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          title: '测试其他资料',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '测试其他资料'),
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
          ],
        ),
      );
      expect(genericResult.persisted, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: genericResult.itemId!)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: find.byType(AppBar), matching: find.text('其他资料')),
        findsOneWidget,
      );
      expect(find.textContaining('类型：'), findsNothing);
      expect(find.text('本地保存'), findsNothing);
      expect(find.text('默认脱敏'), findsNothing);
      expect(find.text('可复制字段'), findsNothing);

      // 3.3 银行卡复制按钮回归保护验证
      final debitResult = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225123456789012',
            ),
          ],
        ),
      );
      expect(debitResult.persisted, isTrue);

      await tester.pumpWidget(
        buildTestWidget(ItemDetailPage(itemId: debitResult.itemId!)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debit_card_header_copy')), findsOneWidget);
    });
  });
}
