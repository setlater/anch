import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/widgets/anch_blocking_progress_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('确定进度遮罩提供 Material 文字边界与可感知百分比', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: const Stack(
          children: [
            AnchBlockingProgressOverlay(
              title: '正在处理',
              message: '请保持应用在前台',
              progress: 0.42,
              semanticsLabel: '正在处理，请勿退出',
              barrierKey: ValueKey('test_progress_barrier'),
            ),
          ],
        ),
      ),
    );

    final progress = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    final inheritedStyle = DefaultTextStyle.of(
      tester.element(find.text('正在处理')),
    ).style;

    expect(progress.value, 0.42);
    expect(find.text('42%'), findsOneWidget);
    expect(inheritedStyle.decoration, TextDecoration.none);
    expect(
      find.ancestor(of: find.text('正在处理'), matching: find.byType(Material)),
      findsWidgets,
    );
    expect(
      tester
          .widget<ModalBarrier>(
            find.byKey(const ValueKey('test_progress_barrier')),
          )
          .dismissible,
      isFalse,
    );
  });

  testWidgets('可取消长操作显示明确操作且保持遮罩不可点透', (tester) async {
    var canceled = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: Stack(
          children: [
            AnchBlockingProgressOverlay(
              title: '正在传送',
              message: '请保持在前台',
              progress: 0.5,
              semanticsLabel: '正在传送',
              barrierKey: const ValueKey('cancelable-progress-barrier'),
              onCancel: () => canceled = true,
              cancelLabel: '取消传送',
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('取消传送'));

    expect(canceled, isTrue);
    expect(
      tester
          .widget<ModalBarrier>(
            find.byKey(const ValueKey('cancelable-progress-barrier')),
          )
          .dismissible,
      isFalse,
    );
  });

  testWidgets('未提供真实进度时使用加载指示，不伪装为进度条', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AnchTheme.light,
        home: const Stack(
          children: [
            AnchBlockingProgressOverlay(
              title: '正在导入',
              message: '正在准备附件',
              progress: null,
              semanticsLabel: '正在导入附件',
            ),
          ],
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });
}
