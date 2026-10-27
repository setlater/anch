@Tags(['security'])
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/features/app_lock/app_lock_gate.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import 'package:anch/features/app_lock/app_lock_setup_placeholder_page.dart';
import '../support/app_pin_test_helpers.dart';

void main() {
  group('AppLockGate Widget 测试', () {
    const childWidget = Text('PROTECTED_CONTENT');

    testWidgets('验证 1. disabledForDev 展示 child', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.disabledForDev),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.byType(AppLockSetupPlaceholderPage), findsNothing);
    });

    testWidgets('验证 2. unlocked 展示 child', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.byType(AppLockSetupPlaceholderPage), findsNothing);
    });

    testWidgets('验证 3. locked 展示 AppLockPage', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsNothing);
      expect(find.byType(AppLockPage), findsOneWidget);
      expect(find.byType(AppLockSetupPlaceholderPage), findsNothing);
    });

    testWidgets('验证 4. unconfigured 展示 AppLockSetupPlaceholderPage', (
      tester,
    ) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unconfigured),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsNothing);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.byType(AppLockSetupPlaceholderPage), findsOneWidget);
    });

    testWidgets('验证 5. temporarilyLocked 展示 AppLockPage', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(
          status: AppLockStatus.temporarilyLocked,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      expect(find.text('PROTECTED_CONTENT'), findsNothing);
      expect(find.byType(AppLockPage), findsOneWidget);
      expect(find.byType(AppLockSetupPlaceholderPage), findsNothing);
    });

    testWidgets('验证 5b. 锁屏覆盖输入页面时释放原输入焦点并关闭系统键盘', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            controller: controller,
            child: const Scaffold(body: TextField()),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);

      controller.value = const AppLockState(status: AppLockStatus.locked);
      await tester.pump();
      await tester.pump();

      expect(find.byType(AppLockPage), findsOneWidget);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('验证 6. 未提供真实设置入口时不提供模拟操作', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unconfigured),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      // 此时展示占位设置页
      expect(find.byType(AppLockSetupPlaceholderPage), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.text('PROTECTED_CONTENT'), findsNothing);

      expect(find.textContaining('模拟'), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(controller.value.status, AppLockStatus.unconfigured);
      expect(find.byType(AppLockSetupPlaceholderPage), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.text('PROTECTED_CONTENT'), findsNothing);
    });

    testWidgets('验证 7. 使用真实 AppPinManager 的 controller 解锁后能正确展示 child', (
      tester,
    ) async {
      final fakePinManager = FakeDelayPinManager('123456', autoComplete: false);

      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: fakePinManager,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(controller: controller, child: childWidget),
        ),
      );

      // 一开始处于 locked，展示 AppLockPage 且不展示 child
      expect(find.byType(AppLockPage), findsOneWidget);
      expect(find.text('PROTECTED_CONTENT'), findsNothing);

      await tapAppPin(tester, '123456');

      // 等待异步校验
      await tester.pump();
      expect(find.text('正在验证…'), findsOneWidget);

      fakePinManager.completeVerify(true);
      await tester.pumpAndSettle();

      // 解锁成功，AppLockPage 消失，展示 child 页面
      expect(controller.value.status, AppLockStatus.unlocked);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.text('PROTECTED_CONTENT'), findsOneWidget);
    });

    testWidgets('验证 8. onOpenPinSetup 不为空时展示真实设置入口，且点击仅触发回调', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unconfigured),
      );

      var callbackCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            controller: controller,
            onOpenPinSetup: () {
              callbackCalled = true;
            },
            child: childWidget,
          ),
        ),
      );

      // 验证按钮文案
      expect(find.text('设置应用锁 PIN'), findsOneWidget);
      expect(find.textContaining('模拟'), findsNothing);

      // 点击按钮
      await tester.tap(find.text('设置应用锁 PIN'));
      await tester.pump();

      // 断言回调被触发，但状态仍未 configured，且不直接展示 child/unlocked
      expect(callbackCalled, isTrue);
      expect(controller.value.status, AppLockStatus.unconfigured);
      expect(find.text('PROTECTED_CONTENT'), findsNothing);
    });
  });
}

class FakeDelayPinManager implements AppPinManager {
  final String correctPin;
  final bool autoComplete;
  Completer<bool>? _verifyCompleter;

  FakeDelayPinManager(this.correctPin, {this.autoComplete = true});

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<void> setPin(String pin) async {}

  @override
  Future<bool> verifyPin(String pin) {
    _verifyCompleter = Completer<bool>();
    if (autoComplete) {
      _verifyCompleter!.complete(pin == correctPin);
    }
    return _verifyCompleter!.future;
  }

  @override
  Future<void> clearPin() async {}

  void completeVerify(bool result) {
    if (_verifyCompleter != null && !_verifyCompleter!.isCompleted) {
      _verifyCompleter!.complete(result);
    }
  }
}
