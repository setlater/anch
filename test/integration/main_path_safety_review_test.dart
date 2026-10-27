@Tags(['integration'])
library;

import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/widgets/anch_startup_failure_page.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/template/type_definition.dart';
import 'package:anch/core/template/field_definition.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/sensitive_level.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/security/app_startup_failure.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/member/member_page.dart';
import 'package:anch/features/mine/mine_page.dart';
import 'package:anch/features/search/search_page.dart';
import 'package:anch/features/type/type_page.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late MemberRepository memberRepo;
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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    memberRepo = di.memberRepo;
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child) {
    return wrapTest(
      MaterialApp(home: child),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('安册主路径安全边界与脱敏复盘测试', () {
    const String testIdNumber = '110101199003072345';

    test('1. 搜索高敏字段完整值不命中，仅能通过尾号检索命中 (单元与集成测试结合)', () async {
      // 集成层面：身份证的 id_number 默认不可搜索（searchable 为 false）
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: testIdNumber),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);

      // 搜索完整身份证号不应命中任何数据
      final searchFull = await service.searchItems(testIdNumber);
      expect(searchFull.isEmpty, isTrue);

      // 单元层面：验证如果高敏字段配置为 searchable=true 且具有 normalizedValue 尾号时，SearchTextBuilder 的安全防线
      const mockType = TypeDefinition(
        typeKey: 'mock_type',
        label: '模拟模板',
        categoryKey: 'mock_cat',
        fields: [
          FieldDefinition(
            fieldKey: 'card_number',
            label: '卡号',
            valueType: FieldValueType.bankCardNumber,
            sensitiveLevel: SensitiveLevel.high,
            searchable: true,
          ),
        ],
      );

      final mockFields = [
        ItemFieldDraftInput(fieldKey: 'card_number', valueText: '1234567890'),
      ];

      final normalizedValues = {'card_number': '7890'};

      final searchText = SearchTextBuilder.buildSearchText(
        title: '测试标题',
        typeDef: mockType,
        categoryLabel: '测试大类',
        fields: mockFields,
        normalizedValues: normalizedValues,
      );

      // 验证生成的模糊搜索索引中绝对不包含完整的高敏明文，但包含尾号
      expect(searchText.contains('1234567890'), isFalse);
      expect(searchText.contains('7890'), isTrue);
    });

    test('2. 搜索结果 ItemModel、最近保存资料卡片中不含完整高敏字段值', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: testIdNumber),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      final saveResult = await service.saveDraft(draft);
      expect(saveResult.success, isTrue);

      // A. 检验搜索结果 ItemModel 中的各字段（搜索能命中张三的 title 关键字）
      final searchResults = await service.searchItems('张三');
      expect(searchResults.length, equals(1));
      final itemFromSearch = searchResults.first;
      expect(itemFromSearch.title!.contains(testIdNumber), isFalse);
      expect(
        itemFromSearch.primaryText?.contains(testIdNumber) ?? false,
        isFalse,
      );
      expect(
        itemFromSearch.summaryText?.contains(testIdNumber) ?? false,
        isFalse,
      );
      expect(
        itemFromSearch.searchText?.contains(testIdNumber) ?? false,
        isFalse,
      );

      // B. 检验首页最近保存资料 ItemModel 中的各字段
      final recentItems = await itemRepo.getRecentItemsForSession();
      expect(recentItems.isNotEmpty, isTrue);
      final itemFromRecent = recentItems.first;
      expect(itemFromRecent.title!.contains(testIdNumber), isFalse);
      expect(
        itemFromRecent.primaryText?.contains(testIdNumber) ?? false,
        isFalse,
      );
      expect(
        itemFromRecent.summaryText?.contains(testIdNumber) ?? false,
        isFalse,
      );
      expect(
        itemFromRecent.searchText?.contains(testIdNumber) ?? false,
        isFalse,
      );
    });

    testWidgets('3. 成员资料列表、类型资料列表中不含完整高敏字段值', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: testIdNumber),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );
      final saveResult = await service.saveDraft(draft);
      expect(saveResult.success, isTrue);

      final familyMember = await memberRepo.getMemberById(systemFamilyMemberId);
      expect(familyMember, isNotNull);

      // A. 渲染成员资料列表页
      await tester.pumpWidget(
        buildTestApp(MemberItemsPage(member: familyMember!)),
      );
      await tester.pumpAndSettle();
      // widget 树中应当有张三的身份证
      expect(find.text('张三的身份证'), findsOneWidget);
      // 但绝对不能含有完整的身份证号明文
      expect(find.textContaining(testIdNumber), findsNothing);

      // B. 渲染类型资料列表页
      final cat = TemplateRegistry.getTemplate('id_card')!;
      await tester.pumpWidget(buildTestApp(TypeItemsPage(type: cat)));
      await tester.pumpAndSettle();
      expect(find.text('张三的身份证'), findsOneWidget);
      expect(find.textContaining(testIdNumber), findsNothing);
    });

    test('4. 备注(note)不参与模糊搜索的分级安全边界断言', () async {
      // 备注(note)属于自由输入的非结构化文本，若用户在其中记录高敏隐私，则可能存在搜索明文泄漏的隐患。
      // 因此 note 不参与模糊搜索。
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: testIdNumber),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
        note: '这是特有的备注标识词汇',
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);

      // 验证 note 不再被搜索命中
      final results = await service.searchItems('特有');
      expect(results.isEmpty, isTrue);
    });

    testWidgets('7. 首页卡片、成员列表卡片、类型列表卡片与搜索卡片中不展示备注(note)明文断言', (
      WidgetTester tester,
    ) async {
      const String secretNote = 'TEST-note-secret-value';
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '王五'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: testIdNumber),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '女'),
        ],
        note: secretNote,
      );
      final saveResult = await service.saveDraft(draft);
      expect(saveResult.success, isTrue);

      final familyMember = await memberRepo.getMemberById(systemFamilyMemberId);
      expect(familyMember, isNotNull);

      // A. 验证首页卡片不展示备注明文
      await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
      await tester.pumpAndSettle();
      expect(find.text('王五的身份证'), findsOneWidget);
      expect(find.textContaining(secretNote), findsNothing);

      // B. 验证成员资料列表卡片不展示备注明文
      await tester.pumpWidget(
        buildTestApp(MemberItemsPage(member: familyMember!)),
      );
      await tester.pumpAndSettle();
      expect(find.text('王五的身份证'), findsOneWidget);
      expect(find.textContaining(secretNote), findsNothing);

      // C. 验证类型资料列表卡片不展示备注明文
      final cat = TemplateRegistry.getTemplate('id_card')!;
      await tester.pumpWidget(buildTestApp(TypeItemsPage(type: cat)));
      await tester.pumpAndSettle();
      expect(find.text('王五的身份证'), findsOneWidget);
      expect(find.textContaining(secretNote), findsNothing);

      // D. 验证搜索结果卡片不展示备注明文，且输入备注关键词不应展示卡片
      await tester.pumpWidget(buildTestApp(const SearchPage()));
      await tester.pumpAndSettle();

      final searchInput = find.byType(TextField);

      // D1. 输入备注关键词，不应展示包含该 note 的资料卡片
      await tester.enterText(searchInput, secretNote);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // 等待 debounce 完成
      expect(find.text('王五的身份证'), findsNothing);
      expect(find.text('暂无资料'), findsOneWidget);

      // D2. 输入标题搜索，卡片展示，但卡片中不展示备注明文
      await tester.enterText(searchInput, '王五');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // 等待 debounce 完成
      expect(find.text('王五的身份证'), findsOneWidget);
      expect(find.textContaining(secretNote), findsNothing);
    });

    testWidgets('5. 启动阻断错误页脱敏性验证 (不含真实密钥、堆栈、危险按钮)', (
      WidgetTester tester,
    ) async {
      const String mySecretKey = 'my-secret-key-123456';
      const String stackTraceSample =
          'at AppDatabaseOpener.openConnection (database_opener.dart:120)';

      final mockFailure = AppStartupException(
        AppStartupFailureType.databaseKeyMismatch,
        '模拟密钥不匹配错误。',
        'Original error: key=$mySecretKey\n$stackTraceSample',
      );

      await tester.pumpWidget(AnchStartupFailureApp(failure: mockFailure));
      await tester.pumpAndSettle();

      // 应显示合法的脱敏错误分类代码
      expect(find.text('db_credential_mismatch'), findsOneWidget);
      // 应显示主要阻断标题
      expect(find.text('无法打开本机资料'), findsOneWidget);

      // 绝对不能包含真实的敏感密钥值
      expect(find.textContaining(mySecretKey), findsNothing);
      // 绝对不能包含底层异常的堆栈信息
      expect(find.textContaining(stackTraceSample), findsNothing);
      // 绝对不能包含任何重置、继续或进入主程序的动作按钮（防止诱导用户绕过阻断）
      expect(find.text('继续'), findsNothing);
      expect(find.text('进入 App'), findsNothing);
      expect(find.text('重置'), findsNothing);
      expect(find.text('清除数据并重试'), findsNothing);
    });

    testWidgets('6. 关键页面均有开发验证安全横幅展示', (WidgetTester tester) async {
      // 验证安全 Banner 确实覆盖了以下关键路径页面且文案统一
      final Map<String, Widget> testPages = {
        '首页': const HomePage(isActive: true),
        '录入页': const ItemEntryFlowPage(),
        '我的页': const MinePage(),
        '搜索页': const SearchPage(),
        '类型页': const TypePage(isActive: true),
        '成员页': const MemberPage(isActive: true),
      };

      for (final entry in testPages.entries) {
        await tester.pumpWidget(buildTestApp(entry.value));
        await tester.pumpAndSettle();

        // 验证开发验证 Banner 文案是否存在
        expect(
          find.text(AnchSecurityBanner.devModeMessage),
          findsOneWidget,
          reason: '页面 ${entry.key} 缺少统一的开发验证安全横幅',
        );
      }
    });
  });
}
