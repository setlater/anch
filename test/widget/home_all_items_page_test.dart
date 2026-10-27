import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/widgets/anch_page_header.dart';
import 'package:anch/core/widgets/anch_route_back.dart';
import 'package:anch/features/all_items/all_items_page.dart';
import 'package:anch/features/all_items/archived_items_page.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/mine/recently_deleted_page.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

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
    di = DependencyProvider.create(runtime: runtime, child: const SizedBox());
    db = di.db;
    service = di.itemUseCaseService;
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

  testWidgets('首页搜索框使用独立白色表面并保留搜索入口行为', (tester) async {
    await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
    await tester.pumpAndSettle();

    final surface = tester.widget<Container>(
      find.byKey(const Key('home_search_surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(
      decoration.color,
      tester.element(find.byType(HomePage)).anchColors.surface,
    );
    expect(find.byKey(const Key('home_search_entry')), findsOneWidget);
  });

  testWidgets('首页可进入全部已保存资料并展示完整低敏列表', (tester) async {
    for (var index = 1; index <= 6; index++) {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          title: '资料 $index',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '银行 $index'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '622588000000000$index',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);
    }

    await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
    await tester.pumpAndSettle();

    final entry = find.byKey(const Key('all_saved_items_entry'));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(entry, findsOneWidget);

    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(AllItemsPage), findsOneWidget);
    expect(find.textContaining('全部资料'), findsAtLeastNWidgets(1));
    expect(find.text('6 条'), findsOneWidget);
    for (var index = 6; index >= 1; index--) {
      final title = find.text('资料 $index（000$index）');
      await tester.scrollUntilVisible(
        title,
        100,
        scrollable: find.byType(Scrollable).last,
      );
      expect(title, findsOneWidget);
      expect(find.text('622588000000000$index'), findsNothing);
    }
  });

  testWidgets('资料管理子页共用标准 AppBar 与返回位置', (tester) async {
    for (final page in <({Widget widget, String title})>[
      (widget: const AllItemsPage(), title: '全部资料'),
      (widget: const ArchivedItemsPage(), title: '已归档资料'),
      (widget: const RecentlyDeletedPage(), title: '最近删除'),
    ]) {
      await tester.pumpWidget(buildTestApp(page.widget));
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
      expect(appBar.leadingWidth, 48);
      expect(appBar.titleSpacing, 0);
      expect((appBar.title! as Text).data, page.title);
      expect(find.byType(AnchRouteBack), findsOneWidget);
      expect(find.byType(AnchPageHeader), findsNothing);
    }
  });

  testWidgets('首页资料标题显示完整活跃资料总数而非预览上限', (tester) async {
    for (var index = 1; index <= 26; index++) {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'document',
          typeKey: 'other_document',
          title: '计数资料 $index',
          fields: [
            ItemFieldDraftInput(
              fieldKey: 'document_name',
              valueText: '虚构资料 $index',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);
    }

    await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
    await tester.pumpAndSettle();

    expect(find.text('26 份资料'), findsOneWidget);
    expect(find.text('20 条'), findsNothing);
    expect(find.byType(AnchUnifiedDataCard), findsNWidgets(5));
  });

  testWidgets('全部资料使用惰性列表，仅构建可见卡片并可滚动到末项', (tester) async {
    for (var index = 1; index <= 40; index++) {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'document',
          typeKey: 'other_document',
          title: '规模资料 $index',
          fields: [
            ItemFieldDraftInput(
              fieldKey: 'document_name',
              valueText: '虚构资料 $index',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);
    }

    await tester.pumpWidget(buildTestApp(const AllItemsPage()));
    await tester.pumpAndSettle();

    expect(find.text('40 条'), findsOneWidget);
    expect(find.byType(AnchUnifiedDataCard).evaluate().length, lessThan(40));
    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());

    await tester.scrollUntilVisible(
      find.text('规模资料 1'),
      500,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('规模资料 1'), findsOneWidget);
  });

  testWidgets('首页置顶资料始终排在新建普通资料之前', (tester) async {
    for (final entry in [
      (title: '置顶资料', isPinned: true),
      (title: '新增资料', isPinned: false),
    ]) {
      final result = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          title: entry.title,
          isPinned: entry.isPinned,
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '9999000000000001',
            ),
          ],
        ),
      );
      expect(result.success, isTrue);
    }

    await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('置顶资料（0001）')).dy,
      lessThan(tester.getTopLeft(find.text('新增资料（0001）')).dy),
    );
  });

  testWidgets('首页资料卡长按显示操作菜单并可切换置顶', (tester) async {
    final result = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '长按操作资料',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225880000000009',
          ),
        ],
      ),
    );
    expect(result.success, isTrue);

    await tester.pumpWidget(buildTestApp(const HomePage(isActive: true)));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(AnchUnifiedDataCard));
    await tester.pumpAndSettle();
    expect(find.text('设为置顶'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);

    await tester.tap(find.text('设为置顶'));
    await tester.pumpAndSettle();
    final item = (await di.itemRepo.getActiveItems()).firstWhere(
      (item) => item.id == result.itemId,
    );
    expect(item.isPinned, isTrue);
    await tester.pump(const Duration(seconds: 2));

    await tester.longPress(find.byType(AnchUnifiedDataCard));
    await tester.pumpAndSettle();
    expect(find.text('取消置顶'), findsOneWidget);
  });
}
