import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/features/search/search_page.dart';
import 'package:anch/widgets/item_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  for (final width in [320.0, 600.0, 1000.0]) {
    testWidgets('筛选在 $width 宽度与亮暗大字号下可触达，计数随条件更新且注销卡不算到期', (tester) async {
      final context = createTestRepositoryContext();
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await context.itemRepository.saveItemsInBatch([
        SaveItemInput(
          id: 'pinned',
          memberId: systemFamilyMemberId,
          typeKey: 'generic',
          title: 'TEST pinned',
          isPinned: true,
          fields: [],
        ),
        SaveItemInput(
          id: 'closed',
          memberId: systemMeMemberId,
          typeKey: 'credit_card',
          title: 'TEST closed',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'is_closed',
              valueType: FieldValueType.boolean,
              valueText: 'true',
            ),
            SaveItemFieldInput(
              fieldKey: 'valid_until',
              valueType: FieldValueType.date,
              valueText: '2020-01-01',
            ),
          ],
        ),
      ]);
      for (final dark in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          RuntimeScope(
            runtime: context.runtime,
            child: context.di.copyWith(
              child: MaterialApp(
                theme: dark ? AnchTheme.dark : AnchTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(dark ? 2 : 1)),
                  child: child!,
                ),
                home: const SearchPage(),
              ),
            ),
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 350);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('输入关键词，查找已整理的资料'));
        await tester.pumpAndSettle();
        expect(find.text('输入关键词，查找已整理的资料').hitTestable(), findsOneWidget);
        tester.view.resetViewInsets();
        await tester.binding.setSurfaceSize(Size(width, 400));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('输入关键词，查找已整理的资料'));
        await tester.pumpAndSettle();
        expect(find.text('输入关键词，查找已整理的资料').hitTestable(), findsOneWidget);
        await tester.binding.setSurfaceSize(Size(width, 700));
        await tester.enterText(find.byType(TextField), 'TEST');
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(find.text('找到 2 条资料'), findsOneWidget);
        expect(find.byType(FilterChip), findsNothing);
        tester.view.viewInsets = const FakeViewPadding(bottom: 350);
        await tester.pumpAndSettle();
        final result = find.byType(ItemSummaryCard).first;
        expect(result, findsOneWidget);
        final viewport = tester.getRect(find.byType(ListView));
        expect(tester.getRect(result).top, lessThan(viewport.bottom));
        final toggle = find.byKey(const Key('search_filter_toggle'));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
        expect(find.widgetWithText(FilterChip, '已到期'), findsNothing);
        for (final label in ['已置顶', '我', '信用卡']) {
          final chip = find.widgetWithText(FilterChip, label);
          await tester.ensureVisible(chip);
          expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(chip).width, greaterThanOrEqualTo(48));
        }
        await tester.ensureVisible(find.widgetWithText(FilterChip, '我'));
        await tester.tap(find.widgetWithText(FilterChip, '我'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('search_result_count')),
        );
        expect(find.text('找到 1 条资料'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byType(FilterChip), findsNothing);
        expect(find.text('筛选 · 1'), findsOneWidget);
        await tester.ensureVisible(
          find.text('TEST closed', findRichText: true),
        );
        expect(find.text('已注销'), findsOneWidget);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 350);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.enterText(find.byType(TextField), 'closed');
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(find.text('找到 1 条资料'), findsOneWidget);
        expect(find.byKey(const Key('search_filter_toggle')), findsNothing);
        expect(find.text('筛选 · 1'), findsNothing);
        expect(find.byType(FilterChip), findsNothing);
        await tester.enterText(find.byType(TextField), 'TEST');
        await tester.pumpAndSettle(const Duration(milliseconds: 350));
        expect(find.text('找到 2 条资料'), findsOneWidget);
        expect(find.text('筛选'), findsOneWidget);
      }
    });
  }

  testWidgets('超过 100 条的搜索结果仍可筛选最早录入的资料', (tester) async {
    final context = createTestRepositoryContext();
    await context.itemRepository.saveItemsInBatch([
      for (var index = 0; index < 120; index++)
        SaveItemInput(
          id: 'search-$index',
          memberId: systemFamilyMemberId,
          typeKey: 'generic',
          title: 'TEST record $index',
          isPinned: index == 119,
          fields: [],
        ),
    ]);
    await tester.pumpWidget(
      RuntimeScope(
        runtime: context.runtime,
        child: context.di.copyWith(
          child: const MaterialApp(home: SearchPage()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'TEST');
    await tester.pumpAndSettle(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const Key('search_filter_toggle')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '已置顶'));
    await tester.pumpAndSettle();
    expect(find.text('TEST record 119', findRichText: true), findsOneWidget);
    expect(find.text('暂无资料'), findsNothing);
  });

  for (final width in [320.0, 600.0, 900.0]) {
    testWidgets('敏感查询在 $width 宽度显示替代查找方式，后台清空输入', (tester) async {
      final context = createTestRepositoryContext();
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        RuntimeScope(
          runtime: context.runtime,
          child: context.di.copyWith(
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(1.3)),
                child: child!,
              ),
              home: const SearchPage(),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '110101199003072345');
      await tester.pumpAndSettle(const Duration(milliseconds: 350));
      expect(find.text('不支持完整敏感号码搜索'), findsOneWidget);
      expect(find.text('去添加资料'), findsNothing);
      expect(tester.takeException(), isNull);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .isEmpty,
        isFalse,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .isEmpty,
        isTrue,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('输入关键词，查找已整理的资料'), findsOneWidget);
    });
  }
}
