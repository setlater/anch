@Tags(['security'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';
import 'package:anch/core/security/app_lock_bootstrap_service.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_lifecycle_controller.dart';
import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/features/app_lock/app_lock_bootstrap_gate.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import '../support/app_pin_test_helpers.dart';

void main() {
  Widget buildGate({
    required AppLockBootstrapDecision decision,
    required AppLockController controller,
    VoidCallback? onOpenPinSetup,
    VoidCallback? onBackToSettings,
  }) {
    return MaterialApp(
      home: AppLockBootstrapGate(
        decision: decision,
        appLockController: controller,
        onOpenPinSetup: onOpenPinSetup,
        onBackToSettings: onBackToSettings,
        child: const Text('受保护内容'),
      ),
    );
  }

  for (final decision in [
    AppLockBootstrapDecision.disabledForDev,
    AppLockBootstrapDecision.unlockedForPrototype,
  ]) {
    testWidgets('$decision 放行内容', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.unlocked),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        buildGate(decision: decision, controller: controller),
      );
      expect(find.text('受保护内容'), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
    });
  }

  testWidgets('PIN 配置缺失时隐藏内容，仅通过真实设置回调继续', (tester) async {
    final controller = AppLockController();
    addTearDown(controller.dispose);
    var opened = false;
    await tester.pumpWidget(
      buildGate(
        decision: AppLockBootstrapDecision.requireSetup,
        controller: controller,
        onOpenPinSetup: () => opened = true,
      ),
    );
    expect(find.text('受保护内容'), findsNothing);
    expect(find.text('应用锁配置需要修复'), findsWidgets);
    await tester.tap(find.text('重新设置应用锁 PIN'));
    expect(opened, isTrue);
    expect(controller.value.status, AppLockStatus.disabledForDev);
  });

  testWidgets('实际管理器读取失败时启动门禁阻断内容且不提供 PIN 重设', (tester) async {
    for (final prefix in ['anch.app_pin.', 'anch.app_lock.enabled.']) {
      final store = _SelectiveReadFailureStore();
      final pin = SecureStorageAppPinManager(store: store, iterations: 10);
      final settings = SecureStorageAppLockSettingsManager(store: store);
      await pin.setPin('123456');
      await settings.setAppLockEnabled(true);
      store.failingPrefix = prefix;
      final result = await AppLockBootstrapService(
        appPinManager: pin,
        appLockSettingsManager: settings,
      ).bootstrap(appLockGateExplicitlyEnabled: true);
      final controller = AppLockController(initialState: result.initialState);
      try {
        var returned = false;
        await tester.pumpWidget(
          buildGate(
            decision: result.decision,
            controller: controller,
            onOpenPinSetup: () => fail('配置异常不得进入 PIN 设置'),
            onBackToSettings: () => returned = true,
          ),
        );
        expect(find.text('应用锁配置异常'), findsWidgets);
        expect(find.text('受保护内容'), findsNothing);
        expect(find.text('重新设置应用锁 PIN'), findsNothing);
        await tester.tap(find.text('返回应用锁设置'));
        expect(returned, isTrue);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  });

  testWidgets('错误 PIN 保持遮挡且不显示输入，正确 PIN 才放行', (tester) async {
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.locked),
      prototypePin: '123456',
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      buildGate(
        decision: AppLockBootstrapDecision.requireUnlock,
        controller: controller,
      ),
    );
    expect(find.byType(AppLockPage), findsOneWidget);
    expect(find.text('受保护内容'), findsNothing);
    await tapAppPin(tester, '111111');
    await tester.pumpAndSettle();
    expect(find.text('PIN 不正确'), findsOneWidget);
    expect(find.text('受保护内容'), findsNothing);
    expect(find.text('111111'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tapAppPin(tester, '123456');
    await tester.pumpAndSettle();
    expect(find.text('受保护内容'), findsOneWidget);
    expect(find.byType(AppLockPage), findsNothing);
  });

  testWidgets('子路由回前台后锁屏覆盖全局，取消生物认证仍需 PIN', (tester) async {
    final controller = AppLockController(
      initialState: const AppLockState(status: AppLockStatus.unlocked),
      prototypePin: '123456',
      biometricEnabled: true,
      appLockEnabled: true,
    );
    addTearDown(controller.dispose);
    var now = 0;
    final lifecycle = AppLockLifecycleController(
      appLockController: controller,
      autoLockMode: AppLockAutoLockMode.everyForeground,
      nowMillis: () => now,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockBootstrapGate(
          decision: AppLockBootstrapDecision.requireUnlock,
          appLockController: controller,
          biometricAuthenticator: _CancelledBiometric(),
          biometricEnabled: true,
          child: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (context) => settings.name == '/sensitive'
                  ? const Scaffold(body: Text('子页敏感内容'))
                  : Scaffold(
                      body: TextButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/sensitive'),
                        child: const Text('打开子页'),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开子页'));
    await tester.pumpAndSettle();
    expect(find.text('子页敏感内容'), findsOneWidget);
    lifecycle.handleLifecycleState(AppLifecycleState.paused);
    now = 1;
    lifecycle.handleLifecycleState(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(controller.value.status, AppLockStatus.locked);
    expect(find.byType(AppLockPage), findsOneWidget);
    expect(find.text('子页敏感内容'), findsNothing);
    expect(find.text('子页敏感内容', skipOffstage: false), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AppLockPage), findsOneWidget);
    expect(find.text('子页敏感内容', skipOffstage: false), findsOneWidget);
    await tapAppPin(tester, '123456');
    await tester.pumpAndSettle();
    expect(find.byType(AppLockPage), findsNothing);
    expect(find.text('子页敏感内容'), findsOneWidget);
  });
}

class _SelectiveReadFailureStore extends MemorySecureKeyValueStore {
  String? failingPrefix;

  @override
  Future<String?> read(String key) {
    if (failingPrefix != null && key.startsWith(failingPrefix!)) {
      throw StateError('SYNTHETIC_READ_FAILURE');
    }
    return super.read(key);
  }
}

class _CancelledBiometric implements AppBiometricAuthenticator {
  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  @override
  Future<AppBiometricResult> authenticate() async =>
      AppBiometricResult.cancelled;

  @override
  Future<void> cancel() async {}
}
