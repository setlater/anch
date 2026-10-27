import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/features/main_shell.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/database/app_database.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;

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
    di = DependencyProvider.create(runtime: runtime, child: Container());
  });

  tearDown(() async {
    await di.db.close();
  });

  Widget buildTestApp() {
    return wrapTest(
      const MaterialApp(home: MainShell()),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('MainShell 页头入口与自适应导航', () {
    testWidgets('首页仅保留页头新增入口并打开录入流程', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      final add = find.byKey(const Key('home_add_item'));
      expect(add, findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(
        find.descendant(of: add, matching: find.text('新增')),
        findsOneWidget,
      );
      final icon = tester.widget<AnchIcon>(
        find.descendant(of: add, matching: findAnchIcon(AnchIcons.add)),
      );
      expect(icon.size, 20);
      expect(tester.getSize(add).height, greaterThanOrEqualTo(48));
      tester.semantics.tap(find.semantics.byLabel('新增资料'));
      await tester.pumpAndSettle();
      expect(find.byType(ItemEntryFlowPage), findsOneWidget);
    });

    testWidgets('成员和分类各有新增入口，设置没有新增入口', (tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      for (final label in ['成员', '分类', '设置']) {
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        expect(find.text('新增'), label == '设置' ? findsNothing : findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
      }
    });

    testWidgets('非活跃 Tab 延迟加载，切换后再读取最新统计', (tester) async {
      final saved = await di.itemUseCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'document',
          typeKey: 'other_document',
          title: '虚构延迟加载资料',
          fields: const [],
        ),
      );
      expect(saved.success, isTrue);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      expect(find.text('1 项资料', skipOffstage: false), findsNothing);
      await tester.tap(find.text('成员').last);
      await tester.pumpAndSettle();
      expect(find.text('1 项资料'), findsOneWidget);
    });

    testWidgets('导航适配保留页面状态，底部图标固定尺寸且选中不加底色', (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(390, 900);
      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();
      final homeState = tester.state(find.byType(HomePage));
      for (final (width, scale) in [
        (320.0, 1.0),
        (600.0, 1.0),
        (1000.0, 1.0),
        (320.0, 2.0),
        (390.0, 1.0),
      ]) {
        tester.view.physicalSize = Size(width, 900);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpAndSettle();
        expect(
          find.byType(NavigationRail),
          width >= 840 ? findsOneWidget : findsNothing,
        );
        expect(tester.state(find.byType(HomePage)), same(homeState));
        if (width < 840) {
          for (final icon in [
            AnchIcons.homeNavigation.selected,
            AnchIcons.memberNavigation.normal,
          ]) {
            final glyph = findAnchIcon(icon);
            final svg = find.descendant(
              of: glyph,
              matching: find.byType(SvgPicture),
            );
            expect(tester.getSize(svg), const Size(22, 22));
            final target = find
                .ancestor(of: glyph, matching: find.byType(GestureDetector))
                .first;
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
            final accentSoft = tester.element(glyph).anchColors.accentSoft;
            for (final box in tester.widgetList<DecoratedBox>(
              find.ancestor(of: glyph, matching: find.byType(DecoratedBox)),
            )) {
              final decoration = box.decoration;
              if (decoration is BoxDecoration) {
                expect(decoration.color, isNot(accentSoft));
              }
            }
          }
        }
        expect(tester.takeException(), isNull);
      }
    });
  });
}

