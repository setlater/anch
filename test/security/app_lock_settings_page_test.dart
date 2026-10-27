@Tags(['security'])
library;

import 'dart:async';

import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/features/app_lock/app_lock_settings_page.dart';
import 'package:anch/features/app_lock/app_pin_setup_page.dart';
import 'package:anch/features/app_lock/app_pin_verification_page.dart';
import 'package:anch/core/widgets/anch_route_back.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _ControlledReadStore store;
  late SecureStorageAppPinManager pinManager;
  late SecureStorageAppLockSettingsManager settingsManager;
  late AppLockPreferencesManager preferencesManager;

  setUp(() {
    store = _ControlledReadStore();
    pinManager = SecureStorageAppPinManager(store: store, iterations: 10);
    settingsManager = SecureStorageAppLockSettingsManager(store: store);
    preferencesManager = AppLockPreferencesManager(store);
  });

  testWidgets('未配置时从应用锁开关进入 PIN 设置', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('尚未开启'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.byType(AppPinSetupPage), findsOneWidget);
  });

  testWidgets('已开启时展示生物识别和自动锁定方式', (tester) async {
    await pinManager.setPin('123456');
    await settingsManager.setAppLockEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('生物识别解锁'), findsOneWidget);
    expect(find.text('使用指纹等生物识别解锁，仍可使用安册 PIN'), findsOneWidget);
    expect(find.text('自动锁定方式'), findsOneWidget);
    expect(find.text('每次回到安册时'), findsOneWidget);
    expect(find.text('修改安册 PIN'), findsOneWidget);
  });

  testWidgets('应用锁设置内容使用统一 16 逻辑像素页面边距', (tester) async {
    await pinManager.setPin('123456');
    await settingsManager.setAppLockEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchTitle = find.descendant(
      of: find.byType(SwitchListTile).first,
      matching: find.text('应用锁'),
    );
    expect(tester.getTopLeft(switchTitle).dx, 16);
  });

  testWidgets('自动锁定方式可持久化为重新打开安册时', (tester) async {
    await pinManager.setPin('123456');
    await settingsManager.setAppLockEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('自动锁定方式'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重新打开安册时'));
    await tester.pumpAndSettle();

    expect(
      (await preferencesManager.load()).autoLockMode,
      AppLockAutoLockMode.nextLaunch,
    );
  });

  testWidgets('修改 PIN 的全屏验证页取消后不报 PIN 错误', (tester) async {
    await pinManager.setPin('123456');
    await settingsManager.setAppLockEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('修改安册 PIN'));
    await tester.pumpAndSettle();
    expect(find.text('验证安册 PIN'), findsOneWidget);
    expect(find.byType(AppPinVerificationPage), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byType(AnchRouteBack));
    await tester.pumpAndSettle();

    expect(find.text('验证安册 PIN'), findsNothing);
    expect(find.text('PIN 不正确'), findsNothing);
    expect(find.text('修改安册 PIN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('修改 PIN 验证失败后留在页面并允许重新输入', (tester) async {
    await pinManager.setPin('123456');
    await settingsManager.setAppLockEnabled(true);
    await tester.pumpWidget(
      MaterialApp(
        home: AppLockSettingsPage(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          preferencesManager: preferencesManager,
          biometricAuthenticator: _FakeBiometricAuthenticator(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('修改安册 PIN'));
    await tester.pumpAndSettle();
    await _tapPin(tester, '111111');
    await tester.pumpAndSettle();

    expect(find.text('PIN 不正确，请重新输入'), findsOneWidget);
    expect(find.byType(AppPinVerificationPage), findsOneWidget);
  });

  testWidgets('PIN 或启用状态读取失败时隐藏安全操作，重试去重且恢复原配置', (tester) async {
    for (final prefix in ['anch.app_pin.', 'anch.app_lock.enabled.']) {
      store = _ControlledReadStore();
      pinManager = SecureStorageAppPinManager(store: store, iterations: 10);
      settingsManager = SecureStorageAppLockSettingsManager(store: store);
      await pinManager.setPin('123456');
      await settingsManager.setAppLockEnabled(true);
      store.writes = 0;
      store.failingPrefix = prefix;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockSettingsPage(
            appPinManager: pinManager,
            appLockSettingsManager: settingsManager,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('加载安全设置失败'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.text('修改安册 PIN'), findsNothing);
      expect(find.text('尚未开启'), findsNothing);
      expect(find.textContaining('SYNTHETIC_READ_FAILURE'), findsNothing);
      expect(store.enabledReads, 1);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);

      store.failingPrefix = null;
      store.gate = Completer<void>();
      await tester.tap(find.text('重新加载'));
      await tester.tap(find.text('重新加载'));
      await tester.pump();
      expect(store.enabledReads, 2);
      expect(find.byType(SwitchListTile), findsNothing);
      store.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.text('加载安全设置失败'), findsNothing);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).first).value,
        isTrue,
      );
      expect(find.text('修改安册 PIN'), findsOneWidget);
      expect(store.writes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('读取期间退出设置页后，成功或失败的晚到结果均不更新已销毁页面', (tester) async {
    for (final failed in [false, true]) {
      final pendingStore = _ControlledReadStore()..gate = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockSettingsPage(
            appPinManager: SecureStorageAppPinManager(store: pendingStore),
            appLockSettingsManager: SecureStorageAppLockSettingsManager(
              store: pendingStore,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      if (failed) pendingStore.failingPrefix = 'anch.app_lock.enabled.';
      pendingStore.gate!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(pendingStore.writes, 0);
    }
  });
}

class _ControlledReadStore extends MemorySecureKeyValueStore {
  String? failingPrefix;
  Completer<void>? gate;
  int enabledReads = 0;
  int writes = 0;

  @override
  Future<String?> read(String key) async {
    if (key == 'anch.app_lock.enabled.v1') enabledReads++;
    if (gate != null) await gate!.future;
    if (failingPrefix != null && key.startsWith(failingPrefix!)) {
      throw StateError('SYNTHETIC_READ_FAILURE');
    }
    return super.read(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writes++;
    await super.write(key, value);
  }
}

Future<void> _tapPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_digit_$digit')));
    await tester.pump();
  }
}

class _FakeBiometricAuthenticator implements AppBiometricAuthenticator {
  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  @override
  Future<AppBiometricResult> authenticate() async => AppBiometricResult.success;

  @override
  Future<void> cancel() async {}
}
