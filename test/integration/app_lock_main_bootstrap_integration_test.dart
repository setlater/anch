@Tags(['security', 'integration'])
library;

import 'dart:async';

import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/features/privacy/privacy_shield_dependency_bundle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart'; // 导入 buildAnchRootApp
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/security/app_key_manager.dart'; // MemorySecureKeyValueStore
import 'package:anch/core/security/app_lock_bootstrap_policy.dart';
import 'package:anch/core/security/app_lock_bootstrap_service.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';
import 'package:anch/core/security/app_lock_dependency_bundle.dart';
import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import 'package:anch/features/app_lock/app_lock_recovery_page.dart';
import 'package:anch/core/security/app_lock_lifecycle_controller.dart';
import 'package:anch/features/app_lock/app_lock_lifecycle_observer.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/all_items/archived_items_page.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/core/backup/backup_file_save_service.dart';
import 'package:anch/core/backup/backup_unavailable_attachment.dart';
import 'package:anch/features/backup/export_backup_password_page.dart';
import 'package:anch/features/mine/recently_deleted_page.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import '../support/app_pin_test_helpers.dart';

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late ItemUseCaseService useCaseService;

  setUp(() {
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);
    useCaseService = ItemUseCaseService(
      itemRepo: itemRepo,
      memberRepo: memberRepo,
      runtime: RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildRootApp(
    AppLockDependencyBundle? appLockBundle, {
    PrivacyShieldDependencyBundle? privacyShieldBundle,
  }) {
    final runtimeContext = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
      databaseOpenerOverride: NativeAppDatabaseOpener(inMemory: true),
    );
    return RuntimeScope(
      runtime: runtimeContext,
      child: DependencyProvider.forTesting(
        runtime: runtimeContext,
        db: db,
        memberRepo: memberRepo,
        itemRepo: itemRepo,
        itemUseCaseService: useCaseService,
        appLockBundle: appLockBundle,
        privacyShieldBundle: privacyShieldBundle,
        child: const AnchApp(),
      ),
    );
  }

  group('main.dart 启动编排与显式验证集成测试', () {
    testWidgets('永久删除确认不能越过 PIN 锁页，解锁后才可继续删除', (tester) async {
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          categoryKey: 'other',
          typeKey: 'generic',
          title: 'TEST-LOCKED-DELETE',
          fields: [],
        ),
      );
      expect((await useCaseService.deleteItem(itemId)).success, isTrue);
      final store = MemorySecureKeyValueStore();
      final pinManager = SecureStorageAppPinManager(
        store: store,
        iterations: 10,
      );
      final settingsManager = SecureStorageAppLockSettingsManager(store: store);
      await settingsManager.setAppLockEnabled(true);
      await pinManager.setPin('123456');
      final bootstrap = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final result = await bootstrap.bootstrap(
        appLockGateExplicitlyEnabled: true,
      );
      final controller = AppLockController(
        initialState: result.initialState,
        appPinManager: pinManager,
      );
      await tester.pumpWidget(
        buildRootApp(
          AppLockDependencyBundle(
            appPinManager: pinManager,
            appLockSettingsManager: settingsManager,
            appLockBootstrapService: bootstrap,
            appLockController: controller,
            appLockBootstrapResult: result,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tapAppPin(tester, '123456');
      await tester.pumpAndSettle();
      final navigator = tester.state<NavigatorState>(
        find.descendant(
          of: find.byKey(const ValueKey('anch_main_navigator')),
          matching: find.byType(Navigator),
        ),
      );
      unawaited(
        navigator.push<void>(
          MaterialPageRoute(builder: (_) => const RecentlyDeletedPage()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('永久删除'));
      await tester.pumpAndSettle();
      expect(find.text('永久删除资料？'), findsOneWidget);
      controller.lock();
      await tester.pumpAndSettle();
      expect(find.text('永久删除资料？'), findsNothing);
      expect(find.text('永久删除').hitTestable(), findsNothing);
      expect(find.text('1').hitTestable(), findsOneWidget);
      expect((await itemRepo.getItemWithFields(itemId))?.status, 'deleted');
      await tapAppPin(tester, '123456');
      await tester.pumpAndSettle();
      expect(find.text('永久删除资料？'), findsOneWidget);
      await tester.tap(find.text('永久删除').hitTestable());
      await tester.pumpAndSettle();
      expect(await itemRepo.getItemWithFields(itemId), isNull);
      expect(find.byType(RecentlyDeletedPage), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('1. 未注入应用锁时首屏直接渲染 MainShell', (WidgetTester tester) async {
      await tester.pumpWidget(buildRootApp(null));
      await tester.pumpAndSettle();

      // 应显示原有主页面及操作按钮
      expect(find.text('首页'), findsOneWidget);
      expect(find.byKey(const Key('home_add_item')), findsOneWidget);
      expect(find.byType(AppLockPage), findsNothing);
      expect(find.byType(AppLockRecoveryPage), findsNothing);
    });

    testWidgets(
      '2. 开关 true 且未启用 App 锁 (decision = unlockedForPrototype)：放行进入 MainShell，不锁屏',
      (WidgetTester tester) async {
        final store = MemorySecureKeyValueStore();
        final pinManager = SecureStorageAppPinManager(store: store);
        final settingsManager = SecureStorageAppLockSettingsManager(
          store: store,
        );
        final bootstrapService = AppLockBootstrapService(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
        );

        // 模拟未开启应用锁 (enabled = false, hasPin = false)
        final bootstrapResult = await bootstrapService.bootstrap(
          appLockGateExplicitlyEnabled: true,
        );

        expect(
          bootstrapResult.decision,
          AppLockBootstrapDecision.unlockedForPrototype,
        );

        final controller = AppLockController(
          initialState: bootstrapResult.initialState,
          appPinManager: pinManager,
        );

        final bundle = AppLockDependencyBundle(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          appLockBootstrapService: bootstrapService,
          appLockController: controller,
          appLockBootstrapResult: bootstrapResult,
        );

        await tester.pumpWidget(buildRootApp(bundle));
        await tester.pumpAndSettle();

        // 放行：显示主界面，不显示锁屏页
        expect(find.text('首页'), findsOneWidget);
        expect(find.byType(AppLockPage), findsNothing);
        expect(find.byType(AppLockRecoveryPage), findsNothing);
      },
    );

    testWidgets('2b. 归档列表进入详情后，系统返回只退出详情并保留归档列表', (tester) async {
      final saved = await useCaseService.saveDraft(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          title: '虚构归档返回资料',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '虚构银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6228480000000000',
            ),
          ],
        ),
      );
      expect(saved.success, isTrue);
      expect((await useCaseService.archiveItem(saved.itemId!)).success, isTrue);

      final store = MemorySecureKeyValueStore();
      final pinManager = SecureStorageAppPinManager(store: store);
      final settingsManager = SecureStorageAppLockSettingsManager(store: store);
      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final bootstrapResult = await bootstrapService.bootstrap(
        appLockGateExplicitlyEnabled: true,
      );
      final controller = AppLockController(
        initialState: bootstrapResult.initialState,
        appPinManager: pinManager,
      );
      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
      );

      await tester.pumpWidget(buildRootApp(bundle));
      await tester.pumpAndSettle();

      final nestedNavigator = tester.state<NavigatorState>(
        find.descendant(
          of: find.byKey(const ValueKey('anch_main_navigator')),
          matching: find.byType(Navigator),
        ),
      );
      unawaited(
        nestedNavigator.push<void>(
          MaterialPageRoute(builder: (_) => const ArchivedItemsPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArchivedItemsPage), findsOneWidget);

      unawaited(
        nestedNavigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ItemDetailPage(itemId: saved.itemId!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ItemDetailPage), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(ItemDetailPage), findsNothing);
      expect(find.byType(ArchivedItemsPage), findsOneWidget);
      expect(find.text('已归档资料'), findsOneWidget);
    });

    testWidgets(
      '3. 开关 true 且已启用锁但未配置 PIN (decision = requireSetup)：MainShell 隐藏，显示配置修复页',
      (WidgetTester tester) async {
        final store = MemorySecureKeyValueStore();
        final pinManager = SecureStorageAppPinManager(store: store);
        final settingsManager = SecureStorageAppLockSettingsManager(
          store: store,
        );

        // 模拟 enabled = true，hasPin = false
        await settingsManager.setAppLockEnabled(true);

        final bootstrapService = AppLockBootstrapService(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
        );
        final bootstrapResult = await bootstrapService.bootstrap(
          appLockGateExplicitlyEnabled: true,
        );

        expect(bootstrapResult.decision, AppLockBootstrapDecision.requireSetup);

        final controller = AppLockController(
          initialState: bootstrapResult.initialState,
          appPinManager: pinManager,
        );

        final bundle = AppLockDependencyBundle(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          appLockBootstrapService: bootstrapService,
          appLockController: controller,
          appLockBootstrapResult: bootstrapResult,
        );

        await tester.pumpWidget(buildRootApp(bundle));
        await tester.pumpAndSettle();

        // 阻断：MainShell 不可见，显示修复页
        expect(find.text('首页'), findsNothing);
        expect(find.byType(AppLockRecoveryPage), findsOneWidget);
        expect(find.text('应用锁配置需要修复'), findsNWidgets(2));
      },
    );

    testWidgets(
      '4. 开关 true 且已启用锁并配置了 PIN (decision = requireUnlock)：拦截锁屏，输入正确 PIN 后放行',
      (WidgetTester tester) async {
        final store = MemorySecureKeyValueStore();
        final pinManager = SecureStorageAppPinManager(
          store: store,
          iterations: 10,
        ); // 加速 pbkdf2 计算
        final settingsManager = SecureStorageAppLockSettingsManager(
          store: store,
        );

        // 模拟 enabled = true, hasPin = true
        await settingsManager.setAppLockEnabled(true);
        await pinManager.setPin('123456');

        final bootstrapService = AppLockBootstrapService(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
        );
        final bootstrapResult = await bootstrapService.bootstrap(
          appLockGateExplicitlyEnabled: true,
        );

        expect(
          bootstrapResult.decision,
          AppLockBootstrapDecision.requireUnlock,
        );

        final controller = AppLockController(
          initialState: bootstrapResult.initialState,
          appPinManager: pinManager,
        );

        final bundle = AppLockDependencyBundle(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          appLockBootstrapService: bootstrapService,
          appLockController: controller,
          appLockBootstrapResult: bootstrapResult,
        );

        await tester.pumpWidget(buildRootApp(bundle));
        await tester.pumpAndSettle();

        // 1. 锁屏展示，MainShell 被阻断
        expect(find.text('首页'), findsNothing);
        expect(find.byType(AppLockPage), findsOneWidget);
        expect(find.text('安册已锁定'), findsOneWidget);

        await tapAppPin(tester, '111111');
        await tester.pumpAndSettle();

        expect(find.text('首页'), findsNothing);
        expect(find.text('PIN 不正确'), findsOneWidget);

        await tapAppPin(tester, '123456');
        await tester.pumpAndSettle();

        // 4. 解锁成功：主页正常显示
        expect(find.text('首页'), findsOneWidget);
        expect(find.byType(AppLockPage), findsNothing);
      },
    );

    testWidgets(
      '5. bootstrap 发生读取错误时 (decision = configurationError)：阻断并渲染配置异常页，不显示细节',
      (WidgetTester tester) async {
        // 构造一个在读取 hasPin 和 isAppLockEnabled 时抛出异常的 Fake Manager
        final pinManager = FakeExceptionPinManager();
        final settingsManager = FakeExceptionSettingsManager();
        final bootstrapService = AppLockBootstrapService(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
        );

        final bootstrapResult = await bootstrapService.bootstrap(
          appLockGateExplicitlyEnabled: true,
        );

        expect(
          bootstrapResult.decision,
          AppLockBootstrapDecision.configurationError,
        );

        final controller = AppLockController(
          initialState: bootstrapResult.initialState,
          appPinManager: pinManager,
        );

        final bundle = AppLockDependencyBundle(
          appPinManager: pinManager,
          appLockSettingsManager: settingsManager,
          appLockBootstrapService: bootstrapService,
          appLockController: controller,
          appLockBootstrapResult: bootstrapResult,
        );

        await tester.pumpWidget(buildRootApp(bundle));
        await tester.pumpAndSettle();

        // 阻断异常：不进入 MainShell，不泄露异常内容
        expect(find.text('首页'), findsNothing);
        expect(find.byType(AppLockRecoveryPage), findsOneWidget);
        expect(find.text('应用锁配置异常'), findsNWidgets(2));
        expect(find.textContaining('Exception:'), findsNothing);
      },
    );

    testWidgets(
      '6. 默认开关 false (appLockBundle == null) 时组件树中不包含 AppLockLifecycleObserver',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildRootApp(null));
        await tester.pumpAndSettle();

        expect(find.byType(AppLockLifecycleObserver), findsNothing);
      },
    );

    testWidgets('7. 解锁后导出失败，回前台重锁时附件明细不能盖住 PIN 页面', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      int mockTime = 1000;
      final store = MemorySecureKeyValueStore();
      final pinManager = SecureStorageAppPinManager(
        store: store,
        iterations: 10,
      );
      final settingsManager = SecureStorageAppLockSettingsManager(store: store);

      await settingsManager.setAppLockEnabled(true);
      await pinManager.setPin('123456');

      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final bootstrapResult = await bootstrapService.bootstrap(
        appLockGateExplicitlyEnabled: true,
      );

      final controller = AppLockController(
        initialState: bootstrapResult.initialState,
        appPinManager: pinManager,
      );

      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: true,
        nowMillis: () => mockTime,
      );

      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
        appLockLifecycleController: lifecycleController,
      );

      await tester.pumpWidget(buildRootApp(bundle));
      await tester.pumpAndSettle();

      // 验证包含 AppLockLifecycleObserver
      expect(find.byType(AppLockLifecycleObserver), findsOneWidget);

      await tapAppPin(tester, '123456');
      await tester.pumpAndSettle();

      expect(find.text('首页'), findsOneWidget);
      expect(controller.value.status, AppLockStatus.unlocked);

      final nestedNavigator = tester.state<NavigatorState>(
        find.descendant(
          of: find.byKey(const ValueKey('anch_main_navigator')),
          matching: find.byType(Navigator),
        ),
      );
      unawaited(
        nestedNavigator.push<void>(
          MaterialPageRoute(
            builder: (_) => ExportBackupPasswordPage(
              onExportForTestOrPrototype: (_, _) async {
                throw BackupFileSaveException(
                  BackupFileSaveErrorType.sourceUnavailable,
                  '附件缺失。',
                  unavailableAttachments: const [
                    BackupUnavailableAttachment(
                      itemId: 'test-item',
                      itemTitle: 'TEST-LOCK-FIXTURE',
                      originalName: 'TEST-MISSING.png',
                      reason: BackupUnavailableAttachmentReason.fileMissing,
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var index = 0; index < 2; index++) {
        await tester.enterText(
          find.byType(TextFormField).at(index),
          'temporary-test-password',
        );
      }
      await tester.ensureVisible(find.text('继续导出'));
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('backup_export_failure_dialog')),
        findsOneWidget,
      );

      // 触发后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // 超过30秒前台唤醒
      mockTime = 32000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // 应被重新锁定
      expect(controller.value.status, AppLockStatus.locked);
      expect(find.byType(AppLockPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('backup_export_failure_dialog')),
        findsNothing,
      );
      expect(find.text('1').hitTestable(), findsOneWidget);
      await tapAppPin(tester, '123456');
      await tester.pumpAndSettle();
      expect(controller.value.status, AppLockStatus.unlocked);
      expect(
        find.byKey(const ValueKey('backup_export_failure_dialog')),
        findsOneWidget,
      );
      expect(find.text('安全保护已生效'), findsOneWidget);
      await tester.tap(find.text('我知道了').hitTestable());
      await tester.pumpAndSettle();
      expect(find.text('安全保护已生效'), findsNothing);
      await tester.tap(find.text('我知道了').hitTestable());
      await tester.pumpAndSettle();
      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);
      expect(
        tester
            .widgetList<TextFormField>(find.byType(TextFormField))
            .every((field) => field.controller!.text.isEmpty),
        isTrue,
      );
    });

    testWidgets('8. requireUnlock 下若尚未解锁 (locked)，后台与回前台后依然保持 locked', (
      WidgetTester tester,
    ) async {
      int mockTime = 1000;
      final store = MemorySecureKeyValueStore();
      final pinManager = SecureStorageAppPinManager(
        store: store,
        iterations: 10,
      );
      final settingsManager = SecureStorageAppLockSettingsManager(store: store);

      await settingsManager.setAppLockEnabled(true);
      await pinManager.setPin('123456');

      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final bootstrapResult = await bootstrapService.bootstrap(
        appLockGateExplicitlyEnabled: true,
      );

      final controller = AppLockController(
        initialState: bootstrapResult.initialState,
        appPinManager: pinManager,
      );

      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: true,
        nowMillis: () => mockTime,
      );

      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
        appLockLifecycleController: lifecycleController,
      );

      await tester.pumpWidget(buildRootApp(bundle));
      await tester.pumpAndSettle();

      expect(controller.value.status, AppLockStatus.locked);

      // 处于后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // 唤醒
      mockTime = 40000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // 依然是 locked，并且锁屏可见
      expect(controller.value.status, AppLockStatus.locked);
      expect(find.byType(AppLockPage), findsOneWidget);
    });

    testWidgets('9. unlockedForPrototype 状态下，回前台不会被误锁定', (
      WidgetTester tester,
    ) async {
      int mockTime = 1000;
      final store = MemorySecureKeyValueStore();
      final pinManager = SecureStorageAppPinManager(store: store);
      final settingsManager = SecureStorageAppLockSettingsManager(store: store);

      final bootstrapService = AppLockBootstrapService(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
      );
      final bootstrapResult = await bootstrapService.bootstrap(
        appLockGateExplicitlyEnabled: true,
      );

      final controller = AppLockController(
        initialState: bootstrapResult.initialState,
        appPinManager: pinManager,
      );

      // 因为 unlockedForPrototype 时，shouldLockOnForeground 应传入 false
      final lifecycleController = AppLockLifecycleController(
        appLockController: controller,
        autoLockMode: AppLockAutoLockMode.everyForeground,
        shouldLockOnForeground: false,
        nowMillis: () => mockTime,
      );

      final bundle = AppLockDependencyBundle(
        appPinManager: pinManager,
        appLockSettingsManager: settingsManager,
        appLockBootstrapService: bootstrapService,
        appLockController: controller,
        appLockBootstrapResult: bootstrapResult,
        appLockLifecycleController: lifecycleController,
      );

      await tester.pumpWidget(buildRootApp(bundle));
      await tester.pumpAndSettle();

      expect(controller.value.status, AppLockStatus.unlocked);

      // 后台
      mockTime = 1000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // 唤醒
      mockTime = 50000;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // 不应被误锁，主页可见
      expect(controller.value.status, AppLockStatus.unlocked);
      expect(find.text('首页'), findsOneWidget);
    });
  });
}

class FakeExceptionPinManager implements AppPinManager {
  @override
  Future<bool> hasPin() async {
    throw Exception('Keystore IO Error!');
  }

  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<bool> verifyPin(String pin) async => false;
  @override
  Future<void> clearPin() async {}
}

class FakeExceptionSettingsManager implements AppLockSettingsManager {
  @override
  Future<bool> isAppLockEnabled() async {
    throw Exception('Secure Storage read error!');
  }

  @override
  Future<void> setAppLockEnabled(bool enabled) async {}
  @override
  Future<void> clear() async {}
}
