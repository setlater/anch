import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/core/widgets/anch_adaptive_layout.dart';

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

  Widget buildTestWidget() {
    return wrapTest(
      const AnchApp(),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  testWidgets('DatePicker 交互与格式写入测试', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 进入身份证填写页
    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(find.text('填写核心信息')).style?.fontSize, 18);
    addTearDown(tester.view.resetViewInsets);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsNothing);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('填写核心信息'), findsOneWidget);

    final gender = find.bySemanticsLabel('性别－男');
    expect(tester.getSize(gender).height, greaterThanOrEqualTo(48));

    // 日期提示与图标明确选择行为，整项仍可点击。
    final dateField = find.byKey(const Key('item_field_control_birth_date'));
    expect(dateField, findsOneWidget);
    expect(
      find.descendant(of: dateField, matching: find.text('选择日期')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dateField,
        matching: findAnchIcon(AnchIcons.calendar),
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      dateField,
      100.0,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(dateField);
    await tester.pumpAndSettle();

    // 此时应当拉起标准 DatePicker，验证中文按钮文本并点击
    final cancelButton = find.text('取消');
    expect(cancelButton, findsOneWidget);

    final okButton = find.text('确定');
    expect(okButton, findsOneWidget);
    await tester.tap(okButton);
    await tester.pumpAndSettle();

    // 验证出生日期输入框已被填入 yyyy-MM-dd 格式值（即当前年份，例如 2026-06-10）
    final todayStr =
        "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    final dateTextField = tester.widget<TextFormField>(dateField);
    expect(dateTextField.controller?.text, todayStr);
  });

  testWidgets('身份证有效期在局部空间不足时自动由双列重排为单列', (WidgetTester tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(360, 800));
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    final dateColumns = find.byType(AnchResponsiveColumns);
    expect(dateColumns, findsOneWidget);
    expect(
      find.descendant(
        of: dateColumns,
        matching: find.byKey(const Key('anch_responsive_columns_column')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.binding.setSurfaceSize(const Size(412, 800));
    await tester.pump();
    expect(
      find.descendant(
        of: dateColumns,
        matching: find.byKey(const Key('anch_responsive_columns_row')),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('idNumber 前段与尾号约束测试', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    final idField = find.byKey(const Key('item_field_control_id_number'));
    expect(idField, findsOneWidget);

    // 1. 测试前 17 位限制非数字：输入 "110A"
    await tester.enterText(idField, '110A');
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(idField).controller?.text, '110');

    // 2. 测试第 18 位允许 X/x：输入 17 位纯数字后加 'X'
    await tester.enterText(idField, '11010119900307234X');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(idField).controller?.text,
      '11010119900307234X',
    );

    // 3. 测试第 18 位拦截非 X/x：输入 17 位纯数字后加 'A'
    await tester.enterText(idField, '11010119900307234A');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(idField).controller?.text,
      '11010119900307234',
    );

    // 4. 测试超出 18 位限制：输入 19 位
    await tester.enterText(idField, '1101011990030723456');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextFormField>(idField).controller?.text,
      '110101199003072345',
    );
  });

  testWidgets('bankCardNumber 只允许纯数字测试', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();

    // 先点击“证件资料”把长列表收起，防止“储蓄卡”被遮挡不渲染

    await openEntryFields(tester, find.text('储蓄卡'));
    await tester.pumpAndSettle();

    final cardField = find.byKey(const Key('item_field_control_card_number'));
    expect(cardField, findsOneWidget);

    // 输入 "6225abc"
    await tester.enterText(cardField, '6225abc');
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(cardField).controller?.text, '6225');
  });

  testWidgets('身份证号自动联动推导出生日期与性别测试', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    final idField = find.byKey(const Key('item_field_control_id_number'));
    final birthField = find.byKey(const Key('item_field_control_birth_date'));

    // 1. 输入生日段为 19900230 的非法日期身份证号，不应自动推导填充 birth_date，但性别可正常独立推导
    await tester.enterText(idField, '110101199002302345');
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(birthField).controller?.text, '');
    final femaleSemantics = tester.getSemantics(find.bySemanticsLabel('性别－女'));
    expect(
      femaleSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    // 2. 输入第17位是偶数的合法身份证，推导为 "1990-03-07" 和 "女"
    await tester.enterText(idField, '110101199003072345');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextFormField>(birthField).controller?.text,
      '1990-03-07',
    );
    final femaleSemantics2 = tester.getSemantics(find.bySemanticsLabel('性别－女'));
    expect(
      femaleSemantics2.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );

    // 3. 输入第 17 位是奇数的合法身份证，推导为 "男"
    await tester.enterText(idField, '110101199003072335');
    await tester.pumpAndSettle();
    final maleSemantics3 = tester.getSemantics(find.bySemanticsLabel('性别－男'));
    expect(
      maleSemantics3.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('联动防覆盖机制测试：手动更改后不被覆盖', (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('home_add_item')).first);
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    final idField = find.byKey(const Key('item_field_control_id_number'));
    final birthField = find.byKey(const Key('item_field_control_birth_date'));

    // 1. 用户首先手动设定性别为 "女"
    await tester.tap(find.bySemanticsLabel('性别－女'));
    await tester.pumpAndSettle();

    // 2. 更改身份证号（按照其规则本来推导性别应为“男”）
    await tester.enterText(idField, '110101199003072335');
    await tester.pumpAndSettle();

    // 验证：出生日期被联动推导为了 "1990-03-07"，但性别没有被推导覆盖，依然保持 "女"
    expect(
      tester.widget<TextFormField>(birthField).controller?.text,
      '1990-03-07',
    );
    final femaleSemantics = tester.getSemantics(find.bySemanticsLabel('性别－女'));
    expect(
      femaleSemantics.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('首页会话只读入口与详情跳转验证测试', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // 1. 初始状态下由于去重空状态，资料区块被隐藏，不显示空状态提示与按钮
    expect(find.text('本次运行还没有保存任何资料'), findsNothing);
    expect(find.text('资料'), findsNothing);

    // 2. 新增一个资料
    await tester.tap(find.byKey(const Key('home_add_item')));
    await tester.pumpAndSettle();
    await openEntryFields(tester, find.text('身份证'));
    await tester.pumpAndSettle();

    final textFormFields = find.byType(TextFormField);
    await tester.enterText(textFormFields.at(0), '李四');
    await tester.enterText(textFormFields.at(1), '110101199003072335');
    await tester.pumpAndSettle();

    // 保存
    await tester.tap(find.text('下一步'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存资料'));
    await tester.pumpAndSettle();

    // 进入详情页，点击 Home 按钮返回首页
    expect(find.text('身份证'), findsOneWidget);
    await tester.tap(findAnchIcon(AnchIcons.home));
    await tester.pumpAndSettle();

    // 验证没有 SnackBar 弹出
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpAndSettle();

    // 3. 首页应该显示刚才录入的会话记录
    expect(find.text('李四的身份证'), findsOneWidget);
    expect(find.text('全部资料'), findsOneWidget);

    // 4. 点击该只读列表项，能进入详情页
    final itemFinder = find.text('李四的身份证');
    await tester.scrollUntilVisible(itemFinder, 50.0);
    await tester.pumpAndSettle();
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();
    expect(find.text('身份证'), findsOneWidget);

    expect(
      find.text('••••  ••••  ••••  2335'),
      findsOneWidget,
    ); // 且 high 敏感字段为掩码
  });
}
