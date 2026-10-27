@Tags(['security'])
library;

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import '../support/anch_icon_finder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/features/app_lock/app_data_reset_page.dart';
import 'package:anch/core/security/app_data_reset_service.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_theme.dart';

void main() {
  group('AppDataResetPage UI 交互及两层确认测试', () {
    testWidgets('1. 页面展现真实风险说明，且默认未勾选时删除按钮处于禁用状态', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AppDataResetPage(onConfirmReset: () async {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('删除本机资料'), findsNWidgets(2));
      expect(find.textContaining('原型开发验证阶段'), findsNothing);
      expect(find.text('风险说明'), findsOneWidget);
      expect(find.text('删除本机资料是一项不可撤销的操作，将产生以下影响：'), findsOneWidget);
      expect(find.text('我已了解：删除后本机资料无法撤销，且安册无法帮助找回。'), findsOneWidget);

      // 验证重置按钮不可用
      final buttonFinder = find.byType(ElevatedButton);
      final ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.enabled, isFalse);
    });

    testWidgets('2. 勾选复选框激活第一层确认，点击后唤起第二层确认 Dialog，取消 Dialog 不会执行重置', (
      WidgetTester tester,
    ) async {
      var resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppDataResetPage(
            onConfirmReset: () async {
              resetCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 勾选同意协议以激活按钮
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      final buttonFinder = find.byType(ElevatedButton);
      final ElevatedButton button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.enabled, isTrue);

      // 2. 点击重置按钮唤起二级 Dialog
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('确认删除本机资料？'), findsOneWidget);
      expect(resetCalled, isFalse);

      // 3. 点击取消，关闭 Dialog，不执行重置
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('确认删除本机资料？'), findsNothing);
      expect(resetCalled, isFalse);
    });

    testWidgets('3. 确认二级 Dialog 后执行重置，成功后弹出验证完成 Dialog 且内容脱敏', (
      WidgetTester tester,
    ) async {
      var resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppDataResetPage(
            onConfirmReset: () async {
              resetCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // 点击确认删除
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      // 成功弹窗
      expect(find.text('本机资料已删除'), findsOneWidget);
      expect(find.text('本机资料删除操作已完成。'), findsOneWidget);

      // ⚠️ 【安全红线】绝不误导为正式安全或泄露字段
      final textFinder = find.byType(Text);
      final texts = textFinder
          .evaluate()
          .map((el) => (el.widget as Text).data ?? '')
          .toList();
      for (final t in texts) {
        expect(t.contains('正式安全模式已启用'), isFalse);
        expect(t.contains('databaseKey'), isFalse);
        expect(t.contains('PIN码'), isFalse);
      }
    });

    testWidgets('4. 删除抛出异常时只显示用户可理解的失败提示', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppDataResetPage(
            onConfirmReset: () async {
              throw const AppDataResetException(
                AppDataResetErrorType.resetFailed,
                '测试模拟重置子任务异常。',
                'databaseKey: key-123456',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();

      // 失败弹窗出现
      expect(find.text('删除失败'), findsOneWidget);
      expect(find.textContaining('删除未完成，本机现有资料可能仍保留'), findsOneWidget);
      expect(find.textContaining('AppDataResetException'), findsNothing);
      expect(find.textContaining('key-123456'), findsNothing);
    });

    testWidgets('物理清空成功后交由应用根节点重建，不显示要求手动重启的旧成功弹窗', (
      WidgetTester tester,
    ) async {
      var resetCalled = 0;
      var restartCalled = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AppDataResetPage(
            physicalReset: true,
            onConfirmReset: () async {
              resetCalled++;
            },
            onPhysicalResetCompleted: () async {
              restartCalled++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();

      expect(resetCalled, 1);
      expect(restartCalled, 1);
      expect(find.text('本机资料已删除'), findsNothing);
      expect(find.textContaining('请完全退出并重新启动应用'), findsNothing);
    });

    testWidgets(
      '5. onOpenBackupRestore 为 null 时成功 Dialog 显示“确定”按钮且不显示“前往备份恢复”',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: AppDataResetPage(
              onConfirmReset: () async {},
              onOpenBackupRestore: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('确认删除'));
        await tester.pumpAndSettle();

        expect(find.text('确定'), findsOneWidget);
        expect(find.text('前往备份恢复'), findsNothing);
        expect(find.text('稍后处理'), findsNothing);
      },
    );

    testWidgets(
      '6. onOpenBackupRestore 不为 null 时成功 Dialog 显示“稍后处理”与“前往备份恢复”按钮，点击前往备份恢复触发回调',
      (WidgetTester tester) async {
        var restoreCalled = false;
        await tester.pumpWidget(
          MaterialApp(
            home: AppDataResetPage(
              onConfirmReset: () async {},
              onOpenBackupRestore: () {
                restoreCalled = true;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(CheckboxListTile));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pumpAndSettle();

        await tester.tap(find.text('确认删除'));
        await tester.pumpAndSettle();

        expect(find.text('确定'), findsNothing);
        expect(find.text('稍后处理'), findsOneWidget);
        expect(find.text('前往备份恢复'), findsOneWidget);

        await tester.tap(find.text('前往备份恢复'));
        await tester.pumpAndSettle();

        expect(restoreCalled, isTrue);
      },
    );

    testWidgets('危险操作与成功结果消费主题语义色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AnchTheme.light,
          home: AppDataResetPage(onConfirmReset: () async {}),
        ),
      );
      await tester.pumpAndSettle();

      final colors = tester.element(find.byType(AppDataResetPage)).anchColors;
      expect(
        tester.widget<AnchIcon>(findAnchIcon(AnchIcons.danger)).color,
        colors.danger,
      );

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(
        button.style?.backgroundColor?.resolve(<WidgetState>{}),
        colors.danger,
      );
      expect(
        tester.getSize(find.byType(ElevatedButton)).height,
        greaterThanOrEqualTo(48),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('本机资料已删除')).style?.color,
        colors.success,
      );
    });
  });
}
