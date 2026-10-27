import 'package:anch/core/template/template_registry.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_spacing.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_category_index_item.dart';
import 'package:anch/core/widgets/anch_choice_card.dart';
import 'package:anch/core/widgets/anch_header_action.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/core/widgets/anch_page_header.dart';
import 'package:anch/core/widgets/anch_route_back.dart';
import 'package:anch/features/item_detail/item_detail_attachments_section.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/type/type_page.dart';
import 'package:anch/features/backup/export_backup_password_page.dart';
import 'package:anch/features/backup/restore_backup_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

class _AllIntentCountsRepository extends ItemRepository {
  _AllIntentCountsRepository(super.db);

  @override
  Future<Map<String, int>> getActiveTypeCounts() async => {
    for (final intent in TemplateRegistry.getCreatableTypes())
      intent.typeKey: 1,
  };
}

void main() {
  late TestRepositoryContext context;

  setUp(() {
    context = createTestRepositoryContext(
      config: const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
  });

  Widget buildTypePage({double textScale = 1}) {
    final itemRepo = _AllIntentCountsRepository(context.db);
    return wrapTest(
      MaterialApp(
        theme: AnchTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TypePage(isActive: true),
      ),
      context.runtime,
      (child) => DependencyProvider.forTesting(
        runtime: context.runtime,
        db: context.db,
        memberRepo: context.memberRepository,
        itemRepo: itemRepo,
        itemUseCaseService: context.itemUseCaseService,
        child: child,
      ),
    );
  }

  Widget buildTaskIntentPicker({double textScale = 1}) {
    final controller = context.di.createEntryFlowController(
      enableAutoFillScaffold: false,
    );
    return wrapTest(
      MaterialApp(
        theme: AnchTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: ItemEntryFlowPage(controller: controller),
      ),
      context.runtime,
      (child) => context.di.copyWith(child: child),
    );
  }

  void useCompactViewport(WidgetTester tester, {double width = 320}) {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('备份密码在横屏键盘与大字号下完整可访问，收键盘后保留返回入口', (tester) async {
    await tester.binding.setSurfaceSize(const Size(924, 412));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final keyboard = ValueNotifier(false);
    addTearDown(keyboard.dispose);
    final runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.securityValidation,
        useEncryptedDatabase: true,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
      databaseOpenerOverride: NativeAppDatabaseOpener(inMemory: true),
    );
    for (final page in [
      (widget: const ExportBackupPasswordPage(), title: '导出备份', action: '继续导出'),
      (
        widget: const RestoreBackupPasswordPage(
          directRestore: true,
          preparedFileSizeLabel: '合成文件',
        ),
        title: '恢复备份',
        action: '验证并查看范围',
      ),
    ]) {
      for (final appearance in [
        (theme: AnchTheme.light, scale: 1.0),
        (theme: AnchTheme.dark, scale: 2.0),
      ]) {
        await tester.pumpWidget(const SizedBox.shrink());
        keyboard.value = false;
        await tester.pumpWidget(
          RuntimeScope(
            runtime: runtime,
            child: MaterialApp(
              theme: appearance.theme,
              builder: (context, child) => ValueListenableBuilder(
                valueListenable: keyboard,
                builder: (context, visible, _) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: const Size(924, 412),
                    textScaler: TextScaler.linear(appearance.scale),
                    padding: const EdgeInsets.only(top: 56),
                    viewPadding: const EdgeInsets.only(top: 56),
                    viewInsets: EdgeInsets.only(bottom: visible ? 252 : 0),
                  ),
                  child: child!,
                ),
              ),
              home: page.widget,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final input = find.byType(EditableText).first;
        await tester.ensureVisible(input);
        await tester.tap(input);
        keyboard.value = true;
        await tester.pumpAndSettle();
        await Scrollable.ensureVisible(tester.element(input), alignment: .5);
        await tester.pumpAndSettle();
        expect(tester.widget<EditableText>(input).focusNode.hasFocus, isTrue);
        final viewport = tester.getRect(
          find.byType(SingleChildScrollView).first,
        );
        final inputRect = tester.getRect(input);
        expect(inputRect.top, greaterThanOrEqualTo(viewport.top - .5));
        expect(inputRect.bottom, lessThanOrEqualTo(viewport.bottom + .5));
        await tester.ensureVisible(find.text(page.action));
        await tester.pumpAndSettle();
        final action = tester.getRect(find.text(page.action));
        expect(action.top, greaterThanOrEqualTo(viewport.top - .5));
        expect(action.bottom, lessThanOrEqualTo(viewport.bottom + .5));
        FocusManager.instance.primaryFocus?.unfocus();
        keyboard.value = false;
        await tester.pumpAndSettle();
        expect(find.text(page.title), findsOneWidget);
        expect(find.byType(AnchRouteBack), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  }, tags: ['security']);

  testWidgets('200% 字号下分类页单列且没有纵向溢出', (tester) async {
    useCompactViewport(tester);

    await tester.pumpWidget(buildTypePage(textScale: 2));
    await tester.pumpAndSettle();

    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% 字号下空附件提示可换行且不溢出', (tester) async {
    useCompactViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: ItemDetailAttachmentsSection(
              attachments: const [],
              onAddAttachment: () {},
              onPreviewImages: (_, _) {},
              onOpenFileAttachment: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加照片、PDF 或文件'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('200% 字号下删除确认操作纵排且不溢出', (tester) async {
    useCompactViewport(tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: double.infinity,
            child: DeleteRecordSheet(
              itemId: 'fictional-item-id',
              service: context.itemUseCaseService,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final deleteRect = tester.getRect(find.text('移入最近删除'));
    final cancelRect = tester.getRect(find.text('取消'));
    expect(deleteRect.bottom, lessThanOrEqualTo(cancelRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('新增类型在不同宽度下重排，长名称完整显示且不出现孤字换行', (tester) async {
    useCompactViewport(tester, width: 360);
    for (final width in <double>[360, 320, 600, 1000]) {
      tester.view.physicalSize = Size(width, 1000);
      await tester.pumpWidget(buildTaskIntentPicker());
      await tester.pumpAndSettle();
      final grid = tester.widget<GridView>(find.byType(GridView));
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      if (width == 320) expect(delegate.crossAxisCount, 1);
      if (width == 360) expect(delegate.crossAxisCount, 2);
      final scrollable = find.descendant(
        of: find.byType(GridView),
        matching: find.byType(Scrollable),
      );
      tester.state<ScrollableState>(scrollable).position.jumpTo(0);
      await tester.pumpAndSettle();
      for (final label in ['港澳通行证', '学历/学位证书']) {
        await tester.scrollUntilVisible(
          find.text(label),
          100,
          scrollable: scrollable,
        );
        final title = tester.renderObject<RenderParagraph>(find.text(label));
        final boxes = title.getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: label.length),
        );
        expect(boxes.map((box) => box.top).toSet(), hasLength(1));
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('放大字号下类型卡片按宽度重排并保留足够高度', (tester) async {
    useCompactViewport(tester, width: 360);
    for (final scale in [1.3, 2.0]) {
      for (final width in <double>[320, 600, 1000]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(buildTaskIntentPicker(textScale: scale));
        await tester.pumpAndSettle();
        final grid = tester.widget<GridView>(find.byType(GridView));
        final delegate =
            grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        if (width == 320) expect(delegate.crossAxisCount, 1);
        if (scale == 2) {
          expect(delegate.mainAxisExtent, greaterThanOrEqualTo(140));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('分类身份图标使用资料图标主题色', (tester) async {
    await tester.pumpWidget(buildTypePage());
    await tester.pumpAndSettle();

    final colors = tester
        .element(find.byType(AnchCategoryIndexItem).first)
        .anchColors;
    final categoryIcon = tester.widget<AnchIcon>(
      find.descendant(
        of: find.byType(AnchCategoryIndexItem).first,
        matching: find.byType(AnchIcon),
      ),
    );
    expect(categoryIcon.color, colors.documentIcon);
  });

  testWidgets('资料类型选择图标使用资料图标主题色', (tester) async {
    var taps = 0;
    final typeIcon = AnchIcons.forTypeKey(
      TemplateRegistry.getCreatableTypes().first.typeKey,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchChoiceCard(
            title: '虚构资料类型',
            icon: typeIcon,
            compact: true,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final choiceIcon = tester.widget<AnchIcon>(
      find.byWidgetPredicate(
        (widget) => widget is AnchIcon && widget.icon == typeIcon,
      ),
    );
    final colors = tester.element(find.byType(AnchChoiceCard)).anchColors;
    final choiceCard = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byType(AnchChoiceCard),
        matching: find.byType(AnimatedContainer),
      ),
    );

    expect(choiceIcon.color, colors.documentIcon);
    expect(
      choiceCard.padding,
      const EdgeInsets.symmetric(
        horizontal: AnchSpacing.md,
        vertical: AnchSpacing.md,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(AnchChoiceCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is SizedBox && widget.height == 4,
        ),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(AnchChoiceCard));
    expect(taps, 1);
  });

  testWidgets('录入工具栏使用固定返回箭头且不预留右侧占位', (tester) async {
    useCompactViewport(tester, width: 360);
    var backCount = 0;
    var closeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchFlowHeader(
            title: '虚构资料',
            onBack: () => backCount++,
            onClose: () => closeCount++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final backFinder = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.back,
    );
    final closeFinder = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.close,
    );
    final colors = tester.element(backFinder).anchColors;
    expect(tester.widget<AnchIcon>(backFinder).size, 24);
    expect(tester.widget<AnchIcon>(closeFinder).size, 20);
    expect(tester.getSize(backFinder), const Size(24, 24));
    expect(tester.getSize(closeFinder), const Size(20, 20));
    expect(tester.getRect(backFinder).left, AnchSpacing.page);
    expect(
      tester.getRect(closeFinder).right,
      360 - AnchSpacing.page - ((48 - 20) / 2),
    );
    expect(tester.widget<AnchIcon>(backFinder).color, colors.textPrimary);
    expect(tester.widget<AnchIcon>(closeFinder).color, colors.textPrimary);
    expect(find.byType(NavigationToolbar), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AnchRouteBack),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(AnchHeaderAction),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    await tester.tap(backFinder);
    await tester.tap(closeFinder);

    expect(backCount, 1);
    expect(closeCount, 1);
  });
}
