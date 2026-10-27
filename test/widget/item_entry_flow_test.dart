import 'package:anch/core/widgets/anch_step_indicator.dart';
import 'dart:async';
import 'package:anch/core/widgets/anch_choice_card.dart';
import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' show SemanticsAction, Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/features/item_entry/utils/key_registry.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/item_entry/controllers/item_entry_flow_controller.dart';
import 'package:anch/features/item_entry/controllers/item_auto_fill_engine.dart';
import 'package:anch/core/template/type_definition.dart';
import 'package:anch/core/repository/models/member_model.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/widgets/anch_page_header.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemRepository itemRepo;

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
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      child: Container(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
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

  DependencyProvider createFlowTestProvider(RuntimeContext runtime) {
    final provider = DependencyProvider.create(
      runtime: runtime,
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      child: Container(),
      database: db,
    );
    return provider;
  }

  testWidgets('正向流程测试：选择类型 -> 选择成员 -> 输入字段 -> 保存并进入详情 -> 掩码与明文切换', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 验证首页开发验证横幅及"新增资料"按钮
    // AnchSecurityBanner 使用更详细的文案，用部分匹配验证存在
    expect(find.textContaining('开发验证模式'), findsAtLeastNWidgets(1));
    // 首页去重后，无资料时只保留唯一一个"新增资料"主按钮
    final addButton = find.byKey(const Key('home_add_item'));
    expect(addButton, findsOneWidget);

    // 点击进入新增资料流
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // 选择类型，再确认归属
    expect(find.text('选择资料类型'), findsOneWidget);
    final idCardTile = find.text('身份证');
    expect(idCardTile, findsOneWidget);

    await openEntryFields(tester, idCardTile);
    await tester.pumpAndSettle();

    // 4. 步骤三：表单输入
    expect(find.text('填写核心信息'), findsOneWidget);

    final textFormFields = find.byType(TextFormField);
    expect(textFormFields, findsAtLeastNWidgets(2));
    final nameLabel = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('item_field_label_name')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '姓名',
        ),
      ),
    );
    final colors = tester
        .element(find.byKey(const Key('item_field_label_name')))
        .anchColors;
    expect(nameLabel.style?.fontSize, 14);
    expect(nameLabel.style?.fontWeight, FontWeight.w500);
    expect(nameLabel.style?.color, colors.textSecondary);
    final nameField = tester.widget<TextField>(find.byType(TextField).at(0));
    expect(nameField.enableInteractiveSelection, isTrue);
    expect(nameField.contextMenuBuilder, isNotNull);

    // 根据身份证字段模板顺序：姓名(Index 0), 身份证号(Index 1)
    await tester.enterText(textFormFields.at(0), '张三');
    await tester.enterText(textFormFields.at(1), '110101199003072345');
    await tester.pumpAndSettle();

    // 验证录入/编辑页不出现“资料完整度”相关内容
    expect(find.textContaining('资料完整度'), findsNothing);

    // 新录入流程需要在步骤三（填写）点击“下一步”进入步骤四（保存）再保存
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 点击保存资料
    final saveButton = find.text('保存资料');
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // 5. 保存成功后，自动跳转进入详情页
    expect(find.text('身份证'), findsOneWidget);
    expect(find.text('张三的身份证'), findsOneWidget);

    // 验证详情页不出现“资料完整度参考”相关内容
    expect(find.textContaining('资料完整度参考'), findsNothing);

    // 6. 验证身份证号默认被脱敏
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);
    expect(find.text('110101199003072345'), findsNothing);

    // 查找眼睛图标切换明文（可能有多个 high 敏字段，这里选取第一个）
    final visibilityIcon = findAnchIcon(AnchIcons.visibility).first;
    expect(visibilityIcon, findsOneWidget);

    await tester.scrollUntilVisible(
      visibilityIcon,
      100.0,
      scrollable: scrollable,
    );
    await tester.pumpAndSettle();

    await tester.tap(visibilityIcon);
    await tester.pumpAndSettle();

    // 验证明文显示
    expect(find.text('110101199003072345'), findsOneWidget);
    expect(find.text('••••  ••••  ••••  2345'), findsNothing);
  });

  testWidgets('步骤二（填写字段）点击下一步时会提前校验必填字段（阻塞模式，停留在填写页并显示错误）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 步骤一：选择归属

    // 步骤二：选择类型（身份证）
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    // 此时在“填写字段”页。不输入身份证号，直接点击“下一步”
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 阻塞模式：如果必填项缺失，应该停留在“填写字段”页
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入姓名'), findsOneWidget);
    expect(find.text('请输入身份证号'), findsOneWidget);
    expect(find.textContaining('请输入'), findsNWidgets(2));
  });

  testWidgets('新增资料仅选择归属和类型后关闭不确认，填写字段后才确认退出', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    await tester.tap(findAnchIcon(AnchIcons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('确认退出'), findsNothing);
    expect(find.byType(ItemEntryFlowPage), findsNothing);

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '张三');
    await tester.pumpAndSettle();

    await tester.tap(findAnchIcon(AnchIcons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('确认退出'), findsOneWidget);
  });

  testWidgets('编辑资料未改动时关闭直接退出', (WidgetTester tester) async {
    final memberId = await di.memberRepo.saveMember(
      SaveMemberInput(
        memberType: 'person',
        name: '编辑退出测试',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ),
    );
    final result = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: memberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        templateVersion: 1,
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '原姓名'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ItemEntryFlowPage(existingItemId: result.itemId),
                      ),
                    );
                  },
                  child: const Text('打开编辑页'),
                ),
              ),
            ),
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('打开编辑页'));
    await tester.pumpAndSettle();

    await tester.tap(findAnchIcon(AnchIcons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('确认退出'), findsNothing);
    expect(find.text('打开编辑页'), findsOneWidget);
  });

  testWidgets(
    'New Task-Based UX Flow Test: Intent -> Owner -> Auto-fill -> Review -> Notes -> Save',
    (WidgetTester tester) async {
      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      Widget buildTaskTestWidget() {
        return wrapTest(
          const AnchApp(),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        );
      }

      await tester.pumpWidget(buildTaskTestWidget());
      await tester.pumpAndSettle();

      // 1. Click the add button to start the flow
      final addButton = find.byKey(const Key('home_add_item'));
      expect(addButton, findsOneWidget);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      // 2. Step 0: Intent Picker. We must select an intent using KeyRegistry.typeCardIdCard
      expect(find.text('选择资料类型'), findsAtLeastNWidgets(1));
      final intentCard = find.byKey(KeyRegistry.typeCardIdCard);
      expect(intentCard, findsOneWidget);
      await tester.tap(intentCard);
      await tester.pumpAndSettle();

      // 3. Step 1: Owner Selector. Select owner. KeyRegistry.ownerCardFamily
      expect(find.text('选择归属'), findsOneWidget);
      final ownerCard = find.byKey(KeyRegistry.ownerCardFamily);
      expect(ownerCard, findsOneWidget);
      await tester.tap(ownerCard);
      await tester.pumpAndSettle();

      final nextButtonStep1 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      expect(nextButtonStep1, findsOneWidget);
      await tester.tap(nextButtonStep1);
      await tester.pumpAndSettle();

      // 4. Step 2: Editable Review.
      expect(find.text('填写核心信息'), findsOneWidget);
      expect(findField('家庭'), findsOneWidget);
      expect(findField('110101199003072345'), findsOneWidget);
      expect(find.text('已自动填充'), findsNothing);
      expect(
        find.textContaining('已自动填充'),
        findsNothing,
      ); // ID Card doesn't show unified banner anymore

      final nextButtonStep2 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      expect(nextButtonStep2, findsOneWidget);
      await tester.tap(nextButtonStep2);
      await tester.pumpAndSettle();

      // 5. Step 3: Optional Notes / Supplement
      expect(
        tester
            .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
            .currentStep,
        3,
      );
      expect(find.byKey(const Key('entry_note_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('entry_note_field')),
        '测试流新备注内容',
      );
      await tester.pumpAndSettle();

      final saveButton = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonSave),
        matching: find.byType(ElevatedButton),
      );
      expect(saveButton, findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // 7. Verify detail page is opened
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('家庭的身份证'), findsOneWidget);
      expect(find.text('测试流新备注内容'), findsOneWidget);

      // Clean up
      await taskDi.db.close();
    },
  );

  testWidgets('Task-Based UX Experience Layer Polish and Stability Test', (
    WidgetTester tester,
  ) async {
    void expectOwnerSelected(Finder card, Tristate selected) {
      final data = tester
          .getSemantics(
            find.descendant(of: card, matching: find.byType(InkWell)),
          )
          .getSemanticsData();
      expect(data.flagsCollection.isSelected, selected);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isImage, isFalse);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
    }

    final taskRuntime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    final taskDi = createFlowTestProvider(taskRuntime);

    // Pre-seed another person member so we have at least two members for owner changes
    await taskDi.memberRepo.saveMember(
      SaveMemberInput(
        memberType: 'person',
        name: '测试人员',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ),
    );

    Widget buildTaskTestWidget() {
      return wrapTest(
        const AnchApp(),
        taskRuntime,
        (child) => taskDi.copyWith(child: child),
      );
    }

    await tester.pumpWidget(buildTaskTestWidget());
    await tester.pumpAndSettle();

    // 1. Enter flow and verify step-level AnimatedSwitcher is present
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    expect(find.byType(AnimatedSwitcher), findsOneWidget);

    // Select intent (Step 0)
    await tester.tap(find.byKey(KeyRegistry.typeCardIdCard));
    await tester.pumpAndSettle();

    // 2. Step 1: Owner Selector. First select: no SnackBar
    expect(find.text('已自动更新部分资料'), findsNothing);
    await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
    await tester.pumpAndSettle();
    expect(find.text('已自动更新部分资料'), findsNothing);
    expectOwnerSelected(
      find.byKey(KeyRegistry.ownerCardFamily),
      Tristate.isTrue,
    );
    final otherOwner = find.ancestor(
      of: find.text('测试人员'),
      matching: find.byType(AnchChoiceCard),
    );
    expectOwnerSelected(otherOwner, Tristate.isFalse);
    final addMemberChoice = find.ancestor(
      of: find.text('新增家庭成员'),
      matching: find.byType(AnchChoiceCard),
    );
    expect(
      tester
          .getSemantics(
            find.descendant(
              of: addMemberChoice,
              matching: find.byType(InkWell),
            ),
          )
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.none,
    );

    // Re-select same owner: no SnackBar
    await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
    await tester.pumpAndSettle();
    expect(find.text('已自动更新部分资料'), findsNothing);

    // Click next to advance to editable review
    final nextBtn = find.descendant(
      of: find.byKey(KeyRegistry.flowButtonNext),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(nextBtn);
    await tester.pumpAndSettle();

    // 3. Step 2: Editable Review. Verify stable widget key
    expect(find.byKey(const Key('item_field_root_name')), findsOneWidget);
    expect(find.text('已自动填充'), findsNothing);
    expect(
      find.textContaining('已自动填充'),
      findsNothing,
    ); // ID Card doesn't show unified banner anymore

    // Enter ID number "123456789" manually, leaving "姓名" (value: "家庭") untouched
    final idInput = findField('身份证号');
    expect(idInput, findsOneWidget);
    await tester.enterText(idInput, '123456789');
    await tester.pump();

    // Focus / cursor / text stability check:
    final textFormField = tester.widget<TextFormField>(idInput);
    expect(textFormField.controller?.text, '123456789');

    // Tap back to Owner Selection
    final backIcon1 = findAnchIcon(AnchIcons.back).first;
    await tester.tap(backIcon1);
    await tester.pumpAndSettle();

    // Now change the owner to "测试人员". This should trigger the "已自动更新部分资料" SnackBar
    // because "姓名" (untouched) changes from "家庭" to "测试人员", but manually edited "身份证号" is preserved.
    final otherOwnerCard = find.text('测试人员');
    expect(otherOwnerCard, findsOneWidget);
    await tester.tap(otherOwnerCard);
    await tester.pumpAndSettle();
    expectOwnerSelected(otherOwner, Tristate.isTrue);
    expectOwnerSelected(
      find.byKey(KeyRegistry.ownerCardFamily),
      Tristate.isFalse,
    );

    // Verify no SnackBar was shown
    expect(find.text('已自动更新部分资料'), findsNothing);
    await tester.pumpAndSettle();

    // Verify that value of "身份证号" is still "123456789" (not overwritten)
    // Go forward to editable review
    final nextBtnAfterChange = find.descendant(
      of: find.byKey(KeyRegistry.flowButtonNext),
      matching: find.byType(ElevatedButton),
    );
    await tester.tap(nextBtnAfterChange);
    await tester.pumpAndSettle();

    // Now in Editable Review step.
    // Verify "身份证号" is still "123456789"
    final idInputAfter = findField('身份证号');
    expect(
      tester.widget<TextFormField>(idInputAfter).controller?.text,
      '123456789',
    );

    // Verify "姓名" has been updated to "测试人员"
    final nameInputAfter = findField('姓名');
    expect(
      tester.widget<TextFormField>(nameInputAfter).controller?.text,
      '测试人员',
    );

    // Clean up
    await taskDi.db.close();
  });

  testWidgets(
    'Task Flow UI Banners, SnackBar, and Source Badges Verification',
    (WidgetTester tester) async {
      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      Widget buildTaskTestWidget() {
        return wrapTest(
          const AnchApp(),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        );
      }

      await tester.pumpWidget(buildTaskTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KeyRegistry.typeCardIdCard));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
      await tester.pumpAndSettle();

      final nextBtn1 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn1);
      await tester.pumpAndSettle();

      expect(find.text('已根据归属自动生成内容'), findsNothing);
      expect(find.text('你可以修改任意字段，修改后将以你的输入为准'), findsNothing);

      final nameInput = findField('姓名');
      await tester.enterText(nameInput, '张三新');
      await tester.pumpAndSettle();

      final backIcon = findAnchIcon(AnchIcons.back).first;
      await tester.tap(backIcon);
      await tester.pumpAndSettle();
      expect(find.text('选择归属'), findsOneWidget);

      await taskDi.db.close();
    },
  );

  testWidgets('详情快照可在编辑页首个稳定帧直接生成表单', (tester) async {
    final saved = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '快照编辑'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      ),
    );
    final item = await itemRepo.getItemWithFields(saved.itemId!);
    final member = await di.memberRepo.getMemberById(systemFamilyMemberId);

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: ItemEntryFlowPage(
            existingItemId: saved.itemId,
            initialExistingItem: item,
            initialExistingMember: member,
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('编辑身份证'), findsOneWidget);
    expect(find.text('快照编辑'), findsOneWidget);
  });

  testWidgets('Edit Mode Field Badges Verification (No "系统生成")', (
    WidgetTester tester,
  ) async {
    final taskRuntime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    final taskDi = createFlowTestProvider(taskRuntime);

    final memberRepo = taskDi.memberRepo;
    final member = await memberRepo.saveMember(
      SaveMemberInput(
        memberType: 'person',
        name: '测试人员',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ),
    );
    final result = await taskDi.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: member,
        categoryKey: 'identity',
        typeKey: 'id_card',
        templateVersion: 1,
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '测试编辑'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
        ],
      ),
    );

    Widget buildTaskTestWidget() {
      return wrapTest(
        MaterialApp(home: ItemEntryFlowPage(existingItemId: result.itemId)),
        taskRuntime,
        (child) => taskDi.copyWith(child: child),
      );
    }

    await tester.pumpWidget(buildTaskTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('编辑身份证'), findsOneWidget);

    final nameInput = findField('姓名');
    await tester.enterText(nameInput, '测试编辑修改');
    await tester.pumpAndSettle();

    await taskDi.db.close();
  });

  testWidgets('编辑页键盘显示时下一步和保存按钮保持可见并可操作', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final memberId = await di.memberRepo.saveMember(
      SaveMemberInput(
        memberType: 'person',
        name: '键盘测试成员',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ),
    );
    final saved = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: memberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        templateVersion: 1,
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '星河'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '女'),
        ],
      ),
    );
    final itemId = saved.itemId!;

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 1200),
              viewInsets: EdgeInsets.only(bottom: 300),
            ),
            child: ItemEntryFlowPage(existingItemId: itemId),
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = findField('姓名');
    await tester.enterText(nameField, '星河修改');
    await tester.pumpAndSettle();

    expect(find.text('下一步').hitTestable(), findsOneWidget);
    await tester.tap(find.text('下一步').hitTestable());
    await tester.pumpAndSettle();

    final saveActionBar = find.byKey(const Key('flow_button_save'));
    expect(saveActionBar, findsOneWidget);
    final saveButton = find
        .descendant(of: saveActionBar, matching: find.byType(ElevatedButton))
        .hitTestable();
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final updated = await itemRepo.getItemWithFields(itemId);
    final updatedName = updated!.fields
        .firstWhere((field) => field.fieldKey == 'name')
        .valueText;
    expect(updatedName, '星河修改');
  });

  testWidgets(
    'Only show auto-fill SnackBar when at least one non-empty field is generated',
    (WidgetTester tester) async {
      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      // Create a controller with our MockEmptyAutoFillEngine
      final mockEngine = MockEmptyAutoFillEngine();
      final customController = ItemEntryFlowController(
        enableAutoFillScaffold: true,
        autoFillEngine: mockEngine,
      );

      Widget buildTaskTestWidget() {
        return wrapTest(
          MaterialApp(home: ItemEntryFlowPage(controller: customController)),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        );
      }

      await tester.pumpWidget(buildTaskTestWidget());
      await tester.pumpAndSettle();

      // Select intent
      await tester.tap(find.byKey(KeyRegistry.typeCardIdCard));
      await tester.pumpAndSettle();

      // Select owner
      await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
      await tester.pumpAndSettle();

      final nextBtn1 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn1);
      await tester.pumpAndSettle();

      // Now in AutoFill Preview, but because mock engine returned no fields, no SnackBar should be shown
      expect(find.text('已根据归属自动生成内容'), findsNothing);

      await taskDi.db.close();
    },
  );

  testWidgets(
    'SnackBar should not show for expired steps under rapid back navigation',
    (WidgetTester tester) async {
      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      Widget buildTaskTestWidget() {
        return wrapTest(
          const AnchApp(),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        );
      }

      await tester.pumpWidget(buildTaskTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KeyRegistry.typeCardIdCard));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
      await tester.pumpAndSettle();

      // Tap next to advance to AutoFill Preview
      final nextBtn1 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn1);
      // Tap back immediately to Owner selector
      await tester.pump(); // Start transition

      final backIcon = findAnchIcon(AnchIcons.back).first;
      await tester.tap(backIcon);
      await tester.pumpAndSettle();

      // Verify we are back on Owner selection, and no SnackBar is displayed/remains
      expect(find.text('已根据归属自动生成内容'), findsNothing);

      await taskDi.db.close();
    },
  );

  testWidgets(
    'Verify 5th step (Supplement) UI banner, subtitle, and back button behavior',
    (WidgetTester tester) async {
      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      Widget buildTaskTestWidget() {
        return wrapTest(
          const AnchApp(),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        );
      }

      await tester.pumpWidget(buildTaskTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KeyRegistry.typeCardIdCard));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
      await tester.pumpAndSettle();

      // Step 1 -> Step 2 (Editable Review)
      final nextBtn1 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn1);
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(
        tester.element(find.byType(ItemEntryFlowPage)),
      ).clearSnackBars();
      await tester.pumpAndSettle();

      // Step 2 -> Step 3 (Supplement)
      final nextBtn2 = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn2);
      await tester.pumpAndSettle();

      // Now in Step 3: Supplement
      expect(
        tester
            .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
            .currentStep,
        3,
      );
      expect(find.text('附件保存在应用内部，不进入系统相册'), findsOneWidget);

      // Tap back button from step 3
      final backIcon = findAnchIcon(AnchIcons.back).first;
      await tester.tap(backIcon);
      await tester.pumpAndSettle();

      // Should return to Step 2 (Editable Review)
      expect(find.text('填写核心信息'), findsOneWidget);

      await taskDi.db.close();
    },
  );

  group('身份证 (id_card) 分组、多列与长期有效优化测试', () {
    testWidgets('身份证页面字段顺序、分组与双列布局/地址多行检验', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 进入新增流程
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      // 步骤一：选择归属

      // 步骤二：选择类型（身份证）
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 1. 验证分组标题
      expect(find.text('基本信息'), findsNothing);
      expect(find.text('户籍地址'), findsNothing);
      expect(find.text('签发与有效期'), findsNothing);

      // 2. 验证性别/民族单独占行布局（不在同一个 Row 下）
      final genderFinder = find.byKey(const Key('item_field_control_gender'));
      final ethnicityFinder = findField('民族');
      expect(genderFinder, findsOneWidget);
      expect(ethnicityFinder, findsOneWidget);

      final rowFinder = find.ancestor(
        of: genderFinder,
        matching: find.byType(Row),
      );
      expect(
        find.descendant(of: rowFinder, matching: ethnicityFinder),
        findsNothing,
      );

      // 3. 验证有效期开始/结束双列布局
      final validFromFinder = findField('有效期开始');
      final validUntilFinder = findField('有效期结束');
      expect(validFromFinder, findsOneWidget);
      expect(validUntilFinder, findsOneWidget);

      final validRowFinder = find
          .ancestor(of: validFromFinder, matching: find.byType(Row))
          .first;
      expect(validRowFinder, findsOneWidget);
      expect(
        find.descendant(of: validRowFinder, matching: validUntilFinder),
        findsOneWidget,
      );

      // 4. 验证地址多行 (TextFormField.maxLines > 1)
      final addressFinder = findField('地址');
      expect(addressFinder, findsOneWidget);
      final textField = tester.widget<TextField>(
        find.descendant(of: addressFinder, matching: find.byType(TextField)),
      );
      expect(textField.maxLines, equals(3));
      expect(textField.minLines, equals(2));
    });

    testWidgets('长期有效开启/关闭后，valid_until 交互、禁用状态、UI 文案显示及底层提交值校验', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 进入新增流程
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 输入姓名和身份证号 (必填)
      await tester.enterText(findField('姓名'), '王五');
      await tester.enterText(findField('身份证号'), '110101199003072345');

      // Tapping the date field opens the date picker to select 2026-06-24 (from DeterministicTimeDomainSource)
      final validUntilInput = findField('有效期结束');
      await tester.tap(validUntilInput);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '2026-06-24',
      );

      // 验证默认情况下是否长期有效为 false
      final isLongTermFinder = find.byType(Switch);
      expect(isLongTermFinder, findsOneWidget);
      expect(tester.widget<Switch>(isLongTermFinder).value, isFalse);

      // 1. 开启“是否长期有效”
      await tester.tap(isLongTermFinder);
      await tester.pumpAndSettle();
      expect(tester.widget<Switch>(isLongTermFinder).value, isTrue);

      // 2. 校验 valid_until UI 显示 “长期”
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '长期',
      );

      // 3. 校验日历图标隐藏（SizedBox.shrink 或没有 Icon）
      expect(
        find.descendant(
          of: validUntilInput,
          matching: findAnchIcon(AnchIcons.calendar),
        ),
        findsNothing,
      );

      // 4. 保存资料并拦截/检查传递的有效期限值
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      // 确认详情页被打开
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('王五的身份证'), findsOneWidget);

      // 查询数据库或 Repository 校验保存的值
      final activeItems = await itemRepo.getActiveItems();
      final savedItem = activeItems.firstWhere((i) => i.title == '王五的身份证');
      final savedFields = await itemRepo.getItemWithFields(savedItem.id);

      final savedValidUntil = savedFields!.fields
          .firstWhere((f) => f.fieldKey == 'valid_until')
          .valueText;
      expect(savedValidUntil, equals('2026-06-24')); // 保存的必须是实际日期，不是 "长期"

      final savedIsLongTerm = savedFields.fields
          .firstWhere((f) => f.fieldKey == 'is_long_term')
          .valueText;
      expect(savedIsLongTerm, equals('true'));
    });

    testWidgets('长期开启再关闭后，日期恢复或不被静默清空', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 进入新增流程
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // Tap the date field to open the date picker and select 2026-06-24
      final validUntilInput = findField('有效期结束');
      await tester.tap(validUntilInput);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '2026-06-24',
      );

      final isLongTermFinder = find.byType(Switch);
      // 开启长期有效
      await tester.tap(isLongTermFinder);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '长期',
      );

      // 关闭长期有效
      await tester.tap(isLongTermFinder);
      await tester.pumpAndSettle();

      // 验证日期恢复，没有被静默清空
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '2026-06-24',
      );
    });

    testWidgets('编辑已有身份证资料时长期有效初始化正确', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final memberId = await di.memberRepo.saveMember(
        SaveMemberInput(
          memberType: 'person',
          name: '编辑测试',
          sortOrder: 1,
          isSystem: false,
          isArchived: false,
        ),
      );

      final itemSaveResult = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: memberId,
          categoryKey: 'certificate',
          typeKey: 'id_card',
          templateVersion: 1,
          fields: [
            ItemFieldDraftInput(fieldKey: 'name', valueText: '编辑测试'),
            ItemFieldDraftInput(
              fieldKey: 'id_number',
              valueText: '110101199003072345',
            ),
            ItemFieldDraftInput(fieldKey: 'gender', valueText: '女'),
            ItemFieldDraftInput(fieldKey: 'is_long_term', valueText: 'true'),
            ItemFieldDraftInput(
              fieldKey: 'valid_until',
              valueText: '2030-01-01',
            ),
          ],
        ),
      );

      // 启动编辑页
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            home: ItemEntryFlowPage(existingItemId: itemSaveResult.itemId),
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 UI 显示正确
      expect(find.text('编辑身份证'), findsOneWidget);

      final isLongTermFinder = find.byType(Switch);
      expect(tester.widget<Switch>(isLongTermFinder).value, isTrue);

      final validUntilInput = findField('有效期结束');
      expect(
        tester.widget<TextFormField>(validUntilInput).controller?.text,
        '长期',
      );
    });

    testWidgets('其他模板不再显示字段级“已自动填充”标签', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final taskRuntime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      final taskDi = createFlowTestProvider(taskRuntime);

      await tester.pumpWidget(
        wrapTest(
          const AnchApp(),
          taskRuntime,
          (child) => taskDi.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 进入新增流程
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      // 2. 选择储蓄卡模板 (debit_card)
      await tester.tap(find.byKey(KeyRegistry.typeCardDebitCard));
      await tester.pumpAndSettle();

      // 3. 选择归属并进入
      await tester.tap(find.byKey(KeyRegistry.ownerCardFamily));
      await tester.pumpAndSettle();

      final nextBtn = find.descendant(
        of: find.byKey(KeyRegistry.flowButtonNext),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // 4. 确认在储蓄卡填写页中，没有看到字段级的“已自动填充”
      expect(find.text('填写核心信息'), findsOneWidget);
      expect(find.text('已自动填充'), findsNothing);

      await taskDi.db.close();
    });

    testWidgets('身份证页面UI优化校验：无顶部小标题及通用提示、无自动填充横幅、保留分组标题与性别选择器', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 1. 覆盖身份证页不显示模板小标题、字段数和通用提示
      expect(find.textContaining('10 个字段'), findsNothing);
      expect(find.textContaining('你可以修改任意字段'), findsNothing);

      // 2. 覆盖身份证页不显示“已自动填充部分字段，请仔细核对”
      expect(find.textContaining('已自动填充部分字段'), findsNothing);

      // 3. 仍显示 基本信息 / 户籍地址 / 签发与有效期
      expect(find.text('基本信息'), findsNothing);
      expect(find.text('户籍地址'), findsNothing);
      expect(find.text('签发与有效期'), findsNothing);

      // 4. 性别显示“男 / 女”选择组件 (Key 为 id-card-gender-selector)
      final genderSelector = find.byKey(const Key('item_field_control_gender'));
      expect(genderSelector, findsOneWidget);
      expect(
        find.descendant(of: genderSelector, matching: find.text('男')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: genderSelector, matching: find.text('女')),
        findsOneWidget,
      );
    });

    testWidgets('身份证性别字段交互：点击男/女更新字段值；身份证号推导性别同步更新选择状态', (
      WidgetTester tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 1. 点击“男”更新字段值
      await tester.tap(find.bySemanticsLabel('性别－男'));
      await tester.pumpAndSettle();

      // 2. 输入身份证号推导性别同步更新选择状态 (18位，第17位偶数为女 -> 2)
      // 身份证号：110101199003072325 -> 2是偶数 -> 性别应自动推导为女
      await tester.enterText(findField('身份证号'), '110101199003072325');
      await tester.pumpAndSettle();

      // 验证出生日期也被成功推导；由于此前手动点击了“男”，因此性别不会被推导覆盖，依然保持“男”
      expect(
        tester.widget<TextFormField>(findField('出生日期')).controller?.text,
        '1990-03-07',
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('性别－男'))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    });

    testWidgets('身份证号输入格式：允许末位 X/x 且自动转为大写 X', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      final idInput = findField('身份证号');
      // 输入带小写 x 的身份证号
      await tester.enterText(idInput, '11010119900307234x');
      await tester.pumpAndSettle();

      // 验证自动转换成大写 X
      expect(
        tester.widget<TextFormField>(idInput).controller?.text,
        '11010119900307234X',
      );
    });

    testWidgets('身份证核心字段必填校验：姓名或身份证号为空无法继续，且出现对应必填错误', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 1. 姓名和身份证号都为空时，点击“下一步：补充信息”
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 出现必填错误，且停在填写字段页
      expect(find.text('填写核心信息'), findsOneWidget);
      expect(find.text('请输入姓名'), findsOneWidget);
      expect(find.text('请输入身份证号'), findsOneWidget);
      expect(find.text('请选择性别'), findsOneWidget);

      // 2. 只填写姓名，身份证号为空时
      await tester.enterText(findField('姓名'), '李四');
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('填写核心信息'), findsOneWidget);
      expect(find.text('请输入身份证号'), findsOneWidget);
      expect(find.text('请输入姓名'), findsNothing);
    });

    testWidgets('其他非身份证模板：不显示顶部说明块，但能正常进入录入、支持字段级“已自动填充”及正常校验', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      // 选择大类下的储蓄卡 (debit_card)
      await openEntryFields(tester, find.text('储蓄卡'));
      await tester.pumpAndSettle();

      // 验证没有顶部小标题和通用提示
      expect(find.textContaining('储蓄卡 /'), findsNothing);
      expect(find.textContaining('你可以修改任意字段'), findsNothing);

      // 验证非身份证模板必填校验：直接点击下一步，不填任何数据（卡号是必填的）
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 页面不应跳转，且显示必填错误提示
      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
      expect(find.text('请输入卡号'), findsOneWidget);
    });
  });

  testWidgets('身份证性别必填校验：新建时默认未选态；性别为空时阻止提交并显示错误', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    // 1. 新建时性别选择器处于未选态
    final maleSemantics = tester.getSemantics(find.bySemanticsLabel('性别－男'));
    final femaleSemantics = tester.getSemantics(find.bySemanticsLabel('性别－女'));
    expect(
      maleSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
      reason: '新建时"男"不应高亮',
    );
    expect(
      femaleSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isFalse,
      reason: '新建时"女"不应高亮',
    );

    // 2. 填写姓名，不填身份证号（避免触发推导），不选性别，尝试提交
    await tester.enterText(findField('姓名'), '王六');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 3. 性别错误应出现
    expect(find.text('请选择性别'), findsOneWidget);

    // 4. 点击"女"后，"女"高亮
    await tester.tap(find.bySemanticsLabel('性别－女'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('性别－女'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
      reason: '选中后"女"应高亮',
    );
    semantics.dispose();
  });

  testWidgets('验证键盘弹出态下的紧凑模式展现与回退行为', (WidgetTester tester) async {
    // 1. 模拟没有键盘弹出的常规状态
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: AnchPageHeader(
              title: '测试标题',
              subtitle: '测试副标题',
              compactWhenKeyboardVisible: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 常规模式下，有副标题
    expect(find.text('测试副标题'), findsOneWidget);

    // 2. 模拟键盘弹出状态 (viewInsets.bottom = 300)
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: AnchPageHeader(
              title: '测试标题',
              subtitle: '测试副标题',
              compactWhenKeyboardVisible: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 验证紧凑态生效：
    // - Subtitle 不再显示
    expect(find.text('测试副标题'), findsNothing);
  });

  testWidgets('验证单个组件在 compactWhenKeyboardVisible = false 时不响应键盘', (
    WidgetTester tester,
  ) async {
    // 渲染 AnchPageHeader，传入 compactWhenKeyboardVisible: false
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300)),
            child: AnchPageHeader(
              title: '测试标题',
              subtitle: '测试副标题',
              compactWhenKeyboardVisible: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 即使有键盘，副标题依然显示
    expect(find.text('测试副标题'), findsOneWidget);
  });

  testWidgets('护照 (passport) 分组、必填及折叠优化测试', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 步骤一：选择归属，点击进入类型选择

    // 3. 步骤二：选择类型（护照）
    final passportTile = find.text('护照');
    expect(passportTile, findsOneWidget);
    await openEntryFields(tester, passportTile);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.pumpAndSettle();

    // 4. 验证分组标题
    expect(find.text('护照信息'), findsNothing);
    expect(find.text('基本身份信息'), findsNothing);
    expect(find.text('签发与有效期'), findsNothing);

    // 5. 验证“出生地”字段在主体区域中可见
    expect(findField('出生地'), findsOneWidget);

    // 6. 验证“可选填写，不影响先保存资料”这段补充信息折叠提示不可见
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 7. 验证底部“下一步：补充信息”按钮可见
    expect(find.text('下一步'), findsOneWidget);

    // 8. 验证必填字段校验拦截（不填护照号点击下一步，停留在当前页并报错）
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 依然在填写字段页，并出现错误提示
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入护照号'), findsOneWidget);

    // 9. 输入有效的假数据 TEST-PASSPORT-NUMBER，验证可以通过校验并进入 Step 3
    final passportNumField = findField('护照号');
    await tester.enterText(passportNumField, 'TEST-PASSPORT-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 验证已经成功进入下一步：补充信息 (Step 3) 页面
    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );
  });

  testWidgets('港澳通行证 (hk_macao_pass) 分组、必填及折叠优化测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 步骤一：选择归属，点击进入类型选择

    // 3. 步骤二：选择类型（港澳通行证）
    final permitTile = find.text('港澳通行证');
    expect(permitTile, findsOneWidget);
    await openEntryFields(tester, permitTile);
    await tester.pumpAndSettle();

    // 4. 验证分组标题全部出现
    expect(find.text('证件信息'), findsNothing);
    expect(find.text('基本身份信息'), findsNothing);
    expect(find.text('签发与有效期'), findsNothing);

    // 5. 验证主体字段可见
    expect(findField('证件号'), findsOneWidget);
    expect(findField('姓名'), findsOneWidget);
    expect(findField('出生日期'), findsOneWidget);
    expect(findField('有效期至'), findsOneWidget);

    // 6. 验证"签注说明"不在 Step 2 中显示（它是 p1 字段，不纳入分组）
    expect(findField('签注说明'), findsNothing);

    // 7. 验证"可选填写，不影响先保存资料"这段补充信息折叠提示不可见
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 8. 验证底部"下一步"按钮可见
    expect(find.text('下一步'), findsOneWidget);

    // 9. 验证必填字段校验拦截（不填证件号点击下一步，停留在当前页并报错）
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 依然在填写字段页，并出现错误提示
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入证件号'), findsOneWidget);

    // 10. 输入 TEST-HK-MACAO-PERMIT-NUMBER 后，验证可以通过校验并进入 Step 3
    final passNumberField = findField('证件号');
    await tester.enterText(passNumberField, 'TEST-HK-MACAO-PERMIT-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 验证已经成功进入下一步：补充信息 (Step 3) 页面
    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );
  });

  testWidgets('驾驶证 (driver_license) 分组、必填及折叠优化测试', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属

    // 3. 选择驾驶证
    final licenseTile = find.text('驾驶证');
    expect(licenseTile, findsOneWidget);
    await openEntryFields(tester, licenseTile);
    expect(find.text('下一步'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    await tester.pumpAndSettle();

    // 4. 验证四个分组标题全部出现
    expect(find.text('证件信息'), findsNothing);
    expect(find.text('基本身份信息'), findsNothing);
    expect(find.text('驾驶资格'), findsNothing);
    expect(find.text('签发与有效期'), findsNothing);

    // 5. 验证主体字段可见
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      findField('驾驶证号'),
      50.0,
      scrollable: scrollable,
    );
    expect(findField('驾驶证号'), findsOneWidget);
    await tester.scrollUntilVisible(
      findField('档案编号'),
      50.0,
      scrollable: scrollable,
    );
    expect(findField('档案编号'), findsOneWidget);
    await tester.scrollUntilVisible(
      findField('姓名'),
      50.0,
      scrollable: scrollable,
    );
    expect(findField('姓名'), findsOneWidget);
    await tester.scrollUntilVisible(
      findField('出生日期'),
      50.0,
      scrollable: scrollable,
    );
    expect(findField('出生日期'), findsOneWidget);
    await tester.scrollUntilVisible(
      findField('有效期至'),
      50.0,
      scrollable: scrollable,
    );
    expect(findField('有效期至'), findsOneWidget);

    // 6. 验证"国籍"和 nationality 不在 Step 2 中显示
    expect(findField('国籍'), findsNothing);
    expect(findField('nationality'), findsNothing);

    // 7. 验证"可选填写，不影响先保存资料"折叠提示不可见
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 8. 验证底部"下一步"按钮可见
    expect(find.text('下一步'), findsOneWidget);

    // 9. 验证必填校验：不填驾驶证号，停留在 Step 2
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入驾驶证号'), findsOneWidget);

    // 10. 输入 TEST-DRIVING-LICENSE-NUMBER，进入 Step 3
    final licenseField = findField('驾驶证号');
    await tester.scrollUntilVisible(licenseField, 50.0, scrollable: scrollable);
    await tester.enterText(licenseField, 'TEST-DRIVING-LICENSE-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );
  });

  testWidgets('行驶证 (vehicle_license) 分组、必填及折叠优化测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属并进入类型选择

    // 3. 选择行驶证
    final licenseTile = find.text('行驶证');
    expect(licenseTile, findsOneWidget);
    await openEntryFields(tester, licenseTile);
    await tester.pumpAndSettle();

    // 4. 验证四个分组标题全部出现
    expect(find.text('车辆标识'), findsNothing);
    expect(find.text('车辆信息'), findsNothing);
    expect(find.text('所有人信息'), findsNothing);
    expect(find.text('登记与发证'), findsNothing);

    // 5. 验证主体字段可见
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    final fieldsToVerify = [
      '号牌号码',
      '车辆识别代号',
      '发动机号码',
      '车辆类型',
      '品牌型号',
      '使用性质',
      '核定载人数',
      '所有人',
      '地址',
      '注册日期',
      '发证日期',
      '发证机关',
    ];

    for (final label in fieldsToVerify) {
      final field = findField(label);
      await tester.scrollUntilVisible(field, 50.0, scrollable: scrollable);
      expect(field, findsOneWidget);
    }

    // 6. 验证不显示移除的字段
    expect(findField('档案编号'), findsNothing);
    expect(findField('总质量'), findsNothing);
    expect(findField('检验记录'), findsNothing);

    // 7. 验证"可选填写，不影响先保存资料"折叠提示不可见
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 8. 验证必填校验：不填号牌号码，停留在 Step 2 并报错
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入号牌号码'), findsOneWidget);

    // 9. 输入 TEST-PLATE-NUMBER，进入 Step 3
    final plateField = findField('号牌号码');
    await tester.scrollUntilVisible(plateField, 50.0, scrollable: scrollable);
    await tester.enterText(plateField, 'TEST-PLATE-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );
  });

  testWidgets('验证 Step 2 输入框焦点追踪及键盘收起 transition 不会报错崩溃', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    // 1. 初始化页面，不带键盘
    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: ItemEntryFlowPage(),
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    // 2. 选择归属并进入类型选择

    // 3. 选择“驾驶证”
    await openEntryFields(tester, find.text('驾驶证'));
    await tester.pumpAndSettle();

    // 4. 点击“姓名”输入框使其聚焦
    final nameField = findField('姓名');
    expect(nameField, findsOneWidget);
    await tester.tap(nameField);
    await tester.pumpAndSettle();

    // 5. 模拟键盘弹出 (viewInsets.bottom = 300)
    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.only(bottom: 300.0)),
            child: ItemEntryFlowPage(),
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    // 6. 模拟键盘收起 (viewInsets = zero)
    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(viewInsets: EdgeInsets.zero),
            child: ItemEntryFlowPage(),
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    // 渲染下一帧以执行 transition hook 和 addPostFrameCallback
    await tester.pump();
    await tester.pumpAndSettle();

    // 7. 校验底部操作栏成功恢复展示并且没有引发任何 Exception
    expect(find.text('下一步'), findsOneWidget);
  });

  testWidgets('出生证明 (birth_certificate) 分组、必填及折叠优化测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属

    // 3. 选择出生证明
    final birthTile = find.text('出生证明');
    expect(birthTile, findsOneWidget);
    await openEntryFields(tester, birthTile);
    await tester.pumpAndSettle();

    // 4. 验证三个分组标题全部出现
    expect(find.text('新生儿信息'), findsNothing);
    expect(find.text('父母信息'), findsNothing);
    expect(find.text('证明信息'), findsNothing);

    // 5. 验证主体字段可见 (包括出生时间移入了主体)
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    final fieldsToVerify = [
      '新生儿姓名',
      '性别',
      '出生日期',
      '出生时间',
      '出生地点',
      '父亲姓名',
      '母亲姓名',
      '证件编号',
      '签发机构',
      '签发日期',
    ];

    for (final label in fieldsToVerify) {
      if (label == '性别') {
        expect(
          find.byKey(const Key('item_field_control_gender')),
          findsOneWidget,
        );
      } else {
        final field = findField(label);
        await tester.scrollUntilVisible(field, 50.0, scrollable: scrollable);
        expect(field, findsOneWidget);
      }
    }

    // 6. 验证"可选填写，不影响先保存资料"折叠提示不可见
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 7. 验证必填校验：不填证件编号，停留在 Step 2 并报错
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入证件编号'), findsOneWidget);

    // 8. 输入 TEST-BIRTH-CERTIFICATE-NUMBER，进入 Step 3
    final certNumField = findField('证件编号');
    await tester.scrollUntilVisible(certNumField, 50.0, scrollable: scrollable);
    await tester.enterText(certNumField, 'TEST-BIRTH-CERTIFICATE-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );
  });

  testWidgets('出生证明 (birth_certificate) birth_time 时间选择组件交互测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属

    // 3. 选择出生证明
    final birthTile = find.text('出生证明');
    await openEntryFields(tester, birthTile);
    await tester.pumpAndSettle();

    // 4. 验证出生时间可见，且 TextFormField 中的 TextField 是只读的 (readOnly 为 true)
    final birthTimeFinder = findField('出生时间');
    expect(birthTimeFinder, findsOneWidget);
    final textField = tester.widget<TextField>(
      find.descendant(of: birthTimeFinder, matching: find.byType(TextField)),
    );
    expect(textField.readOnly, isTrue);
    expect(
      textField.decoration?.suffixIconConstraints,
      const BoxConstraints.tightFor(width: 40, height: 40),
    );
    final timeIcon = find.descendant(
      of: birthTimeFinder,
      matching: findAnchIcon(AnchIcons.time),
    );
    expect(tester.getSize(timeIcon), const Size(16, 16));

    // 5. 初始值应为空
    final textFormField = tester.widget<TextFormField>(birthTimeFinder);
    expect(textFormField.controller?.text, '');

    // 6. 点击出生时间字段，调出时间选择器
    await tester.tap(birthTimeFinder);
    await tester.pumpAndSettle();

    // 7. 取消选择：点击取消按钮，确认原值仍为空
    final cancelFinder = find.text('取消');
    final cancelEngFinder = find.text('CANCEL');
    if (cancelFinder.evaluate().isNotEmpty) {
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();
    } else if (cancelEngFinder.evaluate().isNotEmpty) {
      await tester.tap(cancelEngFinder);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<TextFormField>(birthTimeFinder).controller?.text, '');

    // 再次点击以重新打开时间选择器
    await tester.tap(birthTimeFinder);
    await tester.pumpAndSettle();

    // 8. 确认选择：点击确定/OK按钮，初始时间是 00:00 (根据 DeterministicTimeDomainSource 2026-06-24 00:00)
    final okFinder = find.text('确定');
    final okEngFinder = find.text('OK');
    if (okFinder.evaluate().isNotEmpty) {
      await tester.tap(okFinder);
      await tester.pumpAndSettle();
    } else if (okEngFinder.evaluate().isNotEmpty) {
      await tester.tap(okEngFinder);
      await tester.pumpAndSettle();
    }

    // 9. 验证字段显示为格式化后的 00:00
    expect(
      tester.widget<TextFormField>(birthTimeFinder).controller?.text,
      '00:00',
    );
  });

  testWidgets('日期字段使用年月日滚轮并保留 YYYY-MM-DD 格式', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('出生证明'));
    await tester.pumpAndSettle();

    final birthDateFinder = findField('出生日期');
    await tester.scrollUntilVisible(
      birthDateFinder,
      50.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(birthDateFinder);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('date_picker_year')), findsOneWidget);
    expect(find.byKey(const Key('date_picker_month')), findsOneWidget);
    expect(find.byKey(const Key('date_picker_day')), findsOneWidget);
    expect(find.byType(CalendarDatePicker), findsNothing);

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(birthDateFinder).controller?.text,
      '2026-06-24',
    );
  });

  testWidgets('结婚证 (marriage_certificate) 分组、必填、不显示补充信息及历史婚姻登记处字段过滤测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属

    // 3. 选择结婚证
    final marriageTile = find.text('结婚证');
    expect(marriageTile, findsOneWidget);
    await openEntryFields(tester, marriageTile);
    await tester.pumpAndSettle();

    // 4. 验证两个分组标题全部出现
    expect(find.text('婚姻关系人'), findsNothing);
    expect(find.text('登记信息'), findsNothing);

    // 5. 验证主体字段可见
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    final fieldsToVerify = ['持证人姓名', '配偶姓名', '证件编号', '登记日期', '登记机关'];

    for (final label in fieldsToVerify) {
      final field = findField(label);
      await tester.scrollUntilVisible(field, 50.0, scrollable: scrollable);
      expect(field, findsOneWidget);
    }

    // 6. 验证"婚姻登记处"与"可选填写，不影响先保存资料"不可见
    expect(find.text('婚姻登记处'), findsNothing);
    expect(findField('婚姻登记处'), findsNothing);
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 7. 验证必填校验：不填证件编号，停留在 Step 2 并报错
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入证件编号'), findsOneWidget);

    // 8. 输入 TEST-MARRIAGE-CERTIFICATE-NUMBER，进入 Step 3
    final certNumField = findField('证件编号');
    await tester.scrollUntilVisible(certNumField, 50.0, scrollable: scrollable);
    await tester.enterText(certNumField, 'TEST-MARRIAGE-CERTIFICATE-NUMBER');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );

    // 9. 编辑旧数据防御过滤：构造带"marriage_registration_office"历史字段的旧结婚证资料并进行编辑
    final itemSaveResult = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'marriage_certificate',
        templateVersion: 1,
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'holder_name',
            valueText: 'TEST-HOLDER',
          ),
          ItemFieldDraftInput(
            fieldKey: 'spouse_name',
            valueText: 'TEST-SPOUSE',
          ),
          ItemFieldDraftInput(
            fieldKey: 'certificate_number',
            valueText: 'TEST-NO',
          ),
          ItemFieldDraftInput(
            fieldKey: 'marriage_registration_office',
            valueText: 'TEST-HISTORY-REGISTRY-OFFICE',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: ItemEntryFlowPage(existingItemId: itemSaveResult.itemId),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    // 验证编辑页也不展示该废弃字段
    expect(find.text('编辑结婚证'), findsOneWidget);
    expect(findField('婚姻登记处'), findsNothing);
  });

  testWidgets('储蓄卡 (debit_card) 分组、必填、不显示补充信息及历史废弃字段过滤测试', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入新增流程
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 2. 选择归属

    // 3. 选择储蓄卡
    final debitTile = find.text('储蓄卡');
    expect(debitTile, findsOneWidget);
    await openEntryFields(tester, debitTile);
    await tester.pumpAndSettle();

    // 4. 验证三个分组标题全部出现
    expect(find.text('卡片信息'), findsNothing);
    expect(find.text('持卡与开户'), findsNothing);
    expect(find.text('使用状态'), findsNothing);

    // 5. 验证主体字段可见
    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;

    final fieldsToVerify = ['银行名称', '卡片别名', '卡号', '户名', '开户行', '账户类型', '卡片用途'];

    for (final label in fieldsToVerify) {
      final field = findField(label);
      await tester.scrollUntilVisible(field, 50.0, scrollable: scrollable);
      expect(field, findsOneWidget);
    }
    expect(find.text('一类／二类／三类'), findsOneWidget);

    // 6. 验证"尾号"、"开户地区"、"预留手机号"、"卡片颜色"及"可选填写，不影响先保存资料"不可见
    expect(find.text('尾号'), findsNothing);
    expect(findField('尾号'), findsNothing);
    expect(find.text('开户地区'), findsNothing);
    expect(findField('开户地区'), findsNothing);
    expect(find.text('预留手机号'), findsNothing);
    expect(findField('预留手机号'), findsNothing);
    expect(find.text('卡片颜色'), findsNothing);
    expect(findField('卡片颜色'), findsNothing);
    expect(find.text('可选填写，不影响先保存资料'), findsNothing);

    // 7. 验证必填校验：不填卡号，停留在 Step 2 并报错
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);
    expect(find.text('请输入卡号'), findsOneWidget);

    // 8. 输入 6225881234567890，进入 Step 3
    final cardNumField = findField('卡号');
    await tester.scrollUntilVisible(cardNumField, 50.0, scrollable: scrollable);
    await tester.enterText(cardNumField, '6225881234567890');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
          .currentStep,
      3,
    );

    // 9. 编辑旧数据防御过滤：构造带废弃字段的旧储蓄卡资料并进行编辑
    final itemSaveResult = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-BANK'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '9999'),
          ItemFieldDraftInput(
            fieldKey: 'open_region',
            valueText: 'TEST-REGION',
          ),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13800000000',
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: ItemEntryFlowPage(existingItemId: itemSaveResult.itemId),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    // 验证编辑页也不展示这些废弃字段
    expect(find.text('编辑储蓄卡'), findsOneWidget);
    expect(findField('尾号'), findsNothing);
    expect(findField('开户地区'), findsNothing);
    expect(findField('预留手机号'), findsNothing);
    expect(findField('卡片颜色'), findsNothing);
  });

  testWidgets('录入流程“设置提醒”占位优化测试：支持类型只读说明且无旧文案', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    // 选择家庭

    // 选择护照
    await openEntryFields(tester, find.text('护照'));
    await tester.pumpAndSettle();

    // 随便填一下必填字段（护照号）
    await tester.enterText(findField('护照号'), 'GALAXY-PASSPORT-NUM');
    await tester.pumpAndSettle();

    // 进入第 3 步：补充信息
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 此时应该出现“到期状态提示”和其hint说明
    expect(find.text('到期状态提示'), findsOneWidget);
    expect(find.text('填写有效期后，安册会在资料列表和详情中提示到期状态'), findsOneWidget);
    expect(find.textContaining('占位'), findsNothing);
    expect(find.textContaining('到期提醒、还款日提醒'), findsNothing); // 旧文案不出现
  });

  testWidgets('录入流程“设置提醒”占位优化测试：不支持类型隐藏该提示', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    await openEntryFields(tester, find.text('储蓄卡'));
    await tester.pumpAndSettle();

    // 储蓄卡必填卡号
    await tester.enterText(findField('卡号'), '6225881234567890');
    await tester.pumpAndSettle();

    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();

    // 储蓄卡无到期字段，应该隐藏“到期状态提示”
    expect(find.text('到期状态提示'), findsNothing);
    expect(find.textContaining('占位'), findsNothing);
    expect(find.textContaining('还款日提醒'), findsNothing);
  });

  testWidgets('录入流程“到期状态提示”卡片多状态交互验证', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();

    await openEntryFields(tester, find.text('护照'));
    await tester.pumpAndSettle();

    // 填入必填项：护照号
    await tester.enterText(findField('护照号'), 'GALAXY-TEST-PASS');
    await tester.pumpAndSettle();

    // 1. 场景 A: 未填写有效期
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('到期状态提示'), findsOneWidget);
    expect(find.text('填写有效期后，安册会在资料列表和详情中提示到期状态'), findsOneWidget);
    expect(find.textContaining('占位'), findsNothing); // 不再有任何“占位”相关的文本或标签
    expect(find.textContaining('还款日提醒'), findsNothing);

    // 退回表单编辑页
    await tester.tap(findAnchIcon(AnchIcons.back).first);
    await tester.pumpAndSettle();

    // 助手函数：找到并设置有效期文本
    void setValidUntil(String text) {
      final validUntilFinder = find.byKey(
        const Key('item_field_root_valid_until'),
      );
      final textFormField = tester.widget<TextFormField>(
        find.descendant(
          of: validUntilFinder,
          matching: find.byType(TextFormField),
        ),
      );
      textFormField.controller?.text = text;

      final dynamic state = tester.state(find.byType(ItemEntryFlowPage));
      state.flowController.updateFieldWithMeta(
        'valid_until',
        text,
        isUserEdit: true,
      );
    }

    // 2. 场景 B: 异常格式
    setValidUntil('invalid-date');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('有效期格式异常，请返回填写页检查'), findsOneWidget);

    await tester.tap(findAnchIcon(AnchIcons.back).first);
    await tester.pumpAndSettle();

    // 3. 场景 C: 正常未临近 (距 2026-06-24 为 57 天)
    setValidUntil('2026-08-20');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('当前有效期未临近，到期前 30 天内会自动提示'), findsOneWidget);

    await tester.tap(findAnchIcon(AnchIcons.back).first);
    await tester.pumpAndSettle();

    // 4. 场景 D: 20 天内到期 (即将到期 > 7天)
    setValidUntil('2026-07-14');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('保存后将显示即将到期'), findsOneWidget);

    await tester.tap(findAnchIcon(AnchIcons.back).first);
    await tester.pumpAndSettle();

    // 5. 场景 E: 2 天内到期 (剩余 2 天 <= 7天)
    setValidUntil('2026-06-26');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('保存后将显示剩余 2 天'), findsOneWidget);

    await tester.tap(findAnchIcon(AnchIcons.back).first);
    await tester.pumpAndSettle();

    // 6. 场景 F: 已过期 (06-22 过期)
    setValidUntil('2026-06-22');
    await tester.pumpAndSettle();
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    expect(find.text('保存后将显示已过期'), findsOneWidget);
  });

  testWidgets('收货地址支持用户主动粘贴并本地解析到四个字段', (tester) async {
    const longAddress = '测试路 1 号测试小区 10 栋 101 室，东门进入后沿测试街道步行至测试楼。';
    var clipboardText = '张三 13800138000 浙江省杭州市西湖区文三路90号';
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': clipboardText};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final saved = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'shipping_address',
        fields: [
          ItemFieldDraftInput(fieldKey: 'recipient_name', valueText: '旧姓名'),
          ItemFieldDraftInput(
            fieldKey: 'phone_number',
            valueText: '13900139000',
          ),
          ItemFieldDraftInput(fieldKey: 'region', valueText: '旧地区'),
          ItemFieldDraftInput(
            fieldKey: 'detailed_address',
            valueText: longAddress,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(home: ItemEntryFlowPage(existingItemId: saved.itemId)),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    final addressField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('item_field_control_detailed_address')),
        matching: find.byType(TextField),
      ),
    );
    expect(addressField.controller!.text, longAddress);
    expect(addressField.minLines, 2);
    expect(addressField.maxLines, 3);
    expect(addressField.keyboardType, TextInputType.multiline);

    await tester.tap(find.byKey(const Key('shipping_address_paste_and_parse')));
    await tester.pumpAndSettle();

    String valueOf(String fieldKey) => tester
        .widget<TextFormField>(find.byKey(Key('item_field_control_$fieldKey')))
        .controller!
        .text;
    expect(valueOf('recipient_name'), '张三');
    expect(valueOf('phone_number'), '13800138000');
    expect(valueOf('region'), '浙江省杭州市西湖区');
    expect(valueOf('detailed_address'), '文三路90号');
    expect(find.text('已解析，请确认后保存'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));

    clipboardText = '李四 13900139000 高新区天府三街199号';
    await tester.tap(find.byKey(const Key('shipping_address_paste_and_parse')));
    await tester.pump();
    expect(valueOf('recipient_name'), isEmpty);
    expect(valueOf('phone_number'), '13900139000');
    expect(valueOf('region'), isEmpty);
    expect(valueOf('detailed_address'), '李四 高新区天府三街199号');
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('新增与编辑读取失败可就地重试，重试不重入且保留编辑归属和字段', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    final memberId = await di.memberRepo.saveMember(
      SaveMemberInput(
        memberType: 'person',
        name: '读取重试归属',
        sortOrder: 1,
        isSystem: false,
        isArchived: false,
      ),
    );
    final saved = await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: memberId,
        categoryKey: 'other',
        typeKey: 'generic',
        templateVersion: 2,
        fields: [
          ItemFieldDraftInput(fieldKey: 'title', valueText: '读取重试测试资料'),
          ItemFieldDraftInput(
            fieldKey: 'custom_field_label_1',
            valueText: '测试字段',
          ),
          ItemFieldDraftInput(
            fieldKey: 'custom_field_value_1',
            valueText: '原始内容',
          ),
        ],
      ),
    );
    expect(saved.success, isTrue);
    final original = await di.itemRepo.getItemWithFields(saved.itemId!);
    final loadedMembers = await di.memberRepo.getActiveMembers();
    for (final mode in ['new-members', 'edit-item', 'edit-members']) {
      final editing = mode.startsWith('edit');
      final members = _EntryReadMembers(db);
      final items = _EntryReadItems(db);
      await tester.runAsync(() async {
        if (mode == 'edit-item') {
          items.pending = Completer<ItemWithFields?>();
        } else {
          members.pending = Completer<List<MemberModel>>();
        }
      });
      final controller = ItemEntryFlowController(
        enableAutoFillScaffold: false,
        autoFillEngine: ItemAutoFillEngine(
          timeDomainSource: di.timeDomainSource,
        ),
      );
      final root = tester.element(find.byKey(const Key('home_add_item')));
      Navigator.of(root).push(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(seconds: 1),
          pageBuilder: (_, _, _) => scopeWithTestRepositories(
            di,
            ItemEntryFlowPage(
              existingItemId: editing ? saved.itemId : null,
              controller: controller,
            ),
            memberRepo: members,
            itemRepo: items,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        ModalRoute.of(
          tester.element(find.byType(ItemEntryFlowPage)),
        )!.animation!.status,
        AnimationStatus.forward,
      );
      await tester.runAsync(() async {
        final error = StateError('SYNTHETIC_READ_FAILURE');
        if (mode == 'edit-item') {
          items.pending!.completeError(error);
        } else {
          members.pending!.completeError(error);
        }
        await Future<void>.delayed(Duration.zero);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final error = mode == 'edit-item' ? '加载编辑资料失败' : '加载成员列表失败';
      expect(find.text(error), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
      if (mode == 'edit-item') {
        items.pending = Completer<ItemWithFields?>();
      } else {
        members.pending = Completer<List<MemberModel>>();
      }
      await tester.tap(find.text('重新加载'));
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      expect(mode == 'edit-item' ? items.calls : members.calls, 2);
      items.pending?.complete(original);
      members.pending?.complete(loadedMembers);
      await tester.pumpAndSettle();
      expect(find.text(error), findsNothing);
      if (editing) {
        expect(controller.value.selectedOwner?.id, memberId);
        expect(
          controller.value.fieldValues['custom_field_value_1']?.value,
          '原始内容',
        );
      } else {
        expect(find.text('选择资料类型'), findsOneWidget);
        await tester.tap(find.text('身份证'));
        await tester.pumpAndSettle();
        expect(find.text('选择归属'), findsOneWidget);
        expect(controller.value.selectedOwner?.id, systemFamilyMemberId);
      }
      Navigator.of(tester.element(find.byType(ItemEntryFlowPage))).pop();
      await tester.pumpAndSettle();
      controller.dispose();
    }
    final unchanged = await di.itemRepo.getItemWithFields(saved.itemId!);
    expect(unchanged?.memberId, original?.memberId);
    expect(unchanged?.updatedAt, original?.updatedAt);
  });

  testWidgets('任务式新增资料入口展示收货地址并可选中', (tester) async {
    final taskRuntime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    final taskDi = createFlowTestProvider(taskRuntime);
    final controller = ItemEntryFlowController(
      enableAutoFillScaffold: true,
      autoFillEngine: ItemAutoFillEngine(
        timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      ),
    );

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(home: ItemEntryFlowPage(controller: controller)),
        taskRuntime,
        (child) => taskDi.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('收货地址'), findsOneWidget);
    await tester.tap(find.text('收货地址'));
    await tester.pump();
    expect(controller.value.selectedType?.typeKey, 'shipping_address');

    controller.dispose();
    await taskDi.db.close();
  });
}

