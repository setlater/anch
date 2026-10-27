import 'package:anch/core/widgets/anch_step_indicator.dart';
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
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
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
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget({Widget? home}) {
    return wrapTest(
      home != null ? MaterialApp(home: home) : const AnchApp(),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('Item 资料生命周期测试 — Repository/UseCase 逻辑层', () {
    test('1. 新增资料后修改更新，验证获取修改后属性且不新增重复记录，摘要标题重新计算', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      // 保存第一版资料
      final result1 = await service.saveDraft(draft);
      expect(result1.success, isTrue);
      final itemId = result1.itemId!;

      // 验证初次写入
      final item1 = await itemRepo.getItemWithFields(itemId);
      expect(item1, isNotNull);
      expect(item1!.title, equals('张三的身份证'));

      final recentItems1 = await itemRepo.getRecentItemsForSession();
      expect(recentItems1.length, equals(1));

      // 编辑更新资料
      final updateDraft = ItemDraftInput(
        id: itemId, // 传入相同的 itemId
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '李四'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
        note: '这是修改后的备注内容',
      );

      final result2 = await service.saveDraft(updateDraft);
      expect(result2.success, isTrue);
      expect(result2.itemId, equals(itemId)); // ID 必须一致

      // 验证数据库状态
      final item2 = await itemRepo.getItemWithFields(itemId);
      expect(item2, isNotNull);
      expect(item2!.title, equals('李四的身份证')); // 标题根据新姓名重新拼装计算
      expect(item2.note, equals('这是修改后的备注内容'));

      // 确保并没有产生冗余的重复记录
      final recentItems2 = await itemRepo.getRecentItemsForSession();
      expect(recentItems2.length, equals(1));
    });

    test('2. 移入最近删除后，活跃列表隐藏且关联数据保留', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      // 删除前确保能在数据库中读出关联字段
      final fieldsBefore = await (db.select(
        db.itemFields,
      )..where((tbl) => tbl.itemId.equals(itemId))).get();
      expect(fieldsBefore.isNotEmpty, isTrue);

      // 调用用例服务删除方法
      await service.deleteItem(itemId);

      // 资料主表保留软删除状态，供最近删除恢复。
      final itemAfter = await itemRepo.getItemWithFields(itemId);
      expect(itemAfter?.status, 'deleted');
      expect(itemAfter?.deletedAt, isNotNull);
      expect(await itemRepo.getActiveItems(), isEmpty);

      // 关联字段仍保留，恢复时不需要重建敏感资料。
      final fieldsAfter = await (db.select(
        db.itemFields,
      )..where((tbl) => tbl.itemId.equals(itemId))).get();
      expect(fieldsAfter, hasLength(fieldsBefore.length));
    });
  });

  group('Item 资料生命周期测试 — Widget 交互界面层', () {
    testWidgets(
      '3. 完整交互体验：新建 -> 进入详情 -> 点击编辑 -> 回填并保存修改 -> 二次确认删除 -> 退出返回并从首页清除',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Step A: 新增资料
        await tester.tap(find.byKey(const Key('home_add_item')));
        await tester.pumpAndSettle();

        // 步骤一：成员归属

        // 步骤二：选择类型
        await openEntryFields(tester, find.text('身份证'));
        await tester.pumpAndSettle();

        // 步骤三：输入核心字段
        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.at(0), '张三');
        await tester.enterText(textFields.at(1), '110101199003072345');
        await tester.pumpAndSettle();

        await tester.tap(find.text('下一步'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存资料'));
        await tester.pumpAndSettle();

        expect(find.text('身份证'), findsOneWidget);
        expect(find.text('张三的身份证'), findsOneWidget);

        // 验证没有 SnackBar 弹出
        expect(find.byType(SnackBar), findsNothing);
        await tester.pumpAndSettle();

        // Step B: 点击编辑按钮
        final editButton = findAnchIcon(AnchIcons.more);
        expect(editButton, findsOneWidget);
        await tester.tap(editButton);
        await tester.pumpAndSettle();

        expect(find.text('编辑'), findsOneWidget);
        await tester.tap(find.text('编辑'));
        await tester.pumpAndSettle();

        // 验证编辑模式
        expect(find.text('编辑身份证'), findsOneWidget);
        expect(
          tester
              .widget<AnchStepIndicator>(
                find.byKey(const Key('step_indicator')),
              )
              .currentStep,
          2,
        );

        // 校验数据回填
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('item_field_control_name')),
              )
              .controller
              ?.text,
          '张三',
        );
        expect(
          tester
              .widget<TextFormField>(
                find.byKey(const Key('item_field_control_id_number')),
              )
              .controller
              ?.text,
          '110101199003072345',
        );

        // 修改姓名
        final editNameField = find.byKey(const Key('item_field_control_name'));
        await tester.enterText(editNameField, '王五');
        await tester.pumpAndSettle();

        // 点击保存修改
        await tester.tap(find.text('下一步'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('保存修改'));
        await tester.pumpAndSettle();

        // 验证回到详情页，且标题修改生效，默认依然保持掩码脱敏
        expect(find.text('身份证'), findsOneWidget);
        expect(find.text('王五的身份证'), findsOneWidget);

        expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);

        // Step C: 点击删除逻辑与二次确认交互
        await tester.tap(findAnchIcon(AnchIcons.more));
        await tester.pumpAndSettle();
        expect(find.text('删除'), findsOneWidget);
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // 验证二次确认弹窗
        expect(find.text('移入最近删除？'), findsOneWidget);
        expect(find.textContaining('可在「数据与备份－最近删除」中恢复'), findsOneWidget);

        // 点击取消
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();

        // 详情页依然存在，没有退出
        expect(find.text('身份证'), findsOneWidget);

        // 重新触发删除
        await tester.tap(findAnchIcon(AnchIcons.more));
        await tester.pumpAndSettle();
        await tester.tap(find.text('删除'));
        await tester.pumpAndSettle();

        // 点击二次确认里的“移入最近删除”按钮
        await tester.tap(find.text('移入最近删除'));
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();

        // 验证删除后顺利返回首页且“最近保存”中已不复存在该条资料
        expect(find.text('身份证'), findsNothing);
        expect(find.text('王五的身份证'), findsNothing);
      },
    );
  });
}
