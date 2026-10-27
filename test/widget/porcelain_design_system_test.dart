import 'package:anch/core/widgets/anch_centered_notice.dart';
import 'package:anch/features/backup/backup_password_text_form_field.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_category_index_item.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/core/widgets/anch_section_header.dart';
import 'package:anch/core/widgets/anch_sensitive_plate.dart';
import 'package:anch/core/widgets/anch_detail_field_row_layout.dart';
import 'package:anch/core/widgets/anch_step_indicator.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'package:anch/widgets/card_contract/anch_card_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildApp(Widget child, {ThemeData? theme}) => MaterialApp(
    theme: theme ?? AnchTheme.light,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('详情短字段在常规手机保持同行，窄屏和大字号纵排', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in <double>[360, 320, 600, 1000]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 1000);
        await tester.pumpWidget(
          MaterialApp(
            theme: AnchTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: AnchDetailFieldRowLayout(
                    label: '姓名',
                    valueText: '虚构姓名',
                    fieldKey: 'compact_name',
                    trailing: AnchCompactIconAction(
                      icon: AnchIcons.copy,
                      onPressed: () {},
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = tester.getRect(find.text('姓名'));
        final value = tester.getRect(find.text('虚构姓名'));
        if (width == 320 || scale == 2) {
          expect(label.bottom, lessThanOrEqualTo(value.top));
        } else {
          expect(label.center.dy, closeTo(value.center.dy, 0.01));
        }
        expect(
          tester.getSize(find.byType(AnchCompactIconAction)),
          const Size(48, 48),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('短通知在亮暗主题下使用成对反色且保留操作', (tester) async {
    addTearDown(AnchCenteredNotice.dismiss);
    for (final theme in [AnchTheme.light, AnchTheme.dark]) {
      var acted = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => AnchCenteredNotice.showSuccess(
                  context,
                  '虚构通知',
                  actionLabel: '撤销',
                  onAction: () => acted = true,
                ),
                child: const Text('显示通知'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('显示通知'));
      await tester.pump();
      final notice = tester.widget<Material>(
        find.byKey(AnchCenteredNotice.noticeKey),
      );
      expect(notice.color, theme.colorScheme.inverseSurface);
      expect(
        tester.widget<Text>(find.text('虚构通知')).style?.color,
        theme.colorScheme.onInverseSurface,
      );
      await tester.tap(find.text('撤销'));
      await tester.pump();
      expect(acted, isTrue);
      expect(find.byKey(AnchCenteredNotice.noticeKey), findsNothing);
    }
  });

  testWidgets('备份输入与安全提示在亮暗主题下使用当前语义色', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    for (final theme in [AnchTheme.light, AnchTheme.dark]) {
      var toggled = false;
      await tester.pumpWidget(
        buildApp(
          Column(
            children: [
              BackupPasswordTextFormField(
                controller: controller,
                obscureText: true,
                hintText: '输入备份密码',
                onChanged: (_) {},
                onToggleVisibility: () => toggled = true,
                validator: (_) => null,
              ),
              const AnchSecurityBanner(message: '虚构安全提示'),
            ],
          ),
          theme: theme,
        ),
      );
      await tester.pumpAndSettle();
      final colors = theme.extension<AnchColorsExtension>()!;
      final input = tester.widget<TextField>(find.byType(TextField));
      expect(input.style?.color, colors.textPrimary);
      expect(input.decoration?.fillColor, colors.surface);
      expect(
        tester.widget<Text>(find.text('虚构安全提示')).style?.color,
        colors.danger,
      );
      await tester.tap(find.bySemanticsLabel('显示密码'));
      expect(toggled, isTrue);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('区块标题使用中性文字层级', (tester) async {
    await tester.pumpWidget(buildApp(const AnchSectionHeader(title: '资料信息')));

    final title = tester.widget<Text>(find.text('资料信息'));
    expect(title.style?.fontSize, 14);
    expect(title.style?.color, AnchColorsExtension.light.textSecondary);
  });

  testWidgets('普通资料使用平面行并保留点击与长按行为', (tester) async {
    var tapped = false;
    var longPressed = false;
    const model = AnchCardModel(
      title: '虚构测试资料',
      description: '虚构成员 · 测试类型',
      icon: AnchIcons.generic,
      tag: '置顶',
    );

    await tester.pumpWidget(
      buildApp(
        AnchUnifiedDataCard(
          model: model,
          onTap: () => tapped = true,
          onLongPress: () => longPressed = true,
        ),
      ),
    );

    final row = find.byType(AnchRecordRow);
    final iconSlot = find.byKey(const Key('anch_record_leading_icon_slot'));
    expect(row, findsOneWidget);
    expect(find.descendant(of: row, matching: find.byType(Card)), findsNothing);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(76));
    expect(tester.getSize(iconSlot).width, 28);
    expect(
      tester
          .widget<AnchIcon>(
            find.descendant(of: iconSlot, matching: find.byType(AnchIcon)),
          )
          .size,
      24,
    );
    final colors = tester.element(row).anchColors;
    expect(
      tester
          .widget<AnchIcon>(
            find.descendant(of: iconSlot, matching: find.byType(AnchIcon)),
          )
          .color,
      colors.documentIcon,
    );

    await tester.tap(row);
    await tester.longPress(row);
    expect(tapped, isTrue);
    expect(longPressed, isTrue);
  });

  testWidgets('敏感铭牌保持显隐复制行为与至少 48 高触控目标', (tester) async {
    var revealCount = 0;
    var copyCount = 0;
    await tester.pumpWidget(
      buildApp(
        AnchSensitivePlate(
          fieldKey: 'number',
          label: '证件号码',
          displayValue: '•••• 2345',
          isRevealed: false,
          copyButtonKey: const Key('copy'),
          onToggleReveal: () => revealCount += 1,
          onCopy: () => copyCount += 1,
        ),
      ),
    );

    expect(find.text('仅本机可见'), findsOneWidget);
    final reveal = find.byKey(const Key('primary_sensitive_reveal_button'));
    final copy = find.byKey(const Key('copy'));
    expect(tester.getSize(reveal).height, greaterThanOrEqualTo(48));
    expect(tester.getSize(copy).height, greaterThanOrEqualTo(48));

    await tester.tap(reveal);
    await tester.tap(copy);
    expect(revealCount, 1);
    expect(copyCount, 1);
  });

  testWidgets('敏感铭牌亮暗主题均消费主题表面而非固定亮色', (tester) async {
    Widget plate() => AnchSensitivePlate(
      fieldKey: 'number',
      label: '证件号码',
      displayValue: '•••• 2345',
      isRevealed: false,
      copyButtonKey: const Key('copy'),
      onToggleReveal: () {},
      onCopy: () {},
    );

    await tester.pumpWidget(buildApp(plate()));
    final light = tester.widget<Material>(
      find.byKey(const Key('anch_sensitive_plate_surface')),
    );

    await tester.pumpWidget(buildApp(plate(), theme: AnchTheme.dark));
    await tester.pumpAndSettle();
    final dark = tester.widget<Material>(
      find.byKey(const Key('anch_sensitive_plate_surface')),
    );

    expect(light.color, isNot(dark.color));
  });

  testWidgets('敏感号码在窄屏保持字号并换行展示', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      buildApp(
        const Padding(
          padding: EdgeInsets.all(16),
          child: AnchSensitivePlate(
            fieldKey: 'card_number',
            label: '卡号',
            displayValue: '6225881234567890123',
            isRevealed: true,
            copyButtonKey: Key('copy_card_number'),
            onToggleReveal: _noop,
            onCopy: _noop,
          ),
        ),
      ),
    );

    final zone = find.byKey(const Key('sensitive_value_zone_card_number'));
    final value = find.text('6225881234567890123');
    expect(value, findsOneWidget);
    expect(tester.widget<Text>(value).style?.fontSize, 20);
    expect(
      find.descendant(of: zone, matching: find.byType(FittedBox)),
      findsNothing,
    );
    expect(
      find.descendant(of: zone, matching: find.byType(SingleChildScrollView)),
      findsNothing,
    );
    expect(
      tester.getRect(value).right,
      lessThanOrEqualTo(tester.getRect(zone).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('石墨资料册基础组件适配紧凑、常规与扩展宽度及放大字体', (tester) async {
    for (final width in <double>[320, 600, 1000]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AnchTheme.light,
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: const TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SizedBox(
                width: width,
                child: ListView(
                  children: [
                    const AnchSectionHeader(title: '资料分组'),
                    const AnchStepIndicator(
                      totalSteps: 4,
                      currentStep: 2,
                      labels: ['类型', '归属', '填写', '补充'],
                    ),
                    const AnchDetailFieldRowLayout(
                      label: '长期证件的签发机关',
                      valueText: '虚构市示例区资料管理部门',
                      fieldKey: 'responsive_issuer',
                    ),
                    AnchUnifiedDataCard(
                      model: const AnchCardModel(
                        title: '虚构家庭成员的重要证件资料与长标题',
                        description: '虚构归属成员 · 可完整阅读的低敏摘要',
                        icon: AnchIcons.idCard,
                        tag: '置顶',
                      ),
                      onTap: _noop,
                    ),
                    const AnchCategoryIndexItem(
                      title: '虚构证件分类',
                      itemCount: 3,
                      icon: AnchIcons.idCard,
                      onTap: _noop,
                    ),
                    AnchSensitivePlate(
                      fieldKey: 'fictional_number',
                      label: '虚构证件号码',
                      displayValue: '••••  ••••  2345',
                      isRevealed: false,
                      copyButtonKey: const Key('responsive_copy'),
                      onToggleReveal: () {},
                      onCopy: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.byType(AnchSensitivePlate), 100);
      expect(find.byType(AnchCategoryIndexItem), findsOneWidget);
      expect(find.byType(AnchSensitivePlate), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('分类索引第一行显示图标与数量，第二行显示标题', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: const Scaffold(
          body: AnchCategoryIndexItem(
            title: '虚构证件分类',
            itemCount: 3,
            icon: AnchIcons.idCard,
            onTap: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final iconRect = tester.getRect(
      find.byKey(const Key('category_index_icon')),
    );
    final titleRect = tester.getRect(
      find.byKey(const Key('category_index_title')),
    );
    final countRect = tester.getRect(
      find.byKey(const Key('category_index_count')),
    );

    expect(iconRect.left, lessThan(countRect.left));
    expect(iconRect.top, lessThan(titleRect.top));
    expect(countRect.top, lessThan(titleRect.top));
    expect(find.text('3 条'), findsOneWidget);
    expect(find.text('虚构分类说明'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
