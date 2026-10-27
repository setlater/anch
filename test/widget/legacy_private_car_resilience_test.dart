import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/search/search_page.dart';
import 'package:anch/features/type/type_page.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
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
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 7, 2)),
      child: Container(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
  });

  tearDown(() async {
    await db.close();
  });

  group('历史遗留车辆数据 private_car 防崩兜底测试', () {
    testWidgets('验证历史 private_car 数据在详情/首页/搜索/大类中加载不崩溃且正常兜底展示', (
      WidgetTester tester,
    ) async {
      // 1. 设置屏幕尺寸并构造历史车辆资料数据
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final itemId = 'legacy_car_profile_id';
      final now = DateTime.now().millisecondsSinceEpoch;

      // 手动插入 items 主表记录
      await db
          .into(db.items)
          .insert(
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: const drift.Value(
                '00000000-0000-4000-8000-000000000001',
              ), // 系统默认家庭成员
              categoryKey: const drift.Value('vehicle'), // 历史车类 Key
              typeKey: const drift.Value('private_car'), // 历史私家车 Key
              templateVersion: const drift.Value(1),
              title: const drift.Value('我的家庭私家车'),
              createdAt: now,
              updatedAt: now,
            ),
          );

      // 手动通过 Repository 保存字段数据
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: '00000000-0000-4000-8000-000000000001',
          categoryKey: 'vehicle',
          typeKey: 'private_car',
          templateVersion: 1,
          title: '我的家庭私家车',
          primaryText: '京A88888',
          searchText: '我的家庭私家车 京A88888 车辆资料 大众',
          summaryText: '车牌号: 京A88888 | 所有人: 张三',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'plate_number',
              valueType: FieldValueType.text,
              valueText: '京A88888',
            ),
            SaveItemFieldInput(
              fieldKey: 'owner_name',
              valueType: FieldValueType.sensitiveText,
              valueText: '张三',
            ),
            SaveItemFieldInput(
              fieldKey: 'maintenance_note',
              valueType: FieldValueType.text,
              valueText: '保养顺畅，无异常',
            ),
          ],
        ),
      );

      // ──────────────────────────────────────────────────────────────────────
      // 验证 1: 详情页不崩溃且正常兜底展示
      // ──────────────────────────────────────────────────────────────────────
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: ItemDetailPage(itemId: itemId)),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );

      // 页面加载等待
      while (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      expect(find.text('vehicle'), findsOneWidget);
      expect(find.text('我的家庭私家车'), findsOneWidget);
      expect(find.text('京A88888'), findsOneWidget);
      expect(find.text('保养顺畅，无异常'), findsOneWidget);

      // ──────────────────────────────────────────────────────────────────────
      // 验证 2: 首页不崩溃且正常列表展示
      // ──────────────────────────────────────────────────────────────────────
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: HomePage()),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('全部资料'), findsOneWidget);
      expect(find.text('我的家庭私家车'), findsOneWidget);

      // ──────────────────────────────────────────────────────────────────────
      // 验证 3: 搜索页检索不崩溃
      // ──────────────────────────────────────────────────────────────────────
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: SearchPage()),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      final searchTextField = find.byType(TextField);
      expect(searchTextField, findsOneWidget);
      await tester.enterText(searchTextField, '京A');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // 搜索成功且显示
      expect(find.text('我的家庭私家车'), findsOneWidget);

      // ──────────────────────────────────────────────────────────────────────
      // 验证 4: 类型大类页不崩溃且正常获取统计
      // ──────────────────────────────────────────────────────────────────────
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(home: TypePage(isActive: true)),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('历史资料'), findsOneWidget);
      await tester.tap(find.text('历史资料'));
      await tester.pumpAndSettle();
      expect(find.text('我的家庭私家车'), findsOneWidget);
    });
  });
}
