import 'dart:async';

import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart' show systemFamilyMemberId;
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/repository/models/member_model.dart';
import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/features/all_items/all_items_page.dart';
import 'package:anch/features/all_items/archived_items_page.dart';
import 'package:anch/features/mine/recently_deleted_page.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/member/member_page.dart';
import 'package:anch/features/type/type_page.dart';
import 'package:anch/features/mine/data_management_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

class ControlledListRepository extends ItemRepository {
  ControlledListRepository(super.db);

  final requests = <Completer<List<ItemModel>>>[];

  @override
  Future<List<ItemModel>> getActiveItems({String? memberId, String? typeKey}) {
    final request = Completer<List<ItemModel>>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<List<ItemModel>> getArchivedItems({String? keyword}) =>
      getActiveItems();

  @override
  Future<List<ItemModel>> getDeletedItems() => getActiveItems();
}

class ControlledStatisticsRepository extends ItemRepository {
  ControlledStatisticsRepository(super.db);
  final counts = <Completer<int>>[];
  final categories = <Completer<Map<String, int>>>[];

  @override
  Future<int> getActiveItemCount() {
    final request = Completer<int>();
    counts.add(request);
    return request.future;
  }

  @override
  Future<Map<String, int>> getActiveTypeCounts() {
    final request = Completer<Map<String, int>>();
    categories.add(request);
    return request.future;
  }

  @override
  Future<Map<String, int>> getActiveMemberCounts() => getActiveTypeCounts();

