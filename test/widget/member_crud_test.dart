import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/member/member_page.dart';
import 'package:anch/features/member/member_form_sheet.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late MemberRepository memberRepo;
  late ItemUseCaseService service;

  setUp(() {
    final context = createTestRepositoryContext();
    runtime = context.runtime;
    di = context.di;
    memberRepo = context.memberRepository;
    service = context.itemUseCaseService;
  });

  Widget buildTestWidget(Widget child) {
    return wrapTest(MaterialApp(
        home: child,
      ), runtime, (child) => di.copyWith(child: child));
  }

  testWidgets('成员保存和删除失败隐藏底层异常，保留输入并允许重试', (tester) async {
    final failingRepo = _FailingMemberRepository(di.db);
    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(home: MemberPage(isActive: true)),
        runtime,
        (child) => scopeWithTestRepositories(di, child, memberRepo: failingRepo),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增家庭成员'));
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextFormField, '称呼');
    final noteField = find.widgetWithText(TextFormField, '备注（选填）');
    await tester.enterText(nameField, '虚构故障成员');
    await tester.enterText(noteField, '虚构备注');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('保存失败，请重试'), findsOneWidget);
    expect(find.textContaining(_FailingMemberRepository.detail), findsNothing);
    expect(tester.widget<TextFormField>(nameField).controller!.text, '虚构故障成员');
    expect(tester.widget<TextFormField>(noteField).controller!.text, '虚构备注');
    expect(await memberRepo.getActiveMembers(), hasLength(2));

    failingRepo.failSave = false;
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberFormSheet), findsNothing);
    final saved = (await memberRepo.getActiveMembers()).singleWhere(
      (member) => !member.isSystem,
    );
    expect(saved.note, '虚构备注');
    await tester.tap(find.text('虚构故障成员'));
    await tester.pumpAndSettle();
    await tester.tap(findAnchIcon(AnchIcons.edit));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('删除成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(find.text('删除失败，请重试'), findsOneWidget);
    expect(find.textContaining(_FailingMemberRepository.detail), findsNothing);
    expect((await memberRepo.getMemberById(saved.id))!.isArchived, isFalse);

    failingRepo.failArchive = false;
    await tester.tap(find.byTooltip('删除成员'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(find.byType(MemberFormSheet), findsNothing);
    expect((await memberRepo.getMemberById(saved.id))!.isArchived, isTrue);
    expect(await memberRepo.getActiveMembers(), hasLength(2));
  }, tags: ['security']);

  group('家庭成员管理 CRUD 与拖拽排序测试', () {
    test('1. MemberRepository 批量更新展示顺序 updateMembersOrder', () async {
      // 1) 初始有家庭和“我”（系统内置）
      final initialList = await memberRepo.getActiveMembers();
      expect(initialList.length, 2);
      expect(initialList.any((m) => m.name == '家庭'), true);
      expect(initialList.any((m) => m.name == '我'), true);

      // 2) 保存两个新自定义成员
      final idA = await memberRepo.saveMember(SaveMemberInput(
        memberType: 'person',
        name: '成员A',
        sortOrder: 0,
      ));
      final idB = await memberRepo.saveMember(SaveMemberInput(
        memberType: 'person',
        name: '成员B',
        sortOrder: 0,
      ));

      var activeList = await memberRepo.getActiveMembers();
      expect(activeList.length, 4);

      // 3) 自定义排序：把 B 放在 A 前面
      await memberRepo.updateMembersOrder([idB, idA]);

      final sortedList = await memberRepo.getActiveMembers();
      expect(sortedList.length, 4);

      // 家庭依旧在首位 (sortOrder 0)，我依旧在第二位 (sortOrder 1)
      expect(sortedList[0].name, '家庭');
      expect(sortedList[1].name, '我');
      expect(sortedList[2].name, '成员B');
      expect(sortedList[3].name, '成员A');
    });

    testWidgets('2. MemberPage 添加成员 (必填校验 & 成功添加 & 列表重置) 集成交互', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(const MemberPage(isActive: true)));
      await tester.pumpAndSettle();

      // 检查初始有“家庭”卡片
      expect(find.text('家庭'), findsOneWidget);
      expect(find.text('成员'), findsOneWidget);
      expect(find.byKey(const Key('anch_member_avatar_family')), findsOneWidget);
      expect(find.byKey(const Key('anch_member_avatar_me')), findsOneWidget);

      // 点击“新增家庭成员”整行以弹出新增表单
      await tester.tap(find.text('新增家庭成员'));
      await tester.pumpAndSettle();

      expect(find.text('添加成员'), findsOneWidget);

      // 1) 验证必填姓名校验
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('称呼不能为空'), findsOneWidget);

      // 2) 输入称呼“爸爸”并保存
      final nameField = find.widgetWithText(TextFormField, '称呼');
      await tester.enterText(nameField, ' 爸爸 '); // 校验去空
      await tester.enterText(find.widgetWithText(TextFormField, '备注（选填）'), '一家之主');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      // 验证 Sheet 关闭，且主页面列表中多出“爸爸”
      expect(find.text('添加成员'), findsNothing);
      expect(find.text('爸爸'), findsOneWidget);
      expect(find.text('爸'), findsOneWidget);
      expect(find.byKey(const Key('anch_member_avatar_initial')), findsOneWidget);
    });

    testWidgets('3. MemberItemsPage 编辑成员、删除成员二次防护确认 (带资料 / 无资料) 交互测试', (WidgetTester tester) async {
      // 1) 先写入一个成员“大宝”
      final id = await memberRepo.saveMember(SaveMemberInput(
        memberType: 'person',
        name: '大宝',
      ));

      // 2) 开启 MemberItemsPage 并查看
      await tester.pumpWidget(buildTestWidget(MemberItemsPage(
        member: (await memberRepo.getMemberById(id))!,
      )));
      await tester.pumpAndSettle();

      expect(find.text('大宝'), findsOneWidget);
      // 3) 点击编辑图标并修改称呼
      await tester.tap(findAnchIcon(AnchIcons.edit));
      await tester.pumpAndSettle();

      expect(find.text('编辑成员'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextFormField, '称呼'), '二宝');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // 验证标题更新为“二宝”
      expect(find.text('二宝'), findsOneWidget);
      expect(find.text('编辑成员'), findsNothing);

      // 4) 资料关联情况测试：无资料删除成员
      await tester.tap(findAnchIcon(AnchIcons.edit));
      await tester.pumpAndSettle();
      // 点击右上角垃圾桶按钮
      await tester.tap(findAnchIcon(AnchIcons.delete));
      await tester.pumpAndSettle();

      // 此时无资料，提示“确认删除该成员？此操作不可撤销。”
      expect(find.text('确认删除该成员？此操作不可撤销。'), findsOneWidget);
      // 取消删除
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('取消')));
      await tester.pumpAndSettle();
      // 关闭 sheet
      await tester.tap(find.descendant(of: find.byType(MemberFormSheet), matching: find.text('取消')));
      await tester.pumpAndSettle();

      // 5) 资料关联情况测试：有资料删除成员
      // 保存一条该成员名下的模拟资料
      await service.saveDraft(ItemDraftInput(
        memberId: id,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '二宝资料'),
          ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199001011234'),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      ));
      await tester.pumpAndSettle();

      // 刷新数据并进入编辑
      await tester.tap(findAnchIcon(AnchIcons.edit));
      await tester.pumpAndSettle();
      await tester.tap(findAnchIcon(AnchIcons.delete));
      await tester.pumpAndSettle();

      // 此时有资料，提示保护型安全确认
      expect(find.textContaining('该成员下的 1 条资料不会被删除，将安全地移入“家庭”归属中。'), findsOneWidget);

      // 确认删除并关闭
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();

      // 验证页面安全 Pop 退回到前一级，二宝不再显示
      expect(find.text('二宝'), findsNothing);
    });

    testWidgets('4. 系统内置家庭成员不显示编辑和删除，也不可拖拽', (WidgetTester tester) async {
      final family = (await memberRepo.getActiveMembers()).first;

      await tester.pumpWidget(buildTestWidget(MemberItemsPage(
        member: family,
      )));
      await tester.pumpAndSettle();

      // “家庭”成员页，右上角不会渲染编辑图标按钮
      expect(findAnchIcon(AnchIcons.edit), findsNothing);
    });

    testWidgets('5. 从空成员资料页新增时自动归属当前成员并跳过归属步骤', (WidgetTester tester) async {
      final memberId = await memberRepo.saveMember(
        SaveMemberInput(memberType: 'person', name: '虚构成员甲'),
      );
      final member = (await memberRepo.getMemberById(memberId))!;

      await tester.pumpWidget(buildTestWidget(MemberItemsPage(member: member)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去添加资料'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
      expect(find.text('选择归属'), findsNothing);
      expect(find.text('选择资料类型'), findsOneWidget);

      await tester.tap(find.text('其他资料'));
      await tester.pumpAndSettle();
      expect(find.text('选择归属'), findsNothing);

      await tester.tap(findAnchIcon(AnchIcons.back));
      await tester.pumpAndSettle();
      expect(find.text('选择资料类型'), findsOneWidget);
      expect(find.text('选择归属'), findsNothing);
      await tester.tap(find.text('其他资料'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('item_field_control_title')),
        '成员入口虚构资料',
      );
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      final items = await di.itemRepo.getActiveItems();
      expect(
        items.where(
          (item) => item.memberId == memberId && item.title == '成员入口虚构资料',
        ),
        hasLength(1),
      );
    });

    testWidgets('6. 成员已有资料时仍展示新增资料按钮并沿用成员上下文', (WidgetTester tester) async {
      final memberId = await memberRepo.saveMember(
        SaveMemberInput(memberType: 'person', name: '虚构成员乙'),
      );
      await service.saveDraft(
        ItemDraftInput(
          memberId: memberId,
          categoryKey: 'generic',
          typeKey: 'generic',
          fields: [ItemFieldDraftInput(fieldKey: 'title', valueText: '既有虚构资料')],
        ),
      );

      await tester.pumpWidget(
        buildTestWidget(
          MemberItemsPage(member: (await memberRepo.getMemberById(memberId))!),
        ),
      );
      await tester.pumpAndSettle();

      final addButton = find.byKey(const Key('member_items_add_fab'));
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
      expect(find.text('选择归属'), findsNothing);
      expect(find.text('选择资料类型'), findsOneWidget);
    });
  });
}

class _FailingMemberRepository extends MemberRepository {
  _FailingMemberRepository(super.db);

  static const detail = 'PRIVATE_BACKEND_DETAIL';
  bool failSave = true;
  bool failArchive = true;

  @override
  Future<String> saveMember(SaveMemberInput input) async {
    if (failSave) throw StateError(detail);
    return super.saveMember(input);
  }

  @override
  Future<void> archiveMember(String memberId) async {
    if (failArchive) throw StateError(detail);
    return super.archiveMember(memberId);
  }
}
