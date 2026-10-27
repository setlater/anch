@Tags(['integration'])
library;

import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemUseCaseService service;

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
    memberRepo = di.memberRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return wrapTest(
      const AnchApp(),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('安册列表刷新与编辑删除收口测试 — Widget 交互', () {
    testWidgets('1. 成员列表进入详情删除后，成员资料列表自动刷新为空状态；取消删除资料不受影响', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 先新建一条身份证资料
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

      // 验证在详情页
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('张三的身份证'), findsOneWidget);

      // 返回首页
      await tester.tap(findAnchIcon(AnchIcons.home));
      await tester.pumpAndSettle();

      // 切换至“成员”Tab
      await tester.tap(find.text('成员'));
      await tester.pumpAndSettle();

      // 点击“家庭”成员卡片
      expect(find.textContaining('1 项资料'), findsOneWidget);
      await tester.tap(find.text('家庭'));
      await tester.pumpAndSettle();

      // 确认进入成员资料列表页，标题旁显示当前资料数量
      expect(find.text('[1条]'), findsOneWidget);
      expect(find.text('张三的身份证'), findsOneWidget);

      // 点击资料卡片进入详情页
      await tester.tap(find.text('张三的身份证'));
      await tester.pumpAndSettle();
      expect(find.text('身份证'), findsOneWidget);

      // 测试：取消删除
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 点击取消按钮
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 确认资料未被删除，页面仍停留在详情页
      expect(find.text('身份证'), findsOneWidget);

      // 测试：确认删除
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移入最近删除'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // 确认自动回退到了成员资料列表页，且展示为空状态
      expect(find.text('[0条]'), findsOneWidget);
      expect(find.text('暂无资料'), findsOneWidget);
      expect(find.text('去添加资料'), findsOneWidget);
    });

    testWidgets('2. 类型列表进入详情删除后，类型列表刷新为空状态且保留新增按钮；编辑后高敏字段默认重新隐藏', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 先新建一条身份证资料
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '李四');
      await tester.enterText(textFields.at(1), '110101199003079999');
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      // 返回首页
      await tester.tap(findAnchIcon(AnchIcons.home));
      await tester.pumpAndSettle();

      // 切换至“分类”Tab
      await tester.tap(find.text('分类'));
      await tester.pumpAndSettle();

      // 验证证件资料类数量为 1，并进入证件资料列表
      expect(find.text('身份证'), findsOneWidget);
      await tester.tap(find.text('身份证'));
      await tester.pumpAndSettle();

      // 点击资料卡片进入详情页
      expect(find.text('李四的身份证'), findsOneWidget);
      await tester.tap(find.text('李四的身份证'));
      await tester.pumpAndSettle();

      // 显隐独立切换验证（默认掩码）
      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      expect(find.text('••••  ••••  ••••  9999'), findsOneWidget);
      expect(find.text('110101199003079999'), findsNothing);

      final eyeIcon = findAnchIcon(AnchIcons.visibility).first;
      await tester.scrollUntilVisible(eyeIcon, 100.0, scrollable: scrollable);
      await tester.pumpAndSettle();
      await tester.tap(eyeIcon);
      await tester.pumpAndSettle();
      // 确认明文展示
      expect(find.text('110101199003079999'), findsOneWidget);

      // 进入编辑模式并保存
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      final nameField = find.byKey(const Key('item_field_control_name'));
      await tester.enterText(nameField, '小李');
      await tester.pumpAndSettle();
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      // 验证保存成功并回到详情页，并且高敏字段默认重新进入掩码状态，标题修改生效
      expect(find.text('小李的身份证'), findsOneWidget);
      expect(find.text('••••  ••••  ••••  9999'), findsOneWidget);
      expect(find.text('110101199003079999'), findsNothing);

      // 执行删除
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移入最近删除'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // 验证自动回退到了证件资料列表页，且展示为空状态
      expect(find.text('暂无资料'), findsOneWidget);

      final addFirstBtn = find.text('去添加资料');
      expect(addFirstBtn, findsOneWidget);
    });

    testWidgets('3. 删除失败场景下，使用 SnackBar 提示错误，不发生崩溃', (
      WidgetTester tester,
    ) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '王五'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003078888',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      // 包装成异常数据库，触发物理删除失败
      final wrongRepo = BadItemRepository(db);
      final badService = ItemUseCaseService(
        itemRepo: wrongRepo,
        memberRepo: memberRepo,
        runtime: RuntimeProvider.create(
          const AnchSecurityRuntimeConfig(
            mode: AnchSecurityMode.dev,
            useEncryptedDatabase: false,
            enableSecureWindow: false,
            enablePrivacyShieldOverlay: false,
            enableAppLockGate: false,
            isFormalBlocked: false,
          ),
        ),
      );

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: ItemDetailPage(itemId: itemId)),
          runtime,
          (child) => DependencyProvider.forTesting(
            runtime: runtime,
            db: db,
            memberRepo: memberRepo,
            itemRepo: wrongRepo,
            attachmentRepo: di.attachmentRepo,
            itemUseCaseService: badService,
            child: child,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 点击删除
      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('移入最近删除'));
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 500),
      ); // 等待 SnackBar 动画渲染出来

      // 验证显示轻量错误提示，并且未发生 Crash 阻断
      expect(find.textContaining('删除失败'), findsOneWidget);
    });

    testWidgets('4. 从成员资料进入详情后点击首页按钮会切换到首页', (WidgetTester tester) async {
      await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'generic',
          typeKey: 'generic',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '成员入口虚构资料'),
          ],
        ),
      );

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('成员'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('家庭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('成员入口虚构资料'));
      await tester.pumpAndSettle();

      await tester.tap(findAnchIcon(AnchIcons.home));
      await tester.pumpAndSettle();

      expect(di.mainShellController.value, 0);
      expect(find.byKey(const Key('home_search_entry')), findsOneWidget);
      expect(find.text('家庭的资料'), findsNothing);
    });

    testWidgets('5. 从分类资料进入详情后点击首页按钮会切换到首页', (WidgetTester tester) async {
      final saveResult = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'certificate',
          typeKey: 'id_card',
          fields: [
            ItemFieldDraftInput(fieldKey: 'name', valueText: '虚构成员丙'),
            ItemFieldDraftInput(
              fieldKey: 'id_number',
              valueText: '990000199001010011',
            ),
            ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ],
        ),
      );
      final item = await di.itemRepo.getItemWithFields(saveResult.itemId!);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('分类'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('身份证'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(item!.title!));
      await tester.pumpAndSettle();

      await tester.tap(findAnchIcon(AnchIcons.home));
      await tester.pumpAndSettle();

      expect(di.mainShellController.value, 0);
      expect(find.byKey(const Key('home_search_entry')), findsOneWidget);
      expect(find.text('分类'), findsOneWidget);
    });
  });
}

// 模拟删除操作会失败的 Repository
class BadItemRepository extends ItemRepository {
  BadItemRepository(super.db);

  @override
  Future<bool> moveToTrash(String itemId) async {
    throw Exception('Mock DB write failure during deletion');
  }
}
