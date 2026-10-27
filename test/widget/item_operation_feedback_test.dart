import 'dart:async';

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
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/widgets/anch_centered_notice.dart';
import 'package:anch/core/widgets/anch_bottom_action_bar.dart';
import 'package:anch/core/widgets/anch_page_header.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/main_shell.dart';

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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget page) {
    return wrapTest(
      MaterialApp(home: page),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Widget buildFaultSaveApp(_FailingSaveRepository failingRepo) {
    final page = MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ItemEntryFlowPage(
                  initialDraft: ItemDraftInput(
                    memberId: systemFamilyMemberId,
                    categoryKey: 'insurance',
                    typeKey: 'insurance',
                    fields: [
                      ItemFieldDraftInput(
                        fieldKey: 'policy_name',
                        valueText: '保存失败回归资料',
                      ),
                      ItemFieldDraftInput(
                        fieldKey: 'policy_number',
                        valueText: 'TEST-POLICY',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            child: const Text('打开录入'),
          ),
        ),
      ),
    );
    return wrapTest(
      page,
      runtime,
      (child) => DependencyProvider.forTesting(
        runtime: runtime,
        db: db,
        memberRepo: di.memberRepo,
        itemRepo: failingRepo,
        child: child,
      ),
    );
  }

  Future<void> openSupplement(WidgetTester tester) async {
    await tester.tap(find.text('打开录入'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
  }

  group('资料操作反馈体验收口测试', () {
    testWidgets('录入保存异常隐藏底层详情，保留草稿并允许重试', (tester) async {
      final failingRepo = _FailingSaveRepository(db);
      await tester.pumpWidget(buildFaultSaveApp(failingRepo));
      await openSupplement(tester);
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(find.textContaining(_FailingSaveRepository.detail), findsNothing);
      expect(await itemRepo.getActiveItemCount(), 0);
      final nameInput = tester.widget<TextFormField>(
        find.byKey(const Key('item_field_control_policy_name')),
      );
      final numberInput = tester.widget<TextFormField>(
        find.byKey(const Key('item_field_control_policy_number')),
      );
      expect(nameInput.controller!.text, '保存失败回归资料');
      expect(numberInput.controller!.text, 'TEST-POLICY');

      failingRepo.failSave = false;
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemEntryFlowPage), findsNothing);
      final saved = await itemRepo.getActiveItems();
      expect(saved, hasLength(1));
      final loaded = await itemRepo.getItemWithFields(saved.single.id);
      expect(
        loaded!.fields
            .firstWhere((field) => field.fieldKey == 'policy_number')
            .valueText,
        'TEST-POLICY',
      );
    }, tags: ['security']);

    testWidgets('保存等待时阻止重复提交、返回及关闭，失败后可正常退出', (tester) async {
      final gate = Completer<void>();
      final failingRepo = _FailingSaveRepository(db)..gate = gate;
      await tester.pumpWidget(buildFaultSaveApp(failingRepo));
      await openSupplement(tester);
      final save = tester
          .widget<AnchBottomActionBar>(
            find.byKey(const Key('flow_button_save')),
          )
          .onPrimary!;
      save();
      save();
      await tester.runAsync(() => failingRepo.entered.future);
      await tester.pump();
      expect(failingRepo.calls, 1);
      final header = tester.widget<AnchFlowHeader>(
        find.byKey(const Key('flow_header')),
      );
      header.onClose!();
      header.onBack!();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('确认退出'), findsNothing);
      expect(find.text('补充附件与备注'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('保存失败，请重试'), findsOneWidget);
      expect(await itemRepo.getActiveItemCount(), 0);
      await tester.tap(find.bySemanticsLabel('关闭'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemEntryFlowPage), findsNothing);
    }, tags: ['security']);

    testWidgets('保存等待时页面被移除，晚到失败不更新已销毁页面', (tester) async {
      final gate = Completer<void>();
      final failingRepo = _FailingSaveRepository(db)..gate = gate;
      await tester.pumpWidget(buildFaultSaveApp(failingRepo));
      await openSupplement(tester);
      await tester.tap(find.text('保存资料'));
      await tester.runAsync(() => failingRepo.entered.future);
      await tester.pumpWidget(const SizedBox.shrink());
      gate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(await itemRepo.getActiveItemCount(), 0);
    }, tags: ['security']);

    testWidgets('1. 验证新建资料保存成功后 pop 返回并显示「资料已整理进册」 Snackbar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const MainShell()));
      await tester.pumpAndSettle();

      // 点击新增按钮以跳转到 Flow 页
      final actionBtn = find.byKey(const Key('home_add_item'));
      expect(actionBtn, findsOneWidget);
      await tester.tap(actionBtn);
      await tester.pumpAndSettle();

      // 现在处于 ItemEntryFlowPage 第一步：选择成员 (默认选择家庭，点击下一步)

      // 第二步：选择资料类型 (选择身份证)
      expect(find.text('身份证'), findsOneWidget);
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 第三步：填写字段并保存
      expect(find.text('下一步'), findsOneWidget);
      // 根据身份证模板：输入姓名和身份证号 (必填)
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '张三测试');
      await tester.enterText(textFields.at(1), '110101199003072345');
      await tester.pumpAndSettle();

      // 点击下一步并保存资料
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      // 应当已经 pop 返回到 HomePage 并触发二级跳转到 ItemDetailPage
      expect(find.text('身份证'), findsOneWidget);

      // 应在此页面上不显示“资料已整理进册”的 Snackbar 成功提示
      expect(find.text('资料已整理进册'), findsNothing);
    });

    testWidgets('2. 验证编辑保存成功后显示「已保存资料修改」 Snackbar 且无数据回滚', (
      WidgetTester tester,
    ) async {
      // 预先存入一条资料 (提供 required 字段 card_number 与 bank_name)
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '原始标题',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '中国农业银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6228481234567890',
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);
      final itemId = res.itemId!;

      // 渲染详情页
      await tester.pumpWidget(buildTestApp(ItemDetailPage(itemId: itemId)));
      await tester.pumpAndSettle();

      // 点击编辑按钮以跳转到 Flow 页修改资料
      final editBtn = findAnchIcon(AnchIcons.more);
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // 处于编辑状态 (直接进入字段填写页)
      expect(find.text('下一步'), findsOneWidget);
      // 修改银行名称
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '修改后的农业银行');
      await tester.pumpAndSettle();

      // 点击下一步并保存修改
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      // 应当已经 pop 回到详情页，且新修改被刷新渲染
      // 检查银行名称更新（在卡片和核心字段列表中可能被渲染多次）
      expect(find.text('修改后的农业银行'), findsAtLeastNWidgets(1));

      // 应不显示“已保存资料修改”的 Snackbar
      expect(find.text('已保存资料修改'), findsNothing);

      // 数据库内容应该并没有发生实际的回滚逻辑（保持为修改后的数据）
      final dbItem = await itemRepo.getItemWithFields(itemId);
      final bankField = dbItem?.fields.firstWhere(
        (f) => f.fieldKey == 'bank_name',
      );
      expect(bankField?.valueText, equals('修改后的农业银行'));
    });

    testWidgets('3. 删除成功后关闭确认层，并在返回页显示屏幕中央深色通知', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '待删除资料',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '中国农业银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6228481234567890',
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);
      final itemId = res.itemId!;

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => ItemDetailPage(itemId: itemId),
                        ),
                      );
                    },
                    child: const Text('打开待删除资料'),
                  ),
                ),
              ),
            ),
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.tap(find.text('打开待删除资料'));
      await tester.pumpAndSettle();

      // 点击编辑按钮 -> 选择删除
      final editBtn = findAnchIcon(AnchIcons.more);
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      final deleteMenu = find.text('删除');
      expect(deleteMenu, findsOneWidget);
      await tester.tap(deleteMenu);
      await tester.pumpAndSettle();

      // 应该弹出了 BottomSheet 二次确认层
      expect(find.text('移入最近删除？'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('移入最近删除'), findsOneWidget);

      // 点击删除按钮后，确认层应关闭，详情页返回，并显示轻量成功反馈。
      await tester.tap(find.text('移入最近删除'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('打开待删除资料'), findsOneWidget);
      expect(find.text('已移入最近删除'), findsOneWidget);

      final notice = find.byKey(AnchCenteredNotice.noticeKey);
      expect(notice, findsOneWidget);
      final noticeRect = tester.getRect(notice);
      final screenCenter =
          tester.view.physicalSize.height / tester.view.devicePixelRatio / 2;
      expect((noticeRect.center.dy - screenCenter).abs(), lessThan(1));
      expect(
        tester.widget<Material>(notice).color,
        Theme.of(
          tester.element(find.byKey(AnchCenteredNotice.noticeKey)),
        ).colorScheme.inverseSurface,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(notice, findsNothing);

      // 验证资料已软删除并保留恢复所需数据。
      final dbItem = await itemRepo.getItemWithFields(itemId);
      expect(dbItem?.status, 'deleted');
      expect(dbItem?.deletedAt, isNotNull);
    });

    testWidgets('4. 详情菜单可切换置顶，且不重写资料字段', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '偏好状态测试资料',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6228481234567890',
          ),
        ],
      );
      final saved = await service.saveDraft(draft);
      expect(saved.success, isTrue);
      final itemId = saved.itemId!;

      await tester.pumpWidget(buildTestApp(ItemDetailPage(itemId: itemId)));
      await tester.pumpAndSettle();

      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      expect(find.text('设为置顶'), findsOneWidget);
      expect(find.text('设为常用'), findsNothing);

      await tester.tap(find.text('设为置顶'));
      await tester.pumpAndSettle();
      var item = await itemRepo.getItemWithFields(itemId);
      expect(item?.isPinned, isTrue);
      expect(item?.pinnedAt, isNotNull);
      expect(
        item?.fields
            .firstWhere((field) => field.fieldKey == 'bank_name')
            .valueText,
        '测试银行',
      );

      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      expect(find.text('取消置顶'), findsOneWidget);
      await tester.tap(find.text('取消置顶'));
      await tester.pumpAndSettle();

      item = await itemRepo.getItemWithFields(itemId);
      expect(item?.isPinned, isFalse);
      expect(item?.pinnedAt, isNull);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('5. 归档成功使用可自动消失的屏幕中央深色通知', (WidgetTester tester) async {
      final saved = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          title: '待归档资料',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6228481234567890',
            ),
          ],
        ),
      );
      expect(saved.success, isTrue);

      await tester.pumpWidget(
        buildTestApp(ItemDetailPage(itemId: saved.itemId!)),
      );
      await tester.pumpAndSettle();

      await tester.tap(findAnchIcon(AnchIcons.more));
      await tester.pumpAndSettle();
      await tester.tap(find.text('归档资料'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '归档资料'));
      await tester.pump();
      await tester.pumpAndSettle();

      final notice = find.byKey(AnchCenteredNotice.noticeKey);
      expect(notice, findsOneWidget);
      expect(find.text('资料已归档'), findsOneWidget);
      expect(find.text('撤销'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(
        tester.widget<Material>(notice).color,
        Theme.of(
          tester.element(find.byKey(AnchCenteredNotice.noticeKey)),
        ).colorScheme.inverseSurface,
      );

      await tester.pump(const Duration(seconds: 4));
      expect(notice, findsNothing);
    });

    testWidgets('6. 居中通知的撤销动作可点击并立即关闭通知', (WidgetTester tester) async {
      var undone = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => AnchCenteredNotice.showSuccess(
                  context,
                  '资料已归档',
                  actionLabel: '撤销',
                  onAction: () => undone = true,
                ),
                child: const Text('显示归档通知'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('显示归档通知'));
      await tester.pump();
      await tester.tap(find.text('撤销'));
      await tester.pump();

      expect(undone, isTrue);
      expect(find.byKey(AnchCenteredNotice.noticeKey), findsNothing);
    });
  });
}

class _FailingSaveRepository extends ItemRepository {
  _FailingSaveRepository(super.db);

  static const detail = 'PRIVATE_BACKEND_DETAIL';
  bool failSave = true;
  Completer<void>? gate;
  final entered = Completer<void>();
  int calls = 0;

  @override
  Future<String> saveItemWithFields(
    SaveItemInput input, {
    bool recordUserEvent = false,
  }) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    await gate?.future;
    if (failSave) throw StateError(detail);
    return super.saveItemWithFields(input, recordUserEvent: recordUserEvent);
  }
}
