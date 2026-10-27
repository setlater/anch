@Tags(['security'])
library;

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import '../support/anch_icon_finder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/features/app_lock/app_lock_recovery_page.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_theme.dart';

/// [AppLockRecoveryPage] 组件测试。
///
/// 覆盖 pinMissingButEnabled 与 configurationError 两种场景的
/// 文案展示、按钮触发和禁止文案验证。
void main() {
  group('AppLockRecoveryPage 组件测试', () {
    // ----------------------------------------------------------------
    // 辅助方法
    // ----------------------------------------------------------------

    /// 构建测试用 Widget，包裹 MaterialApp。
    Widget buildPage(AppLockRecoveryPage page) {
      return MaterialApp(home: page);
    }

    // ----------------------------------------------------------------
    // pinMissingButEnabled 场景
    // ----------------------------------------------------------------

    group('pinMissingButEnabled 场景', () {
      testWidgets('验证 1. 展示标题"应用锁配置需要修复"', (tester) async {
        await tester.pumpWidget(
          buildPage(
            const AppLockRecoveryPage(
              reason: AppLockRecoveryReason.pinMissingButEnabled,
            ),
          ),
        );

        expect(find.text('应用锁配置需要修复'), findsWidgets);
      });

      testWidgets('验证 2. 展示按钮"重新设置应用锁 PIN"', (tester) async {
        await tester.pumpWidget(
          buildPage(
            AppLockRecoveryPage(
              reason: AppLockRecoveryReason.pinMissingButEnabled,
              onOpenPinSetup: () {},
            ),
          ),
        );

        expect(find.text('重新设置应用锁 PIN'), findsOneWidget);
      });

      testWidgets('验证 3. 点击"重新设置应用锁 PIN"触发 onOpenPinSetup 回调', (tester) async {
        bool called = false;

        await tester.pumpWidget(
          buildPage(
            AppLockRecoveryPage(
              reason: AppLockRecoveryReason.pinMissingButEnabled,
              onOpenPinSetup: () {
                called = true;
              },
              onBackToSettings: () {},
            ),
          ),
        );

        await tester.tap(find.text('重新设置应用锁 PIN'));
        await tester.pump();

        expect(called, isTrue);
      });

      testWidgets(
        '验证 6. 点击"返回应用锁设置"触发 onBackToSettings 回调（pinMissingButEnabled）',
        (tester) async {
          bool called = false;

          await tester.pumpWidget(
            buildPage(
              AppLockRecoveryPage(
                reason: AppLockRecoveryReason.pinMissingButEnabled,
                onOpenPinSetup: () {},
                onBackToSettings: () {
                  called = true;
                },
              ),
            ),
          );

          await tester.tap(find.text('返回应用锁设置'));
          await tester.pump();

          expect(called, isTrue);
        },
      );
    });

    // ----------------------------------------------------------------
    // configurationError 场景
    // ----------------------------------------------------------------

    group('configurationError 场景', () {
      testWidgets('验证 4. 展示标题"应用锁配置异常"', (tester) async {
        await tester.pumpWidget(
          buildPage(
            const AppLockRecoveryPage(
              reason: AppLockRecoveryReason.configurationError,
            ),
          ),
        );

        expect(find.text('应用锁配置异常'), findsWidgets);
      });

      testWidgets('验证 5. configurationError 不展示"重新设置应用锁 PIN"按钮', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildPage(
            AppLockRecoveryPage(
              reason: AppLockRecoveryReason.configurationError,
              // onOpenPinSetup 即使传入，configurationError 也不应展示此按钮
              onOpenPinSetup: () {},
              onBackToSettings: () {},
            ),
          ),
        );

        // configurationError 页面设计上不提供"重新设置 App PIN 原型"按钮
        expect(find.text('重新设置应用锁 PIN'), findsNothing);
      });

      testWidgets(
        '验证 6. 点击"返回应用锁设置"触发 onBackToSettings 回调（configurationError）',
        (tester) async {
          bool called = false;

          await tester.pumpWidget(
            buildPage(
              AppLockRecoveryPage(
                reason: AppLockRecoveryReason.configurationError,
                onBackToSettings: () {
                  called = true;
                },
              ),
            ),
          );

          await tester.tap(find.text('返回应用锁设置'));
          await tester.pump();

          expect(called, isTrue);
        },
      );
    });

    // ----------------------------------------------------------------
    // 禁止文案验证（两种场景通用）
    // ----------------------------------------------------------------

    group('禁止文案验证', () {
      for (final reason in AppLockRecoveryReason.values) {
        testWidgets('验证 7. "$reason 场景"不出现"正式安全模式已启用"', (tester) async {
          await tester.pumpWidget(
            buildPage(AppLockRecoveryPage(reason: reason)),
          );
          expect(find.textContaining('正式安全模式已启用'), findsNothing);
        });

        testWidgets('验证 8. "$reason 场景"不出现"可以录入真实敏感资料"', (tester) async {
          await tester.pumpWidget(
            buildPage(AppLockRecoveryPage(reason: reason)),
          );
          expect(find.textContaining('可以录入真实敏感资料'), findsNothing);
        });

        testWidgets('验证 9. "$reason 场景"不出现"已清除本地数据"', (tester) async {
          await tester.pumpWidget(
            buildPage(AppLockRecoveryPage(reason: reason)),
          );
          expect(find.textContaining('已清除本地数据'), findsNothing);
        });

        testWidgets('验证 10. "$reason 场景"不出现"已重置 App"', (tester) async {
          await tester.pumpWidget(
            buildPage(AppLockRecoveryPage(reason: reason)),
          );
          expect(find.textContaining('已重置 App'), findsNothing);
        });
      }
    });

    testWidgets('警告与异常状态消费主题语义色，按钮触控高度不少于 48', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final reason in AppLockRecoveryReason.values) {
        for (final width in [360.0, 700.0, 1000.0]) {
          await tester.binding.setSurfaceSize(Size(width, 900));
          await tester.pumpWidget(
            MaterialApp(
              theme: AnchTheme.light,
              home: AppLockRecoveryPage(
                reason: reason,
                onOpenPinSetup: () {},
                onBackToSettings: () {},
              ),
            ),
          );

          final colors = tester
              .element(find.byType(AppLockRecoveryPage))
              .anchColors;
          final icon = tester.widget<AnchIcon>(
            findAnchIcon(
              reason == AppLockRecoveryReason.pinMissingButEnabled
                  ? AnchIcons.settings
                  : AnchIcons.error,
            ),
          );
          expect(
            icon.color,
            reason == AppLockRecoveryReason.pinMissingButEnabled
                ? colors.warning
                : colors.danger,
          );

          for (final button in find.byType(ButtonStyleButton).evaluate()) {
            expect(
              tester.getSize(find.byWidget(button.widget)).height,
              greaterThanOrEqualTo(48),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    });
  });
}
