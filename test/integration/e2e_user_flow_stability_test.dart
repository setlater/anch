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
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/widgets/anch_centered_notice.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/member/member_page.dart';
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
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
    ItemGlobalRegistry.instance.clear();
  });

  Widget buildTestApp(Widget page) {
    return wrapTest(
      MaterialApp(home: page),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Future<ItemWithFields> seedItem(String title) async {
    final result = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: title,
        note: '端到端验证备注',
        isFavorite: true,
        isPinned: true,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '端到端银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      ),
    );
    expect(result.success, isTrue);
    final item = await itemRepo.getItemWithFields(result.itemId!);
    expect(item, isNotNull);
    return item!;
  }

  Finder cardTitle(String title) {
    return find.descendant(
      of: find.byType(AnchUnifiedDataCard),
      matching: find.text('$title（7890）'),
    );
  }

  Future<void> openHomeDetail(WidgetTester tester, String title) async {
    await tester.pumpWidget(buildTestApp(const HomePage()));
    await tester.pumpAndSettle();
    expect(cardTitle(title), findsOneWidget);

    // Scroll slightly to avoid bottom navigation bar obscuring the card
    await tester.drag(find.byType(ListView), const Offset(0, -150));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AnchUnifiedDataCard).first);
    await tester.pumpAndSettle();
    expect(find.text('储蓄卡'), findsOneWidget);
  }

  Future<void> editCurrentDetailBankName(
    WidgetTester tester,
    String value,
  ) async {
    await tester.tap(findAnchIcon(AnchIcons.more));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();

    expect(find.text('下一步'), findsOneWidget);
    final fields = find.byType(TextFormField);
    expect(fields, findsAtLeastNWidgets(1));
    await tester.enterText(fields.at(0), value);
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存修改'));
    await tester.pumpAndSettle();
    expect(find.text(value), findsAtLeastNWidgets(1));
    expect(find.text('已保存资料修改'), findsNothing);
  }

  Future<void> deleteCurrentDetail(WidgetTester tester) async {
    await tester.tap(findAnchIcon(AnchIcons.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(find.text('移入最近删除？'), findsOneWidget);
    await tester.tap(find.text('移入最近删除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('已移入最近删除'), findsOneWidget);
    expect(find.byKey(AnchCenteredNotice.noticeKey), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  Future<void> expectSearchResult(
    WidgetTester tester,
    String keyword,
    String title, {
    required bool visible,
  }) async {
    await tester.pumpWidget(buildTestApp(const SearchPage()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), keyword);
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    expect(cardTitle(title), visible ? findsOneWidget : findsNothing);
  }

  Future<void> expectVisibleAcrossPages(
    WidgetTester tester,
    String title, {
    required bool visible,
  }) async {
    await tester.pumpWidget(buildTestApp(const HomePage()));
    await tester.pumpAndSettle();
    expect(cardTitle(title), visible ? findsOneWidget : findsNothing);

    await expectSearchResult(tester, title, title, visible: visible);

    final member = (await memberRepo.getActiveMembers()).first;
    await tester.pumpWidget(buildTestApp(MemberItemsPage(member: member)));
    await tester.pumpAndSettle();
    expect(cardTitle(title), visible ? findsOneWidget : findsNothing);

    final category = TemplateRegistry.getTemplate('debit_card')!;
    await tester.pumpWidget(buildTestApp(TypeItemsPage(type: category)));
    await tester.pumpAndSettle();
    expect(cardTitle(title), visible ? findsOneWidget : findsNothing);
  }

  testWidgets('complete user lifecycle keeps data consistent end to end', (
    tester,
  ) async {
    final item = await seedItem('E2E 生命周期卡片');
    final originalTitle = item.title;

    await openHomeDetail(tester, originalTitle!);
    await editCurrentDetailBankName(tester, '端到端银行已编辑');
    final editedItem = await itemRepo.getItemWithFields(item.id);
    expect(editedItem, isNotNull);
    final editedTitle = editedItem!.title;

    await tester.tap(findAnchIcon(AnchIcons.back));
    await tester.pumpAndSettle();
    expect(cardTitle(editedTitle!), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await openHomeDetail(tester, editedTitle);
    final rollback = await itemRepo.getItemWithFields(item.id);
    expect(rollback, isNotNull);
    await deleteCurrentDetail(tester);
    expect(find.text('储蓄卡'), findsNothing);
    await tester.pumpAndSettle();
    expect(cardTitle(editedTitle), findsNothing);

    await expectSearchResult(tester, editedTitle, editedTitle, visible: false);

    final restore = await service.restoreItem(rollback!);
    expect(restore.success, isTrue);
    await expectSearchResult(tester, editedTitle, editedTitle, visible: true);

    final activeItems = await itemRepo.getActiveItems();
    expect(activeItems.where((active) => active.id == item.id), hasLength(1));
  });

  testWidgets('Home delete is reflected in Search Member and Type surfaces', (
    tester,
  ) async {
    final item = await seedItem('E2E 跨页同步卡片');

    await openHomeDetail(tester, 'E2E 跨页同步卡片');
    await deleteCurrentDetail(tester);
    await tester.pumpAndSettle();

    await expectVisibleAcrossPages(tester, 'E2E 跨页同步卡片', visible: false);

    final deleted = await itemRepo.getItemWithFields(item.id);
    expect(deleted?.status, 'deleted');
    expect(deleted?.deletedAt, isNotNull);
  });

  testWidgets('high frequency delete restore cycles leave one stable item', (
    tester,
  ) async {
    final item = await seedItem('E2E 高频闭环卡片');
    ItemWithFields rollback = item;

    for (var i = 0; i < 10; i++) {
      final delete = await service.deleteItem(item.id);
      expect(delete.success, isTrue);
      expect(delete.rollback, isNotNull);
      rollback = delete.rollback!;

      final restore = await service.restoreItem(rollback);
      expect(restore.success, isTrue);
    }

    final activeItems = await itemRepo.getActiveItems();
    expect(activeItems.where((active) => active.id == item.id), hasLength(1));

    await tester.pumpWidget(buildTestApp(const HomePage()));
    await tester.pumpAndSettle();
    expect(cardTitle('E2E 高频闭环卡片'), findsOneWidget);
    final delete = await service.deleteItem(item.id);
    expect(delete.success, isTrue);
    await tester.pumpAndSettle();
    expect(cardTitle('E2E 高频闭环卡片'), findsNothing);
    final restored = await service.restoreItem(delete.rollback!);
    expect(restored.success, isTrue);
    await tester.pumpAndSettle();
    expect(cardTitle('E2E 高频闭环卡片'), findsOneWidget);
  });

  testWidgets(
    'reload pop-back and lifecycle interference do not create ghosts',
    (tester) async {
      final item = await seedItem('E2E 生命周期干扰卡片');

      await tester.pumpWidget(buildTestApp(const SearchPage()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '生命周期干扰');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(cardTitle('E2E 生命周期干扰卡片'), findsOneWidget);

      final state =
          tester.state<State<SearchPage>>(find.byType(SearchPage)) as dynamic;
      state.reloadItems();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final delete = await service.deleteItem(item.id);
      expect(delete.success, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(cardTitle('E2E 生命周期干扰卡片'), findsNothing);

      final restore = await service.restoreItem(delete.rollback!);
      expect(restore.success, isTrue);
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      expect(cardTitle('E2E 生命周期干扰卡片'), findsOneWidget);

      await tester.tap(find.byType(AnchUnifiedDataCard).first);
      await tester.pumpAndSettle();
      expect(find.text('储蓄卡'), findsOneWidget);
      await tester.tap(findAnchIcon(AnchIcons.back));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.pumpAndSettle();
      expect(cardTitle('E2E 生命周期干扰卡片'), findsOneWidget);
    },
  );
}
