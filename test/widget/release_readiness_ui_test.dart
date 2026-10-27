import 'package:anch/core/security/app_startup_failure.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_startup_failure_page.dart';
import 'package:anch/features/help/about_page.dart';
import 'package:anch/features/help/help_center_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('正式版新增页面自适应与无障碍检查', () {
    testWidgets('离线帮助在紧凑深色大字体下可完整滚动且无溢出', (tester) async {
      await _setCompactSurface(tester);
      await tester.pumpWidget(
        _app(theme: AnchTheme.dark, home: const HelpCenterPage()),
      );
      await tester.pumpAndSettle();

      for (var index = 0; index < 8; index++) {
        await tester.drag(find.byType(ListView), const Offset(0, -240));
        await tester.pump();
      }

      expect(find.text('7. 换机或手机丢失'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('关于页在紧凑深色大字体下不裁切关键信息', (tester) async {
      await _setCompactSurface(tester);
      await tester.pumpWidget(
        _app(theme: AnchTheme.dark, home: const AboutPage()),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -240));
      await tester.pump();

      expect(find.text('版本 1.0.0（1）'), findsOneWidget);
      expect(find.textContaining('支付密码'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final type in [
      AppStartupFailureType.databaseKeyMismatch,
      AppStartupFailureType.formalSecurityModeBlocked,
    ]) {
      testWidgets('启动失败页 $type 在紧凑大字体下可读且无溢出', (tester) async {
        await _setCompactSurface(tester);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: AnchStartupFailureApp(
              failure: AppStartupException(type, '脱敏测试错误'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('错误类型'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _app({required ThemeData theme, required Widget home}) {
  return MaterialApp(
    theme: theme,
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: home,
    ),
  );
}

Future<void> _setCompactSurface(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(320, 568));
}
