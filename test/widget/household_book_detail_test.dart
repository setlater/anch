import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/repository/models/item_child_entry_model.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:drift/drift.dart' as drift;
import 'package:anch/core/template/field_value_type.dart';
import '../support/test_bootstrap.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemRepository itemRepo;

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

  group('户口本多成员详情页展示测试 (C2-3)', () {
    testWidgets('1. 0 成员时不展示“户内成员”分组', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final itemId = 'existing_hb_id_no_member';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: const drift.Value(
                '00000000-0000-4000-8000-000000000001',
              ),
              categoryKey: const drift.Value('certificate'),
              typeKey: const drift.Value('household_book'),
              templateVersion: const drift.Value(1),
              title: const drift.Value('已存无成员户口本'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: '00000000-0000-4000-8000-000000000001',
          categoryKey: 'certificate',
          typeKey: 'household_book',
          templateVersion: 1,
          title: '已存无成员户口本',
          primaryText: '',
          searchText: '已存无成员户口本',
          summaryText: '暂无成员信息',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'household_number',
              valueType: FieldValueType.text,
              valueText: '55556666',
            ),
          ],
          childEntries: [],
        ),
      );

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            key: UniqueKey(),
            home: ItemDetailPage(itemId: itemId),
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );

      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // 验证没有渲染任何多成员卡片，标题也不出现成员名字或“第 1 位成员”
      expect(find.text('第 1 位成员'), findsNothing);
      expect(find.text('户主页信息'), findsNothing);
    });

    testWidgets('2. 2个成员时展示2张成员卡片，姓名/关系展示正常，标题无身份证号', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final itemId = 'existing_hb_id_2_members';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: const drift.Value(
                '00000000-0000-4000-8000-000000000001',
              ),
              categoryKey: const drift.Value('certificate'),
              typeKey: const drift.Value('household_book'),
              templateVersion: const drift.Value(1),
              title: const drift.Value('2成员户口本'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: '00000000-0000-4000-8000-000000000001',
          categoryKey: 'certificate',
          typeKey: 'household_book',
          templateVersion: 1,
          title: '2成员户口本',
          primaryText: '',
          searchText: '2成员户口本',
          summaryText: '已记录 2 位成员',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'household_number',
              valueType: FieldValueType.text,
              valueText: '55556666',
            ),
          ],
          childEntries: [
            SaveItemChildEntryInput(
              id: 'm1_id',
              childType: 'household_member',
              sortOrder: 0,
              fields: [
                SaveItemChildFieldInput(
                  fieldKey: 'member_name',
                  label: '姓名',
                  valueText: '张三',
                  valueType: 'text',
                  sensitiveLevel: 'medium',
                  searchable: true,
                ),
                SaveItemChildFieldInput(
                  fieldKey: 'relation_to_head',
                  label: '与户主关系',
                  valueText: '本人',
                  valueType: 'text',
                  sensitiveLevel: 'none',
                ),
                SaveItemChildFieldInput(
                  fieldKey: 'member_id_number',
                  label: '身份证号',
                  valueText: '11010119900307234X',
                  valueType: 'sensitiveText',
                  sensitiveLevel: 'high',
                  copyable: true,
                ),
              ],
            ),
            SaveItemChildEntryInput(
              id: 'm2_id',
              childType: 'household_member',
              sortOrder: 1,
              fields: [
                SaveItemChildFieldInput(
                  fieldKey: 'member_name',
                  label: '姓名',
                  valueText: '',
                  valueType: 'text',
                  sensitiveLevel: 'medium',
                  searchable: true,
                ),
                SaveItemChildFieldInput(
                  fieldKey: 'relation_to_head',
                  label: '与户主关系',
                  valueText: '配偶',
                  valueType: 'text',
                  sensitiveLevel: 'none',
                ),
              ],
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            key: UniqueKey(),
            home: ItemDetailPage(itemId: itemId),
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );

      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // 验证卡片标题
      expect(find.text('张三'), findsOneWidget); // 有名字显示名字
      expect(find.text('第 2 位成员'), findsOneWidget); // 无名字显示“第 2 位成员”
      expect(find.text('配偶'), findsOneWidget);

      final firstMemberCard = find.byKey(const Key('household_member_card_0'));
      expect(firstMemberCard, findsOneWidget);
      expect(
        find.descendant(of: firstMemberCard, matching: find.byType(Divider)),
        findsNWidgets(2),
      );

      // 验证身份证默认脱敏 (通过特定 Text 的 Key 查询)
      final idNumTextFinder = find.byKey(
        const Key('field_normal_val_member_0_member_id_number'),
      );
      expect(idNumTextFinder, findsOneWidget);
      expect(tester.widget<Text>(idNumTextFinder).data, equals('******'));
      expect(find.text('11010119900307234X'), findsNothing);

      // 校验旧扁平成员字段不展示（避免重复）
      expect(find.text('页面成员'), findsNothing);

      // 点击眼睛显示明文
      final trailingActions = find.byKey(
        const Key('field_trailing_actions_member_0_member_id_number'),
      );
      final eyeIcon = find.descendant(
        of: trailingActions,
        matching: findAnchIcon(AnchIcons.visibility),
      );
      expect(eyeIcon, findsOneWidget);
      await tester.tap(eyeIcon);
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(idNumTextFinder).data,
        equals('11010119900307234X'),
      );

      // 下方成员字段行直接复制。
      final copyIcon = find.descendant(
        of: trailingActions,
        matching: findAnchIcon(AnchIcons.copy),
      );
      expect(copyIcon, findsOneWidget);
      await tester.tap(copyIcon);
      await tester.pumpAndSettle();

      expect(find.text('确认复制敏感字段？'), findsNothing);

      // 触发生命周期变化 inactive/paused -> 重新遮蔽
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(tester.widget<Text>(idNumTextFinder).data, equals('******'));
    });

    testWidgets('3. 非户口本模板不受影响', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final itemId = 'existing_id_card_id';
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: const drift.Value(
                '00000000-0000-4000-8000-000000000001',
              ),
              categoryKey: const drift.Value('certificate'),
              typeKey: const drift.Value('id_card'),
              templateVersion: const drift.Value(1),
              title: const drift.Value('身份证'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: '00000000-0000-4000-8000-000000000001',
          categoryKey: 'certificate',
          typeKey: 'id_card',
          templateVersion: 1,
          title: '身份证',
          primaryText: '',
          searchText: '身份证',
          summaryText: '身份证',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'name',
              valueType: FieldValueType.text,
              valueText: '张三',
            ),
            SaveItemFieldInput(
              fieldKey: 'id_number',
              valueType: FieldValueType.idNumber,
              valueText: '110101199003072345',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            key: UniqueKey(),
            home: ItemDetailPage(itemId: itemId),
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );

      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('姓名'), findsOneWidget);
      expect(find.text('张三'), findsOneWidget);
      expect(find.text('户主页信息'), findsNothing);
      expect(find.text('第 1 位成员'), findsNothing);
    });
  });
}
