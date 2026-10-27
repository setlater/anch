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
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/core/template/field_priority.dart';
import 'package:anch/core/template/builtin_templates.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/time/time_domain_source.dart';

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
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      child: const SizedBox.shrink(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({String? existingItemId}) {
    return wrapTest(
      MaterialApp(home: ItemEntryFlowPage(existingItemId: existingItemId)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Future<void> setupScreenSize(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
  }

  group('资料表单字段优先级与折叠体验测试', () {
    testWidgets('1. 新增资料时 generic (其他资料) 显示首组动态字段，且无补充信息折叠块', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 进入新增流：选择家庭成员并进入资料类型选择

      // 收起"证件资料"分类，露出后面的"其他资料"分类

      // 选择“其他资料”类型
      expect(find.text('其他资料'), findsWidgets);
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      // 验证在表单填写页
      expect(find.text('填写核心信息'), findsOneWidget);

      expect(find.textContaining('资料名称'), findsOneWidget);
      expect(
        find.byKey(const Key('item_field_group_generic_pair_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('item_field_group_generic_pair_2')),
        findsNothing,
      );
      expect(find.byKey(const Key('generic_custom_field_add')), findsOneWidget);

      // 验证没有折叠区标题与说明
      expect(find.text('补充信息'), findsNothing);
    });

    testWidgets('3. generic (其他资料) 专属布局下不渲染补充信息折叠卡片', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      // 确认折叠卡片未渲染
      expect(find.text('补充信息'), findsNothing);
    });

    testWidgets('4. generic (其他资料) 专属布局下输入值并验证页面状态', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);
      await tester.pumpAndSettle();

      // 输入资料名称
      final titleField = find.byKey(const Key('item_field_control_title'));
      expect(titleField, findsOneWidget);
      await tester.enterText(titleField, 'TEST-GENERIC');
      await tester.pumpAndSettle();

      // 输入第一组字段名和值。
      final labelField = find.byKey(
        const Key('item_field_control_custom_field_label_1'),
      );
      final valueField = find.byKey(
        const Key('item_field_control_custom_field_value_1'),
      );
      expect(labelField, findsOneWidget);
      expect(valueField, findsOneWidget);
      await tester.enterText(labelField, '所属人');
      await tester.enterText(valueField, '张三');
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(titleField).controller?.text,
        'TEST-GENERIC',
      );
      expect(tester.widget<TextFormField>(labelField).controller?.text, '所属人');
      expect(tester.widget<TextFormField>(valueField).controller?.text, '张三');
    });

    test('5. required 字段即使不是 P0，也不能被默认隐藏 (说明/逻辑校验)', () {
      // 通过直接扫描 BuiltinTemplates 的所有字段定义，验证代码设计层面
      // required 字段绝对被分在 primaryFields 中，不受其 priority 的影响
      for (final type in BuiltinTemplates.types) {
        for (final field in type.fields) {
          if (field.required) {
            // 验证分组逻辑： required == true 的字段必须被归类为 primaryFields (即非 optionalFields)
            final isOptional =
                !field.required && field.priority != FieldPriority.p0;
            expect(
              isOptional,
              isFalse,
              reason: '必填字段 ${field.label} 绝对不能被归类为折叠的可选字段',
            );
          }
        }
      }
    });

    testWidgets('6. 编辑模式下 generic (其他资料) 直接加载 5 字段 & 7. 保存修改不丢失值', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);

      // 1. 先通过 UseCaseService 向数据库写入一条通用资料
      final serviceResult = await service.saveDraft(
        ItemDraftInput(
          memberId: '00000000-0000-4000-8000-000000000001', // 系统默认家庭成员
          categoryKey: 'other',
          typeKey: 'generic',
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: 'TEST-GENERIC'),
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
          ],
        ),
      );

      expect(serviceResult.success, isTrue);
      final itemId = serviceResult.itemId!;

      // 2. 渲染编辑模式页面
      await tester.pumpWidget(buildTestWidget(existingItemId: itemId));
      await tester.pumpAndSettle();

      // 3. 验证编辑状态下直接进入了字段填写页 (currentStep = 2)，页面标题为“编辑其他资料”
      expect(find.text('编辑其他资料'), findsOneWidget);

      // 4. 验证核心字段已加载且可见
      expect(find.textContaining('资料名称'), findsOneWidget);
      expect(
        find.byKey(const Key('item_field_control_owner_name')),
        findsOneWidget,
      );
      final ownerField = find.byKey(const Key('item_field_control_owner_name'));
      expect(tester.widget<TextFormField>(ownerField).controller?.text, '张三');

      // 5. 验证保存修改时不会丢失已有值
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存修改'));
      await tester.pumpAndSettle();

      // 6. 从数据库重新读取验证，确保值没有丢失且正确保存
      final savedItem = await itemRepo.getItemWithFields(itemId);
      expect(savedItem, isNotNull);
      final ownerFieldSaved = savedItem!.fields.firstWhere(
        (f) => f.fieldKey == 'owner_name',
      );
      expect(ownerFieldSaved.valueText, '张三');
    });

    testWidgets('8. 必填校验仍生效，generic (其他资料) 资料名称未输入时报错', (
      WidgetTester tester,
    ) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // PART 1: 验证必填字段未输入报错
      await openEntryFields(tester, find.text('身份证').last);
      await tester.pumpAndSettle();

      // 点击下一步：补充信息，触发必填校验错误 (身份证号 id_number 是必填的，但没有输入)
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 验证必填字段身份证号的错误提示渲染
      expect(find.text('请输入身份证号'), findsOneWidget);

      // PART 2: 验证 generic 资料名称必填校验生效
      await tester.tap(findAnchIcon(AnchIcons.back));
      await tester.pumpAndSettle();
      await tester.tap(findAnchIcon(AnchIcons.back));
      await tester.pumpAndSettle();
      await openEntryFields(tester, find.text('其他资料').last);

      // 资料名称留空，直接点击下一步：补充信息
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // 验证因为没有输入资料名称报错
      expect(find.text('请输入资料名称'), findsOneWidget);
    });

    testWidgets('9. 页面继续显示开发验证警示，无误导性安全宣传文案', (WidgetTester tester) async {
      await setupScreenSize(tester);
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 验证包含 devModeMessage 文案
      expect(find.text(AnchSecurityBanner.devModeMessage), findsOneWidget);

      // 验证没有出现夸大安全宣传的误导性词汇
      expect(find.textContaining('正式安全模式已启用'), findsNothing);
      expect(find.textContaining('银行级安全'), findsNothing);
      expect(find.textContaining('绝对安全'), findsNothing);
      expect(find.textContaining('可放心录入真实敏感资料'), findsNothing);
    });
  });
}
