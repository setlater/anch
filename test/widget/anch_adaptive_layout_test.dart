import 'package:anch/core/widgets/anch_adaptive_layout.dart';
import 'package:anch/core/widgets/anch_app_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Anch 自适应布局', () {
    test('窗口宽度分级遵循紧凑、常规、扩展边界', () {
      expect(
        AnchLayoutBreakpoints.forWindowWidth(599),
        AnchWindowWidthClass.compact,
      );
      expect(
        AnchLayoutBreakpoints.forWindowWidth(600),
        AnchWindowWidthClass.medium,
      );
      expect(
        AnchLayoutBreakpoints.forWindowWidth(840),
        AnchWindowWidthClass.expanded,
      );
    });

    test('可用高度分级覆盖横屏、常规手机与长屏', () {
      expect(
        AnchLayoutBreakpoints.forWindowHeight(479),
        AnchWindowHeightClass.compact,
      );
      expect(
        AnchLayoutBreakpoints.forWindowHeight(480),
        AnchWindowHeightClass.medium,
      );
      expect(
        AnchLayoutBreakpoints.forWindowHeight(900),
        AnchWindowHeightClass.expanded,
      );
    });

    test('网格列数由可用宽度和卡片最小宽度决定', () {
      expect(
        AnchAdaptiveGrid.columnCountFor(
          availableWidth: 280,
          minTileWidth: 144,
          spacing: 8,
        ),
        1,
      );
      expect(
        AnchAdaptiveGrid.columnCountFor(
          availableWidth: 320,
          minTileWidth: 144,
          spacing: 8,
        ),
        2,
      );
      expect(
        AnchAdaptiveGrid.columnCountFor(
          availableWidth: 900,
          minTileWidth: 144,
          spacing: 8,
        ),
        4,
      );
    });

    testWidgets('并排字段在父容器不足时改为纵排', (tester) async {
      Future<void> pumpAtWidth(double width) {
        return tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: width,
                child: const AnchResponsiveColumns(
                  minChildWidth: 160,
                  children: [Text('开始日期'), Text('结束日期')],
                ),
              ),
            ),
          ),
        );
      }

      await pumpAtWidth(320);
      expect(
        find.descendant(
          of: find.byType(AnchResponsiveColumns),
          matching: find.byKey(const Key('anch_responsive_columns_column')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await pumpAtWidth(332);
      expect(
        find.descendant(
          of: find.byType(AnchResponsiveColumns),
          matching: find.byKey(const Key('anch_responsive_columns_row')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('扩展窗口正文保持可读宽度并居中', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AnchAppScaffold(
            body: SizedBox(
              key: const Key('anch_adaptive_body'),
              width: double.infinity,
            ),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('anch_adaptive_body')).first).width,
        AnchLayoutBreakpoints.maxContentWidth,
      );
      expect(tester.takeException(), isNull);
    });
  });
}
