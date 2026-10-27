@Tags(['security'])
library;

import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';
import 'package:anch/core/security/app_lock_bootstrap_service.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_lock_dependency_bundle.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import '../support/test_fakes.dart';



class FakeAppDatabase implements AppDatabase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMemberRepository implements MemberRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeItemRepository implements ItemRepository {
  @override
  Future<Map<String, int>> getActiveTypeCounts() async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeItemUseCaseService implements ItemUseCaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppLockDependencyBundle 与 DependencyProvider 集成/旁路测试', () {
    test('1. 可成功创建包含各个所需组件的 AppLockDependencyBundle 并进行严格 toString 脱敏校验', () {
      final pinManager = FakeAppPinManager(storedPin: '123456');
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
      );
      const bootstrapResult = AppLockBootstrapResult(
        hasPin: true,
        enabled: true,
        decision: AppLockBootstrapDecision.requireUnlock,
        initialState: AppLockState(status: AppLockStatus.locked),
      );

      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
      );

      expect(bundle.appPinManager, pinManager);
      expect(bundle.appLockSettingsManager, settingsManager);
      expect(bundle.appLockBootstrapService, bootstrapService);
      expect(bundle.appLockController, controller);
      expect(bundle.appLockBootstrapResult, bootstrapResult);

      // 验证 toString 脱敏性
      final bundleStr = bundle.toString().toLowerCase();
      expect(bundleStr, isNot(contains('salt')));
      expect(bundleStr, isNot(contains('verifier')));
      expect(bundleStr, isNot(contains('databasekey')));
      expect(bundleStr, isNot(contains('exception')));
    });

    test('2. AppLockRuntimeOptions 默认参数与测试旁路 shouldBypass 状态校验', () {
      // 默认开发验证路径：显式启用开关为 false，不阻断测试
      const optionsDefault = AppLockRuntimeOptions(
        appLockGateExplicitlyEnabled: false,
      );
      expect(optionsDefault.appLockGateExplicitlyEnabled, isFalse);
      expect(optionsDefault.disableForTests, isFalse);
      expect(optionsDefault.shouldBypass, isFalse);

      // 测试旁路打开时：disableForTests 为 true
      const optionsBypass = AppLockRuntimeOptions(
        appLockGateExplicitlyEnabled: true,
        disableForTests: true,
      );
      expect(optionsBypass.appLockGateExplicitlyEnabled, isTrue);
      expect(optionsBypass.disableForTests, isTrue);
      expect(optionsBypass.shouldBypass, isTrue);
    });

    testWidgets('3. DependencyProvider 默认不传入 appLockBundle 时原有业务照常运行且返回 null', (WidgetTester tester) async {
      final runtime = RuntimeProvider.create(const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ));
      final db = FakeAppDatabase();
      final memberRepo = FakeMemberRepository();
      final itemRepo = FakeItemRepository();
      final useCaseService = FakeItemUseCaseService();

      await tester.pumpWidget(
        MaterialApp(
          home: wrapTest(
            Builder(
              builder: (context) {
                final provider = DependencyProvider.of(context);
                expect(provider.appLockBundle, isNull);
                return const Text('BusinessNormal');
              },
            ),
            runtime,
            (child) => DependencyProvider.forTesting(
              runtime: runtime,
              db: db,
              memberRepo: memberRepo,
              itemRepo: itemRepo,
              itemUseCaseService: useCaseService,
              child: child,
            ),
          ),
        ),
      );

      expect(find.text('BusinessNormal'), findsOneWidget);
    });

    testWidgets('4. DependencyProvider 传入 AppLockDependencyBundle 后可通过 of(context) 在子树获取且不影响原业务', (WidgetTester tester) async {
      final runtime = RuntimeProvider.create(const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ));
      final db = FakeAppDatabase();
      final memberRepo = FakeMemberRepository();
      final itemRepo = FakeItemRepository();
      final useCaseService = FakeItemUseCaseService();

      final pinManager = FakeAppPinManager(storedPin: '123456');
      final settingsManager = FakeAppLockSettingsManager(enabled: true);
      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.disabledForDev),
      );
      const bootstrapResult = AppLockBootstrapResult(
        hasPin: true,
        enabled: true,
        decision: AppLockBootstrapDecision.disabledForDev,
        initialState: AppLockState(status: AppLockStatus.disabledForDev),
      );

      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: wrapTest(
            Builder(
              builder: (context) {
                final provider = DependencyProvider.of(context);
                expect(provider.appLockBundle, isNotNull);
                expect(provider.appLockBundle!.appLockController, controller);
                return const Text('BusinessWithAppLockBundle');
              },
            ),
            runtime,
            (child) => DependencyProvider.forTesting(
              runtime: runtime,
              db: db,
              memberRepo: memberRepo,
              itemRepo: itemRepo,
              itemUseCaseService: useCaseService,
              appLockBundle: bundle,
              child: child,
            ),
          ),
        ),
      );

      expect(find.text('BusinessWithAppLockBundle'), findsOneWidget);
    });
  });
}