  @override
  Future<List<ItemModel>> getActiveItems({String? memberId, String? typeKey}) =>
      throw StateError('Statistics must not load item models');
}

ItemModel summary(String title) => ItemModel(
  id: title,
  memberId: systemFamilyMemberId,
  categoryKey: 'certificate',
  typeKey: 'id_card',
  templateVersion: 1,
  title: title,
  isFavorite: false,
  isPinned: false,
  sortOrder: 0,
  status: 'active',
  createdAt: 0,
  updatedAt: 0,
);

void main() {
  final pages = <String, Widget Function(MemberModel)>{
    '全部资料': (_) => const AllItemsPage(),
    '归档资料': (_) => const ArchivedItemsPage(),
    '最近删除': (_) => const RecentlyDeletedPage(),
    '类型资料': (_) =>
        TypeItemsPage(type: TemplateRegistry.getTemplate('id_card')!),
    '成员资料': (member) => MemberItemsPage(member: member),
    '首页': (_) => const HomePage(),
  };

  for (final entry in pages.entries) {
    late TestRepositoryContext context;
    late ControlledListRepository repository;

    Future<void> showPage(WidgetTester tester) async {
      context = createTestRepositoryContext();
      repository = ControlledListRepository(context.db);
      addTearDown(() {
        for (final request in repository.requests) {
          if (!request.isCompleted) request.complete(const []);
        }
      });
      final member = (await context.memberRepository.getMemberById(
        systemFamilyMemberId,
      ))!;
      await tester.pumpWidget(
        RuntimeScope(
          runtime: context.runtime,
          child: DependencyProvider.forTesting(
            runtime: context.runtime,
            db: context.db,
            memberRepo: context.memberRepository,
            itemRepo: repository,
            itemUseCaseService: context.itemUseCaseService,
            child: MaterialApp(home: entry.value(member)),
          ),
        ),
      );
      await tester.pump();
      expect(repository.requests, hasLength(1));
    }

    void refresh() => context.itemUseCaseService.registry.emit(
      const ItemEvent(type: ItemEventType.saved, itemId: 'mock'),
    );

    testWidgets('${entry.key}：首次失败可重试，刷新失败保留内容', (tester) async {
      await showPage(tester);
      repository.requests[0].completeError(StateError('mock read failure'));
      await tester.pumpAndSettle();
      expect(find.text('加载资料失败'), findsOneWidget);
      expect(find.text('暂无资料'), findsNothing);
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      repository.requests[1].complete([summary('TEST saved')]);
      await tester.pumpAndSettle();
      expect(find.text('TEST saved'), findsOneWidget);
      expect(find.text('加载资料失败'), findsNothing);

      refresh();
      await tester.pump();
      repository.requests[2].completeError(StateError('mock refresh failure'));
      await tester.pumpAndSettle();
      expect(find.text('TEST saved'), findsOneWidget);
      expect(find.text('刷新失败，仍显示上次内容'), findsOneWidget);
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      repository.requests[3].complete([summary('TEST updated')]);
      await tester.pumpAndSettle();
      expect(find.text('TEST updated'), findsOneWidget);
      expect(find.text('刷新失败，仍显示上次内容'), findsNothing);
    });

    testWidgets('${entry.key}：过期成功与失败均不能覆盖新请求，退出后不更新', (tester) async {
      await showPage(tester);
      refresh();
      await tester.pump();
      repository.requests[1].complete([summary('TEST newest')]);
      await tester.pumpAndSettle();
      repository.requests[0].completeError(StateError('mock stale failure'));
      await tester.pumpAndSettle();
      expect(find.text('TEST newest'), findsOneWidget);
      expect(find.text('重新加载'), findsNothing);

      refresh();
      await tester.pump();
      refresh();
      await tester.pump();
      repository.requests[3].completeError(StateError('mock newest failure'));
      await tester.pumpAndSettle();
      repository.requests[2].complete([summary('TEST stale')]);
      await tester.pumpAndSettle();
      expect(find.text('TEST newest'), findsOneWidget);
      expect(find.text('TEST stale'), findsNothing);
      expect(find.text('刷新失败，仍显示上次内容'), findsOneWidget);

      refresh();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      repository.requests[4].complete([summary('TEST after disposal')]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('分类统计过期错误不覆盖新数量，刷新失败保留入口且可重试', (tester) async {
    final context = createTestRepositoryContext();
    final repository = ControlledStatisticsRepository(context.db);
    await tester.pumpWidget(
      RuntimeScope(
        runtime: context.runtime,
        child: DependencyProvider.forTesting(
          runtime: context.runtime,
          db: context.db,
          memberRepo: context.memberRepository,
          itemRepo: repository,
          itemUseCaseService: context.itemUseCaseService,
          child: const MaterialApp(home: TypePage()),
        ),
      ),
    );
    context.itemUseCaseService.registry.emit(
      const ItemEvent(type: ItemEventType.saved, itemId: 'mock'),
    );
    repository.categories[1].complete({'id_card': 2});
    await tester.pumpAndSettle();
    repository.categories[0].completeError(
      StateError('mock old count failure'),
    );
    await tester.pumpAndSettle();
    expect(find.text('身份证'), findsOneWidget);
    expect(find.text('刷新失败，仍显示上次内容'), findsNothing);
    context.itemUseCaseService.registry.emit(
      const ItemEvent(type: ItemEventType.saved, itemId: 'mock'),
    );
    repository.categories[2].completeError(
      StateError('mock latest count failure'),
    );
    await tester.pumpAndSettle();
    expect(find.text('身份证'), findsOneWidget);
    expect(find.text('刷新失败，仍显示上次内容'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    repository.categories[3].complete({});
    await tester.pumpAndSettle();
    expect(find.text('暂无分类资料'), findsOneWidget);
    expect(find.text('刷新失败，仍显示上次内容'), findsNothing);
  });

  testWidgets('数据管理只统计数量，读取失败可重试且刷新失败保留旧数量', (tester) async {
    final context = createTestRepositoryContext();
    final repository = ControlledStatisticsRepository(context.db);
    await tester.pumpWidget(
      RuntimeScope(
        runtime: context.runtime,
        child: DependencyProvider.forTesting(
          runtime: context.runtime,
          db: context.db,
          memberRepo: context.memberRepository,
          itemRepo: repository,
          itemUseCaseService: context.itemUseCaseService,
          child: const MaterialApp(home: DataManagementPage()),
        ),
      ),
    );
    repository.counts[0].completeError(StateError('mock statistics failure'));
    await tester.pumpAndSettle();
    expect(find.text('加载资料失败'), findsOneWidget);
    await tester.tap(find.text('重新加载'));
    repository.counts[1].complete(8);
    await tester.pumpAndSettle();
    expect(find.text('8 条'), findsOneWidget);
    await tester.ensureVisible(find.text('最近删除'));
    await tester.tap(find.text('最近删除'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('暂无最近删除的资料'))).pop();
    await tester.pumpAndSettle();
    repository.counts[2].completeError(
      StateError('mock statistics refresh failure'),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('刷新失败，仍显示上次内容'), -100);
    expect(find.text('刷新失败，仍显示上次内容'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('8 条'), 100);
    expect(find.text('8 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('成员首页统计失败显示重试，恢复后数量正确', (tester) async {
    final context = createTestRepositoryContext();
    final repository = ControlledStatisticsRepository(context.db);
    await tester.pumpWidget(
      RuntimeScope(
        runtime: context.runtime,
        child: DependencyProvider.forTesting(
          runtime: context.runtime,
          db: context.db,
          memberRepo: context.memberRepository,
          itemRepo: repository,
          itemUseCaseService: context.itemUseCaseService,
          child: const MaterialApp(home: MemberPage()),
        ),
      ),
    );
    repository.categories[0].completeError(
      StateError('mock member counts failure'),
    );
    await tester.pumpAndSettle();
    expect(find.text('加载资料失败'), findsOneWidget);
    expect(find.text('暂无资料'), findsNothing);
    await tester.tap(find.text('重新加载'));
    repository.categories[1].complete({systemFamilyMemberId: 2});
    await tester.pumpAndSettle();
    expect(find.text('家庭'), findsOneWidget);
    expect(find.text('2 项资料'), findsOneWidget);
    expect(find.text('加载资料失败'), findsNothing);
  });
}
