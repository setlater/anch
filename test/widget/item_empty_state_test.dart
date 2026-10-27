import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_global_registry.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/search/search_page.dart';
import '../contracts/contract_extractor.dart';
import '../contracts/contract_test_runner.dart';

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

  group('Empty State UX 统一收口与回归校验', () {
    testWidgets('1. HomePage 空状态展示与跳转校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 首页无任何资料，应展示统一的空状态组件
      final contract = ContractExtractor.fromListItem(tester);
      ContractTestRunner.verify(
        contract,
        expectedHasEmptyState: true,
        expectedEmptyStateType: '暂无资料',
      );

      // 验证没有混入任何安全存储类或引导性夸大宣传文案
      expect(find.textContaining('安全存储'), findsNothing);
      expect(find.textContaining('立即开启'), findsNothing);

      // 点击“去添加资料”，校验跳转到 ItemEntryFlowPage
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('去添加资料'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
    });

    testWidgets('2. SearchPage 空状态展示与跳转校验', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // 进入搜索页
      await tester.tap(find.byKey(const Key('home_search_entry')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchPage), findsOneWidget);

      // 输入不会匹配任何记录 of 关键词
      await tester.enterText(find.byType(TextField), '不存在的资料');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 600),
      ); // 等待 debounce 完成

      // 搜索无结果时应展示统一的空状态
      final contract = ContractExtractor.fromListItem(tester);
      ContractTestRunner.verify(
        contract,
        expectedHasEmptyState: true,
        expectedEmptyStateType: '未找到匹配资料',
      );

      // 点击“去添加资料”，校验跳转到 ItemEntryFlowPage
      await tester.tap(find.text('去添加资料'));
      await tester.pumpAndSettle();

      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
    });
  });
}
