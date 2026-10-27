import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/repository/models/item_child_entry_model.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:drift/drift.dart' as drift;
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/widgets/anch_page_header.dart';
import '../support/test_bootstrap.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemRepository itemRepo;

  setUp(() {
    ItemGlobalRegistry.instance.clear();
    runtime = RuntimeProvider.create(const AnchSecurityRuntimeConfig(
      mode: AnchSecurityMode.dev,
      useEncryptedDatabase: false,
      enableSecureWindow: false,
      enablePrivacyShieldOverlay: false,
      enableAppLockGate: false,
      isFormalBlocked: false,
    ));
    di = DependencyProvider.create(
      runtime: runtime,
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 30)),
      child: Container(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return wrapTest(const AnchApp(), runtime, (child) => di.copyWith(child: child));
  }

  group('户口本多成员录入 UI 集成测试 (C2-2)', () {
    testWidgets('1. Step3 户口本显示“户内成员（可选）”模块及空状态卡片', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 点击新增资料进入流
      await tester.tap(find.byKey(const Key('home_add_item')));
      await tester.pumpAndSettle();

      // Step 0: 选择归属

      // Step 1: 选择类型 -> 户口本
      await openEntryFields(tester, find.text('户口本'));
      await tester.pumpAndSettle();

      // Step 2: 填写字段
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '12345678'); // 户号
      await tester.pumpAndSettle();

      // 点击下一步：补充信息
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // Step 3: 验证显示“户内成员（可选）”模块与空状态卡片
      expect(find.text('户内成员（可选）'), findsOneWidget);
      expect(find.text('可添加户内成员信息，也可以只上传户口本照片后保存'), findsOneWidget);
      expect(find.byKey(const Key('add-member-empty-btn')), findsOneWidget);

      // 验证模块顺序：“户内成员（可选）”必须出现在“附件”之前
      final memberSectionTop = tester.getTopLeft(find.text('户内成员（可选）')).dy;
      final attachmentsSectionTop = tester.getTopLeft(find.text('附件')).dy;
      expect(memberSectionTop < attachmentsSectionTop, isTrue);

      // 验证全局移除了冗余的二级标题和提示说明，但保留了页面顶部的标题
      expect(find.descendant(of: find.byType(AnchFlowHeader), matching: find.text('新增户口本')), findsOneWidget);
      expect(find.descendant(of: find.byType(ListView), matching: find.text('补充信息')), findsNothing);
      expect(find.text('可添加附件照片作为补充说明'), findsNothing);
    });

    testWidgets('2. 新建户口本不添加成员直接保存', (WidgetTester tester) async {
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

      await openEntryFields(tester, find.text('户口本'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '11112222');
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 点击保存资料
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      // 验证保存成功并跳转至详情页
      expect(find.text('户口本'), findsOneWidget);

      final items = await db.select(db.items).get();
      expect(items.length, equals(1));

      // 验证子成员数据为 0
      final childEntries = await itemRepo.getChildEntries(items.first.id);
      expect(childEntries, isEmpty);
    });

    testWidgets('3. 添加单成员与多成员保存及 sortOrder/掩码安全性测试', (WidgetTester tester) async {
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

      await openEntryFields(tester, find.text('户口本'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '33334444');
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 1. 点击添加成员开启 BottomSheet
      await tester.tap(find.byKey(const Key('add-member-empty-btn')));
      await tester.pumpAndSettle();

      expect(find.text('添加户内成员'), findsOneWidget);

      // 全部空白时点击保存，被姓名或身份证同时为空规则拦截
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-form-error-text')), findsOneWidget);
      expect(find.text('请填写成员姓名或身份证号'), findsOneWidget);

      // 仅填写籍贯，姓名和身份证为空，保存依然被拦截
      final textInputs = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputs.at(5), '北京'); // 籍贯
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('member-form-error-text')), findsOneWidget);

      // 清除籍贯，填写姓名“张三”，关系为空，保存成功
      await tester.enterText(textInputs.at(5), ''); // 籍贯
      await tester.enterText(textInputs.at(0), '张三'); // 成员姓名
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 2. 验证第一个成员卡片呈现在列表中
      expect(find.text('张三'), findsOneWidget);
      // 无关系时不显示关系标签，因此页面上不应有“关系未填写”或类似标签
      expect(find.text('关系未填写'), findsNothing);

      // 3. 继续添加第二个成员（仅填身份证号）
      await tester.tap(find.text('添加成员'));
      await tester.pumpAndSettle();

      final textInputs2 = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputs2.at(2), '11010119900307234x'); // 身份证号，带小写 x
      await tester.pumpAndSettle();

      // 验证小写 x 自动转大写 X
      final idNumField = tester.widget<TextField>(textInputs2.at(2));
      expect(idNumField.controller?.text, equals('11010119900307234X'));

      // 点击保存
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 验证姓名为空但身份证非空时，卡片显示“未填写姓名”，并且只展示“******”作为身份证脱敏
      expect(find.text('未填写姓名'), findsOneWidget);
      expect(find.textContaining('******'), findsOneWidget);
      expect(find.text('11010119900307234X'), findsNothing);

      // 4. 保存草稿
      await tester.tap(find.text('保存资料'));
      await tester.pumpAndSettle();

      expect(find.text('户口本'), findsOneWidget);

      final items = await db.select(db.items).get();
      expect(items.length, equals(1));

      // 5. 校验数据库中的多成员属性与 sortOrder 递增
      final childEntries = await itemRepo.getChildEntries(items.first.id);
      expect(childEntries.length, equals(2));
      expect(childEntries[0].sortOrder, equals(0));
      expect(childEntries[0].fields.firstWhere((f) => f.fieldKey == 'member_name').valueText, equals('张三'));
      expect(childEntries[1].sortOrder, equals(1));
      expect(childEntries[1].fields.firstWhere((f) => f.fieldKey == 'member_id_number').valueText, equals('11010119900307234X'));
    });

    testWidgets('4. 编辑已有户口本回填、更新、删除与清空测试', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // 1. 初始化带有多成员的户口本数据
      final itemId = 'existing_hb_id';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.into(db.items).insert(ItemsCompanion.insert(
        id: itemId,
        originId: itemId,
        memberId: const drift.Value('00000000-0000-4000-8000-000000000001'),
        categoryKey: const drift.Value('certificate'),
        typeKey: const drift.Value('household_book'),
        templateVersion: const drift.Value(1),
        title: const drift.Value('已存户口本'),
        createdAt: now,
        updatedAt: now,
      ));

      await itemRepo.saveItemWithFields(SaveItemInput(
        id: itemId,
        memberId: '00000000-0000-4000-8000-000000000001',
        categoryKey: 'certificate',
        typeKey: 'household_book',
        templateVersion: 1,
        title: '已存户口本',
        primaryText: '',
        searchText: '已存户口本 张三 李四',
        summaryText: '已记录 2 位成员',
        fields: [
          SaveItemFieldInput(fieldKey: 'household_number', valueType: FieldValueType.text, valueText: '55556666'),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            id: 'm1_id',
            childType: 'household_member',
            sortOrder: 0,
            fields: [
              SaveItemChildFieldInput(fieldKey: 'member_name', label: '姓名', valueText: '张三', valueType: 'text', sensitiveLevel: 'medium', searchable: true),
              SaveItemChildFieldInput(fieldKey: 'relation_to_head', label: '关系', valueText: '本人', valueType: 'text', sensitiveLevel: 'none'),
            ],
          ),
          SaveItemChildEntryInput(
            id: 'm2_id',
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(fieldKey: 'member_name', label: '姓名', valueText: '李四', valueType: 'text', sensitiveLevel: 'medium', searchable: true),
              SaveItemChildFieldInput(fieldKey: 'relation_to_head', label: '关系', valueText: '配偶', valueType: 'text', sensitiveLevel: 'none'),
            ],
          ),
        ],
      ));

      // 2. 模拟编辑模式打开页面
      await tester.pumpWidget(wrapTest(
        MaterialApp(
          key: UniqueKey(),
          home: ItemEntryFlowPage(existingItemId: itemId),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ));
      
      // 等待加载中状态结束
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // 在 Step 2 (编辑资料)
      expect(find.text('编辑户口本'), findsOneWidget);

      // 点击下一步：补充信息
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 3. 验证回填成员张三、李四均渲染在 Step3 列表中
      expect(find.text('张三'), findsOneWidget);
      expect(find.text('李四'), findsOneWidget);

      // 4. 编辑成员李四 -> 改为王五，关系不变
      final editButtons = findAnchIcon(AnchIcons.edit);
      expect(editButtons, findsNWidgets(2));

      await tester.tap(editButtons.at(1)); // 第二个是李四
      await tester.pumpAndSettle();

      expect(find.text('编辑户内成员'), findsOneWidget);
      final textInputs = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputs.at(0), '王五'); // 成员姓名
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('王五'), findsOneWidget);
      expect(find.text('李四'), findsNothing); // 已更名为王五

      // 5. 点击删除成员张三
      final deleteButtons = findAnchIcon(AnchIcons.delete);
      expect(deleteButtons, findsNWidgets(2));

      await tester.tap(deleteButtons.at(0)); // 第一个是张三
      await tester.pumpAndSettle();

      // 验证二次确认弹框
      expect(find.text('确认删除成员'), findsOneWidget);
      expect(find.text('确定要删除该户内成员信息吗？'), findsOneWidget);

      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 确认删除后，列表中应该只有王五
      expect(find.text('张三'), findsNothing);
      expect(find.text('王五'), findsOneWidget);

      // 6. 保存修改
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      // 验证数据库王五的 sortOrder 被重构规范为 0
      final finalChildEntries = await itemRepo.getChildEntries(itemId);
      expect(finalChildEntries.length, equals(1));
      expect(finalChildEntries.first.fields.firstWhere((f) => f.fieldKey == 'member_name').valueText, equals('王五'));
      expect(finalChildEntries.first.sortOrder, equals(0));

      // 7. 测试清空全部成员：重新进入编辑，删除王五并保存
      await tester.pumpWidget(wrapTest(
        MaterialApp(
          key: UniqueKey(),
          home: ItemEntryFlowPage(existingItemId: itemId),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ));
      
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      expect(find.text('王五'), findsOneWidget);
      await tester.tap(findAnchIcon(AnchIcons.delete).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // 列表已空，显示空文案
      expect(find.text('可添加户内成员信息，也可以只上传户口本照片后保存'), findsOneWidget);

      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      // 验证成员被彻底清除
      final clearedChildEntries = await itemRepo.getChildEntries(itemId);
      expect(clearedChildEntries, isEmpty);
    });

    testWidgets('5. 非户口本模板不显示户内成员录入模块', (WidgetTester tester) async {
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

      // 选择身份证
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // 输入必填信息以能通过校验
      await tester.enterText(find.byKey(const Key('item_field_control_name')), '张三');
      await tester.enterText(find.byKey(const Key('item_field_control_id_number')), '110101199003072345');
      // 选择性别
      await tester.tap(find.bySemanticsLabel('性别－男'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 验证不显示“户内成员（可选）”
      expect(find.text('户内成员（可选）'), findsNothing);
      expect(find.text('可添加户内成员信息，也可以只上传户口本照片后保存'), findsNothing);
    });

    testWidgets('6. 重复身份证号检测及大小写不敏感判断', (WidgetTester tester) async {
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

      await openEntryFields(tester, find.text('户口本'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), '99998888');
      await tester.pumpAndSettle();

      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 1. 添加第一个成员，身份证 11010119900307234X
      await tester.tap(find.byKey(const Key('add-member-empty-btn')));
      await tester.pumpAndSettle();

      final textInputs1 = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputs1.at(0), '张三');
      await tester.enterText(textInputs1.at(2), '11010119900307234X');
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 2. 测试短身份证号（例如 12）不触发重复检测，且允许成功保存
      await tester.tap(find.text('添加成员'));
      await tester.pumpAndSettle();

      final textInputsShort = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputsShort.at(0), '李四');
      await tester.enterText(textInputsShort.at(2), '12'); // 短号
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(find.text('李四'), findsOneWidget); // 成功添加

      // 3. 添加第三个成员，身份证输入小写 11010119900307234x（18位），应被强重复校验拦截并提示已存在
      await tester.tap(find.text('添加成员'));
      await tester.pumpAndSettle();

      final textInputs3 = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextField));
      await tester.enterText(textInputs3.at(0), '王五');
      await tester.enterText(textInputs3.at(2), '11010119900307234x');
      await tester.pumpAndSettle();

      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 验证提示错误，不关闭 BottomSheet
      expect(find.byKey(const Key('member-form-error-text')), findsOneWidget);
      expect(find.text('该身份证号已存在'), findsOneWidget);

      // 关闭/取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 4. 测试编辑第一个成员张三时，不与自己冲突
      // 当前列表有：张三、李四。找张三的编辑按钮 (第一个 edit icon)
      final editButtons = findAnchIcon(AnchIcons.edit);
      expect(editButtons, findsNWidgets(2));
      await tester.tap(editButtons.at(0));
      await tester.pumpAndSettle();

      // 编辑对话框打开
      expect(find.text('编辑户内成员'), findsOneWidget);
      // 直接点击保存
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      // 能够顺利保存，没有重复报错，且编辑框关闭了
      expect(find.text('编辑户内成员'), findsNothing);
      expect(find.text('张三'), findsOneWidget);
    });
  });
}
