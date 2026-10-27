@Tags(['security'])
library;

import 'dart:async';

import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/security/android_secure_window_service.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/screen_protection_controller.dart';
import 'package:anch/core/security/screen_protection_dependency_bundle.dart';
import 'package:anch/core/security/screen_protection_settings_manager.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/features/main_shell.dart';
import 'package:anch/features/privacy/screen_protection_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

class _FakeSecureWindowService implements SecureWindowService {
  final values = <bool>[];
  bool failEnable = false;
  Completer<void>? enablePending;

  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {
    values.add(enabled);
    if (!enabled) return;
    if (failEnable) throw StateError('simulated platform failure');
    await enablePending?.future;
  }
}

void main() {
  late RuntimeContext runtime;
  late DependencyProvider dependencies;
  late ScreenProtectionController controller;
  late _FakeSecureWindowService service;

  Future<void> initializeDependencies() async {
    runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    final settingsManager = SecureStorageScreenProtectionSettingsManager(
      store: MemorySecureKeyValueStore(),
    );
    service = _FakeSecureWindowService();
    controller = ScreenProtectionController(
      settingsManager: settingsManager,
      secureWindowService: service,
    );
    await controller.initialize();
    dependencies = DependencyProvider.create(
      runtime: runtime,
      screenProtectionBundle: ScreenProtectionDependencyBundle(
        controller: controller,
        settingsManager: settingsManager,
      ),
      child: const SizedBox.shrink(),
    );
  }

  tearDown(() async {
    await dependencies.db.close();
    controller.dispose();
  });

  Widget buildApp(Widget page) => wrapTest(
    MaterialApp(home: page),
    runtime,
    (child) => dependencies.copyWith(child: child),
  );

  testWidgets('平台尚未确认保护时，敏感内容与操作不可访问', (tester) async {
    await initializeDependencies();
    service.enablePending = Completer<void>();
    var tapped = false;
    await tester.pumpWidget(
      buildApp(
        ScreenProtectionScope(
          child: Scaffold(
            body: TextButton(
              onPressed: () => tapped = true,
              child: const Text('虚构敏感内容'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('虚构敏感内容'), findsNothing);
    expect(tapped, isFalse);

    service.enablePending!.complete();
    await tester.pumpAndSettle();
    expect(
      controller.isForegroundProtected,
      isTrue,
      reason: 'requested=${controller.shouldProtect}; calls=${service.values}',
    );
    expect(find.text('虚构敏感内容'), findsOneWidget);
    await tester.tap(find.text('虚构敏感内容'));
    expect(tapped, isTrue);
  });

  testWidgets('平台开启保护失败时隐藏敏感内容，重试成功后恢复', (tester) async {
    await initializeDependencies();
    service.failEnable = true;
    await tester.pumpWidget(
      buildApp(
        const ScreenProtectionScope(child: Scaffold(body: Text('虚构敏感内容'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      controller.hasProtectionFailure,
      isTrue,
      reason: 'requested=${controller.shouldProtect}; calls=${service.values}',
    );
    expect(find.text('虚构敏感内容'), findsNothing);
    expect(find.text('重试屏幕保护'), findsOneWidget);

    service.failEnable = false;
    await tester.tap(find.text('重试屏幕保护'));
    await tester.pumpAndSettle();
    expect(find.text('虚构敏感内容'), findsOneWidget);
  });

  testWidgets('低敏摘要主页面在默认模式下允许截图', (tester) async {
    await initializeDependencies();
    await tester.pumpWidget(buildApp(const MainShell()));
    await tester.pumpAndSettle();

    expect(controller.shouldProtect, isFalse);
  });

  testWidgets('运行期保护失败在应用根隐藏内容，重试保留草稿', (tester) async {
    await initializeDependencies();
    await tester.pumpWidget(
      wrapTest(
        ScreenProtectionLifecycleObserver(
          controller: controller,
          child: const MaterialApp(
            home: ScreenProtectionScope(child: Scaffold(body: TextField())),
          ),
        ),
        runtime,
        (child) => dependencies.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '虚构草稿');
    await controller.setMode(ScreenProtectionMode.unrestricted);
    service.failEnable = true;
    await controller.setMode(ScreenProtectionMode.always);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('虚构草稿'), findsNothing);
    expect(find.text('无法启用屏幕保护'), findsOneWidget);

    service.failEnable = false;
    await tester.ensureVisible(find.text('重试屏幕保护'));
    await tester.tap(find.text('重试屏幕保护'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('虚构草稿'), findsOneWidget);
  });

  testWidgets('资料录入页面在默认模式下禁止截图', (tester) async {
    await initializeDependencies();
    await tester.pumpWidget(buildApp(const ItemEntryFlowPage()));
    await tester.pumpAndSettle();

    expect(controller.shouldProtect, isTrue);
  });
}
