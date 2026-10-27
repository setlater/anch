@Tags(['security'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import 'package:anch/features/app_lock/app_data_reset_page.dart';
import '../support/app_pin_test_helpers.dart';

void main() {
  group('AppLockPage 忘记 PIN 恢复入口与路由衔接 Widget 测试', () {
    late AppLockController lockController;

    setUp(() {
      lockController = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );
    });

    testWidgets('1. onForgotPin 为 null 时，默认不显示忘记 PIN 入口且正常解锁', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(controller: lockController, onForgotPin: null),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('忘记 PIN？'), findsNothing);

      await tapAppPin(tester, '123456');
      await tester.pumpAndSettle();

      expect(lockController.value.status, AppLockStatus.unlocked);
    });

    testWidgets('2. onForgotPin 不为 null 时，显示入口且点击可以正常跳转/触发回调', (
      WidgetTester tester,
    ) async {
      var forgotPinCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(
            controller: lockController,
            onForgotPin: () {
              forgotPinCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('忘记 PIN？'), findsOneWidget);

      await tester.tap(find.text('忘记 PIN？'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除本机资料'));
      await tester.pumpAndSettle();

      expect(forgotPinCalled, isTrue);
    });

    testWidgets('3. 验证路由衔接：点击忘记 PIN 进入重置数据页面，并在重置成功后触发备份恢复回调', (
      WidgetTester tester,
    ) async {
      var restoreCalled = false;
      var resetCalled = false;

      // 模拟一个路由衔接：点击 忘记PIN -> Push 到 AppDataResetPage
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name == '/reset') {
              return MaterialPageRoute<void>(
                builder: (context) => AppDataResetPage(
                  onConfirmReset: () async {
                    resetCalled = true;
                  },
                  onOpenBackupRestore: () {
                    restoreCalled = true;
                  },
                ),
              );
            }
            return null;
          },
          home: Builder(
            builder: (context) {
              return AppLockPage(
                controller: lockController,
                onForgotPin: () {
                  Navigator.of(context).pushNamed('/reset');
                },
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. 点击“忘记 PIN？”
      await tester.tap(find.text('忘记 PIN？'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除本机资料'));
      await tester.pumpAndSettle();

      // 验证已打开重置页面，此时默认不执行重置
      expect(
        find.text('删除本机资料'),
        findsNWidgets(2),
      ); // AppBar title and Button text
      expect(resetCalled, isFalse);

      // 2. 勾选第一层强确认
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      // 3. 点击重置按钮唤起第二层确认 Dialog
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('确认删除本机资料？'), findsOneWidget);

      // 4. 点击确认删除，触发 reset 逻辑
      await tester.tap(find.text('确认删除'));
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);

      // 5. 此时成功 Dialog 应该带有“前往备份恢复”和“稍后处理”
      expect(find.text('稍后处理'), findsOneWidget);
      expect(find.text('前往备份恢复'), findsOneWidget);

      // 6. 点击前往备份恢复，应安全触发 restore 回调并返回 AppLockPage
      await tester.tap(find.text('前往备份恢复'));
      await tester.pumpAndSettle();

      expect(restoreCalled, isTrue);
      // 应该返回到 AppLockPage
      expect(find.text('安册已锁定'), findsOneWidget);
    });
  });
}
