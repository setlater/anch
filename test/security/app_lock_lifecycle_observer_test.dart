@Tags(['security'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_lifecycle_controller.dart';
import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/features/app_lock/app_lock_lifecycle_observer.dart';

void main() {
  group('AppLockLifecycleObserver 单元测试', () {
    testWidgets('1. 构建 AppLockLifecycleObserver 后 child 可见', (
      WidgetTester tester,
    ) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
      );

      await tester.pumpWidget(
        AppLockLifecycleObserver(
          lifecycleController: lifecycleController,
          child: const MaterialApp(home: Scaffold(body: Text('Child Visible'))),
        ),
      );

      expect(find.text('Child Visible'), findsOneWidget);
    });

    testWidgets('2. 触发真实后台后回到安册会使 unlocked 状态进入 locked', (
      WidgetTester tester,
    ) async {
      int mockTime = 1000;
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: true,
        nowMillis: () => mockTime,
      );

      await tester.pumpWidget(
        AppLockLifecycleObserver(
          lifecycleController: lifecycleController,
          child: const MaterialApp(home: Scaffold(body: Text('Test Child'))),
        ),
      );

      expect(controller.value.status, AppLockStatus.unlocked);

      // 进入后台 (遵循 Flutter 标准合法流转: resumed -> inactive -> hidden -> paused)
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 回到前台 (遵循 Flutter 标准合法流转: paused -> hidden -> inactive -> resumed)
      // 回到前台。
      mockTime = 32000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller.value.status, AppLockStatus.locked);
    });

    testWidgets('3. 每次回到安册时模式不等待时长，真实后台后立即锁定', (WidgetTester tester) async {
      int mockTime = 1000;
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: true,
        nowMillis: () => mockTime,
      );

      await tester.pumpWidget(
        AppLockLifecycleObserver(
          lifecycleController: lifecycleController,
          child: const MaterialApp(home: Scaffold(body: Text('Test Child'))),
        ),
      );

      expect(controller.value.status, AppLockStatus.unlocked);

      // 进入后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 回到前台，即使只离开极短时间也锁定。
      mockTime = 11000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(controller.value.status, AppLockStatus.locked);
    });

    testWidgets('4. shouldLockOnForeground 为 false 时后台往返不触发锁定', (
      WidgetTester tester,
    ) async {
      int mockTime = 1000;
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: false,
        nowMillis: () => mockTime,
      );

      await tester.pumpWidget(
        AppLockLifecycleObserver(
          lifecycleController: lifecycleController,
          child: const MaterialApp(home: Scaffold(body: Text('Test Child'))),
        ),
      );

      expect(controller.value.status, AppLockStatus.unlocked);

      // 进入后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 回到前台。
      mockTime = 41000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 不应被误锁定
      expect(controller.value.status, AppLockStatus.unlocked);
    });

    testWidgets('5. dispose 之后不会响应生命周期事件', (WidgetTester tester) async {
      int mockTime = 1000;
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: true,
        nowMillis: () => mockTime,
      );

      await tester.pumpWidget(
        AppLockLifecycleObserver(
          lifecycleController: lifecycleController,
          child: const MaterialApp(home: Scaffold(body: Text('Test Child'))),
        ),
      );

      // 替换掉 widget 触发 dispose
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Text('Cleaned'))),
      );

      // 进入后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      // 回到前台
      mockTime = 40000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      // 不应产生任何锁定，因为已经 dispose 移除了监听
      expect(controller.value.status, AppLockStatus.unlocked);
    });
  });
}
