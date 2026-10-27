import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/item_search_service.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/widgets/card_contract/anch_card_model.dart';
import 'package:anch/core/theme/anch_icons.dart';

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
    di = DependencyProvider.create(runtime: runtime, child: Container());
    db = di.db;
    itemRepo = di.itemRepo;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget(Widget child) {
    return wrapTest(
      MaterialApp(home: Scaffold(body: child)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('第十二轮第七组：资料卡片状态展示与排序边界测试', () {
    testWidgets('1. 置顶 badge 渲染测试', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          AnchUnifiedDataCard(
            model: const AnchCardModel(
              title: 'TEST-置顶资料',
              description: '',
              icon: AnchIcons.idCard,
              tag: '置顶',
            ),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('置顶'), findsOneWidget);
      expect(find.text('常用'), findsNothing);
    });

    test('2. getActiveItems 排序边界逻辑测试', () async {
      // A: 普通资料, sortOrder=5, status=active
      final itemA = SaveItemInput(
        id: 'A',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-A',
        isFavorite: false,
        isPinned: false,
        sortOrder: 5,
        status: 'active',
        fields: [],
      );

      // B: 置顶资料, sortOrder=10, status=active
      final itemB = SaveItemInput(
        id: 'B',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-B',
        isFavorite: false,
        isPinned: true,
        pinnedAt: 100,
        sortOrder: 10,
        status: 'active',
        fields: [],
      );

      // C: 置顶资料, sortOrder=2, status=active
      final itemC = SaveItemInput(
        id: 'C',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-C',
        isFavorite: false,
        isPinned: true,
        pinnedAt: 200,
        sortOrder: 2,
        status: 'active',
        fields: [],
      );

      // D: 置顶资料, sortOrder=2, status=active
      final itemD = SaveItemInput(
        id: 'D',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-D',
        isFavorite: false,
        isPinned: true,
        pinnedAt: 300,
        sortOrder: 2,
        status: 'active',
        fields: [],
      );

      // E: 归档资料, 不应被 getActiveItems() 查出
      final itemE = SaveItemInput(
        id: 'E',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-E',
        isFavorite: false,
        isPinned: true,
        pinnedAt: 400,
        sortOrder: 1,
        status: 'archived',
        fields: [],
      );

      // pinnedAt 决定置顶资料的相对顺序，sortOrder 不参与排序。
      await itemRepo.saveItemWithFields(itemA);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemB);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemC);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemD);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemE);

      final activeItems = await itemRepo.getActiveItems();

      // 验证 archived 状态的 E 不存在
      expect(activeItems.any((i) => i.id == 'E'), isFalse);

      // 排序满足 isPinned DESC -> pinnedAt DESC -> updatedAt DESC
      // 置顶有 B, C, D 且优先于 A
      // D、C、B 的置顶时间依次更晚。
      // 正确顺序: D -> C -> B -> A
      expect(activeItems.length, equals(4));
      expect(activeItems[0].id, equals('D'));
      expect(activeItems[1].id, equals('C'));
      expect(activeItems[2].id, equals('B'));
      expect(activeItems[3].id, equals('A'));
    });

    test('3. searchItems 置顶优先与安全防泄露测试', () async {
      final itemC = SaveItemInput(
        id: 'C',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-keyword',
        isFavorite: false,
        isPinned: true,
        sortOrder: 1,
        status: 'active',
        fields: [],
      );

      final itemA = SaveItemInput(
        id: 'A',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-keyword',
        isFavorite: false,
        isPinned: false,
        sortOrder: 1,
        status: 'active',
        fields: [],
      );

      await itemRepo.saveItemWithFields(itemA);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemC);

      final searchService = ItemSearchService(
        RuntimeProvider.create(
          const AnchSecurityRuntimeConfig(
            mode: AnchSecurityMode.dev,
            useEncryptedDatabase: false,
            enableSecureWindow: false,
            enablePrivacyShieldOverlay: false,
            enableAppLockGate: false,
            isFormalBlocked: false,
          ),
        ),
        itemRepo: itemRepo,
      );
      final searchResults = await searchService.searchItems('TEST-keyword');
      expect(searchResults.length, equals(2));
      // 置顶的 C 优先
      expect(searchResults.first.id, equals('C'));

      // 列表和搜索中均不得展示 note 字段与高敏 raw value
      for (final item in searchResults) {
        expect(item.note, isNull);
      }
    });

    test('4. 首页 getRecentItemsForSession 语义与 Badges 展示测试', () async {
      final itemA = SaveItemInput(
        id: 'A',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-A',
        isFavorite: false,
        isPinned: false,
        sortOrder: 1,
        status: 'active',
        fields: [],
      );

      final itemB = SaveItemInput(
        id: 'B',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-B',
        isFavorite: false,
        isPinned: true,
        sortOrder: 1,
        status: 'active',
        fields: [],
      );

      await itemRepo.saveItemWithFields(itemA);
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemB);

      final recentItems = await itemRepo.getRecentItemsForSession();
      expect(recentItems.first.id, equals('B'));

      // 修改 A 使其成为最近被更新
      final itemAUpdated = SaveItemInput(
        id: 'A',
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: 'TEST-A-Updated',
        isFavorite: false,
        isPinned: false,
        sortOrder: 1,
        status: 'active',
        fields: [],
      );
      await Future.delayed(const Duration(milliseconds: 2));
      await itemRepo.saveItemWithFields(itemAUpdated);

      final recentItemsAfterUpdate = await itemRepo.getRecentItemsForSession();
      // 首页必须以“最近时间”为主，因此 A 应当排在 B 前面
      expect(recentItemsAfterUpdate.first.id, equals('A'));
    });

    test('5. UI 文案与敏感技术词静态审计安全测试', () {
      final targetFiles = [
        'lib/core/widgets/anch_record_card.dart',
        'lib/features/home/home_page.dart',
        'lib/features/type/type_page.dart',
        'lib/features/member/member_page.dart',
        'lib/features/search/search_page.dart',
      ];

      final illegalPhrases = ['正式安全模式已启用', '银行级安全', '绝对安全', '可放心录入真实敏感资料'];

      final sensitiveTechWords = [
        'databaseKey',
        'backupKey',
        'salt',
        'verifier',
        'token',
        '/data/data/',
        'content://',
        'file://',
      ];

      for (final path in targetFiles) {
        final file = File(path);
        if (!file.existsSync()) continue;

        final content = file.readAsStringSync();

        for (final phrase in illegalPhrases) {
          expect(
            content.contains(phrase),
            isFalse,
            reason: '文件 $path 中违规包含误导文案: "$phrase"',
          );
        }

        for (final techWord in sensitiveTechWords) {
          expect(
            content.contains(techWord),
            isFalse,
            reason: '文件 $path 中包含敏感技术词/路径前缀: "$techWord"',
          );
        }
      }
    });
  });
}