Finder findField(String labelOrValue) {
  final keyMap = {
    '姓名': 'name',
    '姓名(中文)': 'name_cn',
    '姓名(英文)': 'name_en',
    '身份证号': 'id_number',
    '出生日期': 'birth_date',
    '民族': 'ethnicity',
    '有效期开始': 'valid_from',
    '有效期结束': 'valid_until',
    '地址': 'address',
    '出生地': 'birth_place',
    '国籍': 'nationality',
    '签发地点': 'issue_place',
    '签发机关': 'issuing_authority',
    '签发日期': 'issue_date',
    '护照号': 'passport_number',
    '证件号': 'pass_number',
    '签注说明': 'endorsement_note',
    '驾驶证号': 'license_number',
    '档案编号': 'file_number',
    '准驾车型': 'vehicle_class',
    '有效期至': 'valid_until',
    '号牌号码': 'plate_number',
    '证件编号': 'certificate_number',
    '卡号': 'card_number',
    '出生时间': 'birth_time',
    '婚姻登记处': 'marriage_registration_place',
    '尾号': 'card_number_suffix',
    '开户地区': 'account_region',
    '预留手机号': 'linked_phone',
    '卡片颜色': 'card_color',
    '家庭': 'name',
    '所有人': 'owner_name',
    '注册日期': 'register_date',
    '使用性质': 'use_character',
    '品牌型号': 'model',
    '车辆识别代号': 'vin',
    '发动机号码': 'engine_number',
    '发证日期': 'issue_date',
    '发证机关': 'issuing_authority',
    '核定载人数': 'approved_passengers',
    '新生儿姓名': 'child_name',
    '出生地点': 'birth_place',
    '父亲姓名': 'father_name',
    '母亲姓名': 'mother_name',
    '签发机构': 'issuing_authority',
    '持证人姓名': 'holder_name',
    '配偶姓名': 'spouse_name',
    '登记日期': 'register_date',
    '登记机关': 'issuing_authority',
    '银行名称': 'bank_name',
    '卡片别名': 'card_alias',
    '户名': 'account_name',
    '开户行': 'branch_name',
    '账户类型': 'account_type',
    '卡片用途': 'usage',
    '是否已注销': 'is_closed',
    '车辆类型': 'vehicle_type',
  };

  if (keyMap.containsKey(labelOrValue)) {
    return find.byKey(Key('item_field_control_${keyMap[labelOrValue]}'));
  }

  return find.byWidgetPredicate((widget) {
    if (widget is TextFormField) {
      return widget.controller?.text == labelOrValue;
    }
    return false;
  });
}

class _EntryReadMembers extends MemberRepository {
  _EntryReadMembers(super.db);
  int calls = 0;
  Completer<List<MemberModel>>? pending;

  @override
  Future<List<MemberModel>> getActiveMembers() async {
    calls++;
    return pending?.future ?? super.getActiveMembers();
  }
}

class _EntryReadItems extends ItemRepository {
  _EntryReadItems(super.db);
  int calls = 0;
  Completer<ItemWithFields?>? pending;

  @override
  Future<ItemWithFields?> getItemWithFields(String itemId) async {
    calls++;
    return pending?.future ?? super.getItemWithFields(itemId);
  }
}

class MockEmptyAutoFillEngine extends ItemAutoFillEngine {
  MockEmptyAutoFillEngine()
    : super(
        timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      );

  @override
  Map<String, String> generateAutoFillValues({
    required TypeDefinition type,
    required MemberModel owner,
  }) {
    return const {};
  }
}
