import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_spacing.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_header_action.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/core/widgets/anch_page_header.dart';
import 'package:anch/core/widgets/anch_route_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('固定返回箭头不使用按钮视觉且保留 48 触控范围', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(body: AnchRouteBack(onBack: () => tapCount++)),
      ),
    );

    final back = find.byType(AnchRouteBack);
    final icon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.back,
    );
    expect(tester.getSize(back), const Size(48, 48));
    expect(tester.widget<AnchIcon>(icon).size, 24);
    expect(
      find.descendant(of: back, matching: find.byType(Material)),
      findsNothing,
    );
    expect(
      find.descendant(of: back, matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.tap(icon);
    expect(tapCount, 1);
  });

  testWidgets('子页标题贴近返回箭头并隐藏描述', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchPageHeader(title: '张三', subtitle: '个人名下资料', onBack: () {}),
        ),
      ),
    );

    final title = find.text('张三');
    final icon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.back,
    );
    expect(find.text('个人名下资料'), findsNothing);
    expect(tester.widget<Text>(title).style?.fontSize, 18);
    expect(
      tester.getTopLeft(title).dx - tester.getBottomRight(icon).dx,
      AnchSpacing.sm,
    );
    expect(
      (tester.getCenter(title).dy - tester.getCenter(icon).dy).abs(),
      lessThanOrEqualTo(2),
    );
  });

  testWidgets('标题操作使用平面 20 图标且保留 48 触控范围', (tester) async {
    var tapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchHeaderAction(
            icon: AnchIcons.edit,
            semanticLabel: '编辑成员',
            onTap: () => tapCount++,
          ),
        ),
      ),
    );

    final action = find.byType(AnchHeaderAction);
    final icon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.edit,
    );
    expect(tester.getSize(action), const Size(48, 48));
    expect(tester.widget<AnchIcon>(icon).size, 20);
    expect(
      find.descendant(of: action, matching: find.byType(Material)),
      findsNothing,
    );
    expect(
      find.descendant(of: action, matching: find.byType(InkWell)),
      findsNothing,
    );

    await tester.tap(icon);
    expect(tapCount, 1);
  });

  testWidgets('成员式子页操作紧跟标题且不撑高标题区', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Scaffold(
          body: AnchPageHeader(
            title: '张三',
            titleTrailingText: '[3条]',
            onBack: () {},
            trailingFollowsTitle: true,
            trailing: AnchHeaderAction(
              icon: AnchIcons.edit,
              semanticLabel: '编辑成员',
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final title = find.text('张三');
    final count = find.text('[3条]');
    final editIcon = find.byWidgetPredicate(
      (widget) => widget is AnchIcon && widget.icon == AnchIcons.edit,
    );
    expect(
      tester.getTopLeft(count).dx - tester.getBottomRight(title).dx,
      AnchSpacing.sm,
    );
    expect(
      tester.getTopLeft(editIcon).dx - tester.getBottomRight(count).dx,
      AnchSpacing.sm,
    );
    expect(
      (tester.getCenter(editIcon).dy - tester.getCenter(title).dy).abs(),
      lessThanOrEqualTo(2),
    );
  });
}
