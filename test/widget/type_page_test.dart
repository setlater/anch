import 'package:anch/core/template/template_registry.dart';
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
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/type/type_page.dart';
import 'package:anch/core/widgets/anch_empty_state.dart';
import 'package:anch/core/theme/anch_spacing.dart';
import 'package:anch/core/widgets/anch_category_index_item.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:drift/drift.dart' show Value;

class ThrowingItemRepositoryForTest extends ItemRepository {
  ThrowingItemRepositoryForTest(super.db);

  @override
  Future<Map<String, int>> getActiveTypeCounts() async {
    throw Exception('Simulated DB failure');
  }
}

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
    ItemGlobalRegistry.instance.clear();
  });

  Widget buildTestApp(Widget page, {ItemRepository? customRepo}) {
    return wrapTest(
      MaterialApp(home: page),
      runtime,
      (child) => DependencyProvider.forTesting(
        runtime: runtime,
        db: db,
        memberRepo: di.memberRepo,
        itemRepo: customRepo ?? itemRepo,
        itemUseCaseService: service,
        child: child,
      ),
    );
  }

  Future<void> seedItem({
    required String typeKey,
    required String title,
    String status = 'active',
  }) async {
    final List<ItemFieldDraftInput> fields = [];
    if (typeKey == 'id_card') {
      fields.add(
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
      );
    } else if (typeKey == 'debit_card' || typeKey == 'credit_card') {
      fields.add(
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
      );
    } else if (typeKey == 'passport') {
      fields.add(
        ItemFieldDraftInput(
          fieldKey: 'passport_number',
          valueText: 'E12345678',
        ),
      );
    }

    final result = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: typeKey,
        title: title,
        fields: fields,
      ),
    );
    expect(result.persisted, isTrue);

    // If status is not active, let's update it in the database directly to test filtering
    if (status != 'active') {
      await (db.update(
        db.items,
      )..where((tbl) => tbl.id.equals(result.itemId!))).write(
        ItemsCompanion(
          status: Value(status),
          deletedAt: Value(status == 'deleted' ? 1000 : null),
          statusBeforeDeletion: Value(status == 'deleted' ? 'active' : null),
        ),
      );
    }
  }

  group('TypePage 聚合与页面策略测试', () {
    testWidgets('分类卡片在各档宽度保留横纵间距', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      for (final type in ['id_card', 'debit_card', 'passport', 'credit_card']) {
        await seedItem(typeKey: type, title: '虚构分类资料');
      }
      for (final width in <double>[320, 360, 600, 1000]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(buildTestApp(const TypePage()));
        await tester.pumpAndSettle();
        final cards = find.byType(AnchCategoryIndexItem);
        expect(cards, findsNWidgets(4));
        final first = tester.getRect(cards.at(0));
        final second = tester.getRect(cards.at(1));
        if (second.top == first.top) {
          expect(
            second.left - first.right,
            greaterThanOrEqualTo(AnchSpacing.md),
          );
        }
        final nextRow = [
          for (var index = 1; index < 4; index++)
            tester.getRect(cards.at(index)),
        ].firstWhere((rect) => rect.top > first.top);
        expect(
          nextRow.top - first.bottom,
          greaterThanOrEqualTo(AnchSpacing.md),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('1. 无资料时显示空状态', (tester) async {
      await tester.pumpWidget(buildTestApp(const TypePage()));
      await tester.pump(); // Start loading
      await tester.pumpAndSettle(); // Finish loading

      expect(find.byType(AnchEmptyState), findsOneWidget);
      expect(find.text('暂无分类资料'), findsOneWidget);
    });

    testWidgets('2. 有资料时只显示对应的分类卡片与正确的数量，其余不显示', (tester) async {
      // 写入 1 个身份证, 2 个储蓄卡
      await seedItem(typeKey: 'id_card', title: '测试身份证');
      await seedItem(typeKey: 'debit_card', title: '测试储蓄卡 1');
      await seedItem(typeKey: 'debit_card', title: '测试储蓄卡 2');

      await tester.pumpWidget(buildTestApp(const TypePage(isActive: true)));
      await tester.pump();
      await tester.pumpAndSettle();

      // 验证只显示身份证和储蓄卡卡片
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('1 条'), findsOneWidget);
      expect(find.text('储蓄卡'), findsOneWidget);
      expect(find.text('2 条'), findsOneWidget);

      // 其他卡片如“护照”不应该显示
      expect(find.text('护照'), findsNothing);

      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.mainAxisExtent, 88);
    });

    testWidgets('3. 查询失败时显示加载失败/重试状态，不显示暂无分类资料', (tester) async {
      final customRepo = ThrowingItemRepositoryForTest(db);

      await tester.pumpWidget(
        buildTestApp(const TypePage(isActive: true), customRepo: customRepo),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      // 应该显示重试按钮和错误信息，但不应该显示“暂无分类资料”空状态
      expect(find.text('加载分类失败，请稍后重试'), findsOneWidget);
      expect(find.text('重新加载'), findsOneWidget);
      expect(find.text('暂无分类资料'), findsNothing);
    });

    test('4. getActiveTypeCounts 只统计 active 并且过滤 null/empty typeKey', () async {
      // 1. active items with valid type keys
      await seedItem(typeKey: 'id_card', title: '活跃身份证');
      await seedItem(typeKey: 'debit_card', title: '活跃储蓄卡 1');
      await seedItem(typeKey: 'debit_card', title: '活跃储蓄卡 2');

      // 2. archived item
      await seedItem(typeKey: 'id_card', title: '已归档身份证', status: 'archived');

      // 3. deleted item
      await seedItem(typeKey: 'passport', title: '已删除护照', status: 'deleted');

      // 4. empty/null typeKey items
      final result1 = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'passport',
          title: '空类型资料',
          fields: [],
        ),
      );
      await (db.update(db.items)
            ..where((tbl) => tbl.id.equals(result1.itemId!)))
          .write(const ItemsCompanion(typeKey: Value('')));

      final result2 = await service.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'passport',
          title: 'Null类型资料',
          fields: [],
        ),
      );
      await (db.update(db.items)
            ..where((tbl) => tbl.id.equals(result2.itemId!)))
          .write(const ItemsCompanion(typeKey: Value(null)));

      final counts = await itemRepo.getActiveTypeCounts();

      // Verify counts
      expect(counts['id_card'], equals(1));
      expect(counts['debit_card'], equals(2));
      expect(counts.containsKey('passport'), isFalse);
      expect(counts.containsKey(''), isFalse);
    });

    test('5. 创建流程仍展示全部可创建资料类型', () {
      final intents = TemplateRegistry.getCreatableTypes();
      // 保证 builtinIntents 的数量不为零且能获取到全部可创建的类型
      expect(intents.length, greaterThan(10));
      expect(intents.any((i) => i.typeKey == 'id_card'), isTrue);
      expect(intents.any((i) => i.typeKey == 'debit_card'), isTrue);
      expect(intents.any((i) => i.typeKey == 'passport'), isTrue);
    });

    testWidgets('6. 进入具体类型后资料卡片只使用一层页面左右边距', (tester) async {
      await seedItem(typeKey: 'id_card', title: '虚构身份证');

      await tester.pumpWidget(buildTestApp(const TypePage(isActive: true)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('身份证'));
      await tester.pumpAndSettle();

      final card = find.byType(AnchUnifiedDataCard);
      expect(card, findsOneWidget);
      final list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.padding,
        const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      );
      final spacing = tester.widget<Padding>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.key.toString().contains('type_item_card_spacing_'),
        ),
      );
      expect(spacing.padding, const EdgeInsets.only(bottom: AnchSpacing.sm));
    });
  });
}
