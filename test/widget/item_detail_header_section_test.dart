import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/features/item_detail/item_detail_field_sections.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final textScale in <double>[1, 1.3, 2]) {
    for (final title in <String>['虚构资料标题', '虚构资料标题较长，需要换到第二行展示']) {
      testWidgets('详情标题图标对齐首行，字号 $textScale、标题「$title」', (tester) async {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: MaterialApp(
              theme: AnchTheme.light,
              home: const Scaffold(body: SizedBox()),
              builder: (context, _) => Scaffold(
                body: SizedBox(
                  width: 260,
                  child: ItemDetailHeaderSection(
                    title: title,
                    icon: AnchIcons.idCard,
                    tags: const [],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleBox = tester.getRect(find.text(title));
        final iconLineBox = tester.getRect(
          find.byKey(const Key('detail_title_icon_line_box')),
        );
        final iconBox = tester.getRect(
          find.byKey(const Key('detail_title_type_icon')),
        );

        expect(iconLineBox.top, closeTo(titleBox.top, 0.1));
        expect(iconBox.center.dy, closeTo(iconLineBox.center.dy, 0.1));
        expect(tester.takeException(), isNull);

        final renderedIcon = tester.widget<AnchIcon>(
          find.byKey(const Key('detail_title_type_icon')),
        );
        expect(renderedIcon.size, 24);
      }, skip: false);
    }
  }
}
