@Tags(['security'])
library;

import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/features/app_lock/app_pin_setup_page.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('使用应用内键盘且输入满 6 位后进入确认阶段', (tester) async {
    final manager = _FakePinManager();
    await tester.pumpWidget(
      MaterialApp(home: AppPinSetupPage(appPinManager: manager)),
    );

    expect(find.text('设置安册 PIN'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await _tapPin(tester, '12345');
    await tester.pump();

    expect(find.text('设置 PIN'), findsOneWidget);
    expect(manager.setPinCalls, 0);

    await tester.tap(find.byKey(const Key('pin_digit_6')));
    await tester.pump();
    expect(find.text('再次输入 PIN'), findsOneWidget);
  });

  testWidgets('两次输入一致后保存并返回成功', (tester) async {
    final store = MemorySecureKeyValueStore();
    final manager = SecureStorageAppPinManager(store: store, iterations: 10);
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => AppPinSetupPage(appPinManager: manager),
                ),
              );
            },
            child: const Text('打开'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await _tapPin(tester, '123456');
    await tester.pump();
    await _tapPin(tester, '123456');
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(await manager.verifyPin('123456'), isTrue);
    expect(find.text('123456'), findsNothing);
  });

  testWidgets('两次输入不一致时不写入，多窗口与大字号下提示完整显示', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 360.0, 600.0, 1000.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      for (final theme in [AnchTheme.light, AnchTheme.dark]) {
        for (final scale in [1.0, 2.0]) {
          await tester.pumpWidget(const SizedBox.shrink());
          final manager = _FakePinManager();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: AppPinSetupPage(appPinManager: manager),
            ),
          );
          await _tapPin(tester, '123456');
          await tester.pump();
          await _tapPin(tester, '123457');
          await tester.pumpAndSettle();

          expect(find.text('两次输入不一致，请重新设置'), findsOneWidget);
          expect(find.text('设置 PIN'), findsOneWidget);
          expect(manager.setPinCalls, 0);
          final status = find.byKey(const Key('pin_setup_status'));
          await tester.ensureVisible(status);
          await tester.pumpAndSettle();
          final paragraph = tester.renderObject<RenderParagraph>(status);
          final painter = TextPainter(
            text: paragraph.text,
            textDirection: paragraph.textDirection,
            textScaler: paragraph.textScaler,
          )..layout(maxWidth: paragraph.size.width);
          expect(painter.height, lessThanOrEqualTo(paragraph.size.height + .5));
          painter.dispose();
          expect(
            tester.getRect(status).bottom,
            lessThanOrEqualTo(
              tester.getRect(find.byKey(const Key('pin_digit_1'))).top,
            ),
          );
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  testWidgets('存储失败时安全失败且不泄露输入', (tester) async {
    final manager = _FakePinManager(shouldFail: true);
    await tester.pumpWidget(
      MaterialApp(home: AppPinSetupPage(appPinManager: manager)),
    );
    await _tapPin(tester, '123456');
    await tester.pump();
    await _tapPin(tester, '123456');
    await tester.pumpAndSettle();

    expect(find.text('PIN 设置失败，请稍后再试'), findsOneWidget);
    expect(find.text('123456'), findsNothing);
    expect(find.text('设置 PIN'), findsOneWidget);
  });
}

Future<void> _tapPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.ensureVisible(find.byKey(Key('pin_digit_$digit')));
    await tester.tap(find.byKey(Key('pin_digit_$digit')));
    await tester.pump();
  }
}

class _FakePinManager implements AppPinManager {
  _FakePinManager({this.shouldFail = false});

  final bool shouldFail;
  int setPinCalls = 0;

  @override
  Future<void> setPin(String pin) async {
    setPinCalls++;
    if (shouldFail) throw StateError('TEST-storage-failed');
  }

  @override
  Future<bool> hasPin() async => false;

  @override
  Future<bool> verifyPin(String pin) async => false;

  @override
  Future<void> clearPin() async {}
}
