import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'core/attachment/attachment_crypto_service.dart';
import 'core/backup/attachment_restore_recovery_service.dart';
import 'package:drift/native.dart';
import 'app/dependency_provider.dart';
import 'core/app_guidance_manager.dart';
import 'app/app_session_restart_controller.dart';
import 'app/third_party_licenses.dart';
import 'core/database/app_database.dart';
import 'core/repository/member_repository.dart';
import 'core/runtime/runtime_context.dart';
import 'core/runtime/runtime_provider.dart';
import 'core/runtime/runtime_scope.dart';
import 'core/security/app_key_manager.dart';
import 'core/security/app_startup_failure.dart';
import 'core/security/anch_security_runtime_config.dart';
import 'core/security/app_data_reset_plan.dart';
import 'core/security/physical_app_data_reset_service.dart';
import 'core/theme/anch_theme.dart';
import 'core/widgets/anch_startup_failure_page.dart';
import 'features/main_shell.dart';
import 'core/security/app_lock_bootstrap_policy.dart';
import 'core/security/app_lock_bootstrap_service.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/app_lock_state.dart';
import 'core/security/app_lock_dependency_bundle.dart';
import 'core/security/app_lock_settings_manager.dart';
import 'core/security/app_pin_manager.dart';
import 'core/security/app_lock_lifecycle_controller.dart';
import 'core/security/app_biometric_authenticator.dart';
import 'core/security/app_lock_attempt_manager.dart';
import 'core/security/app_lock_preferences_manager.dart';
import 'features/app_lock/app_lock_bootstrap_gate.dart';
import 'features/app_lock/app_data_reset_page.dart';
import 'features/app_lock/app_lock_lifecycle_observer.dart';
import 'features/app_lock/app_pin_setup_page.dart';
import 'core/security/android_secure_window_service.dart';
import 'features/privacy/privacy_shield_controller.dart';
import 'features/privacy/privacy_shield_dependency_bundle.dart';
import 'features/privacy/privacy_shield_coordinator.dart';
import 'core/security/screen_protection_controller.dart';
import 'core/security/screen_protection_dependency_bundle.dart';
import 'core/security/screen_protection_settings_manager.dart';
import 'features/privacy/screen_protection_scope.dart';

// ============================================================
// 安全运行模式统一配置与显式验证开关说明
//
// 1. 默认 ANCH_SECURITY_MODE=dev 或未配置：
//    - 维持当前开发验证（inMemory）行为，不影响日常 flutter test
//    - 支持通过旧开关（ANCH_USE_ENCRYPTED_DB 等）选择性开启加密或防窥验证
// 2. ANCH_SECURITY_MODE=securityValidation（显式验证模式）：
//    - 强制开启加密数据库、安全窗口、遮罩、AppLock 等所有显式验证能力
// 3. ANCH_SECURITY_MODE=formal（正式安全模式）：
//    - 强制开启加密数据库、安全窗口、后台防窥和 AppLock
//    - Release 构建无论是否传入该参数，都自动进入此模式且不可降级
//
// ⚠️  当前仍是开发验证阶段，禁止录入真实敏感资料。
// ============================================================

/// 原型防窥安全窗口开启。
Future<void> initializeSecureWindowForPrototype({
  required bool enableSecureWindow,
  required SecureWindowService service,
}) async {
  if (!enableSecureWindow) return;
  try {
    await service.setSecureWindowEnabled(true);
  } catch (_) {
    throw AppStartupException(
      AppStartupFailureType.screenProtectionUnavailable,
      '屏幕内容保护暂不可用。',
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAnchThirdPartyLicenses();

  final config = AnchSecurityRuntimeConfig.fromEnvironment();

  runApp(AnchBootstrapRoot(config: config));
}

/// 一次已完成的应用依赖装配。
///
/// 物理清空资料后必须创建新的实例，旧数据库及其仓储不能被任何存活页面复用。
class AnchAppSession {
  const AnchAppSession({
    required this.runtime,
    required this.database,
    this.appLockBundle,
    this.privacyShieldBundle,
    this.screenProtectionBundle,
  });

  final RuntimeContext runtime;
  final AppDatabase database;
  final AppLockDependencyBundle? appLockBundle;
  final PrivacyShieldDependencyBundle? privacyShieldBundle;
  final ScreenProtectionDependencyBundle? screenProtectionBundle;
}

/// 应用依赖根。
///
/// 除首次启动外，它也负责物理清空本机资料后的受控重建：先移除旧会话子树，
/// 再重新创建安全密钥、数据库、应用锁及页面依赖，避免页面继续读取已关闭数据库。
class AnchBootstrapRoot extends StatefulWidget {
  const AnchBootstrapRoot({
    super.key,
    required this.config,
    this.createSessionForTest,
    this.childBuilderForTest,
  });

  final AnchSecurityRuntimeConfig config;

  @visibleForTesting
  final Future<AnchAppSession> Function()? createSessionForTest;

  @visibleForTesting
  final Widget Function()? childBuilderForTest;

  @override
  State<AnchBootstrapRoot> createState() => _AnchBootstrapRootState();
}

class _AnchBootstrapRootState extends State<AnchBootstrapRoot> {
  late final AppSessionRestartController _restartController;
  AnchAppSession? _session;
  AppStartupException? _failure;
  var _hasCompletedBootstrap = false;
  var _sessionGeneration = 0;

  @override
  void initState() {
    super.initState();
    _restartController = AppSessionRestartController(
      restartSessionCallback: _restartSession,
    );
    _restartSession();
  }

  Future<void> _restartSession() async {
    final generation = ++_sessionGeneration;
    if (mounted) {
      setState(() {
        _session = null;
        _failure = null;
      });
    }

    try {
      final session =
          await (widget.createSessionForTest?.call() ??
              _createProductionSession(widget.config));
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _session = session;
        _hasCompletedBootstrap = true;
      });
    } on AppStartupException catch (failure) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _failure = failure;
        _hasCompletedBootstrap = true;
      });
    } catch (_) {
      if (!mounted || generation != _sessionGeneration) return;
      setState(() {
        _failure = AppStartupException(
          AppStartupFailureType.unknown,
          '未知原因导致应用初始化失败。',
        );
        _hasCompletedBootstrap = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session != null) return _buildSessionTree(session);

    final failure = _failure;
    if (failure != null) {
      return AnchStartupFailureApp(
        failure: failure,
        onRetry:
            failure.type == AppStartupFailureType.screenProtectionUnavailable
            ? () => unawaited(_restartSession())
            : null,
      );
    }

    return _AnchSessionBootApp(isRebuilding: _hasCompletedBootstrap);
  }

  Widget _buildSessionTree(AnchAppSession session) {
    final app = widget.childBuilderForTest?.call() ?? const AnchApp();
    final screenProtectionController =
        session.screenProtectionBundle?.controller;
    final protectedApp = screenProtectionController == null
        ? app
        : ScreenProtectionLifecycleObserver(
            controller: screenProtectionController,
            child: app,
          );

    return KeyedSubtree(
      key: ValueKey<String>('anch_app_session_$_sessionGeneration'),
      child: RuntimeScope(
        runtime: session.runtime,
        child: DependencyProvider.create(
          runtime: session.runtime,
          database: session.database,
          appLockBundle: session.appLockBundle,
          privacyShieldBundle: session.privacyShieldBundle,
          screenProtectionBundle: session.screenProtectionBundle,
          appGuidanceManager: AppGuidanceManager(FlutterSecureKeyValueStore()),
          appSessionRestartController: _restartController,
          child: protectedApp,
        ),
      ),
    );
  }
}

class _AnchSessionBootApp extends StatelessWidget {
  const _AnchSessionBootApp({required this.isRebuilding});

  final bool isRebuilding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '安册',
      debugShowCheckedModeBanner: false,
      theme: AnchTheme.light,
      darkTheme: AnchTheme.dark,
      themeMode: ThemeMode.system,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
      locale: const Locale('zh', 'CN'),
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(isRebuilding ? '正在重建本机资料空间' : '正在启动安册'),
            ],
          ),
        ),
      ),
    );
  }
}

Future<AnchAppSession> _createProductionSession(
  AnchSecurityRuntimeConfig config,
) async {
  await initializeSecureWindowForPrototype(
    enableSecureWindow: config.enableSecureWindow,
    service: const AndroidSecureWindowService(),
  );

  if (config.isFormalBlocked) {
    throw AppStartupException(
      AppStartupFailureType.formalSecurityModeBlocked,
      config.blockedReason ??
          'formal security mode is not enabled in this build stage',
    );
  }

  final screenProtectionSettingsManager =
      SecureStorageScreenProtectionSettingsManager(
        store: FlutterSecureKeyValueStore(),
      );
  final screenProtectionController = ScreenProtectionController(
    settingsManager: screenProtectionSettingsManager,
    secureWindowService: const AndroidSecureWindowService(),
  );
  try {
    await screenProtectionController.initialize();
  } catch (_) {
    screenProtectionController.dispose();
    throw AppStartupException(
      AppStartupFailureType.screenProtectionUnavailable,
      '本机屏幕保护初始化失败。',
    );
  }
  if (screenProtectionController.hasProtectionFailure) {
    screenProtectionController.dispose();
    throw AppStartupException(
      AppStartupFailureType.screenProtectionUnavailable,
      '本机屏幕保护初始化失败。',
    );
  }
  final screenProtectionBundle = ScreenProtectionDependencyBundle(
    controller: screenProtectionController,
    settingsManager: screenProtectionSettingsManager,
  );

  final privacyShieldController = config.enablePrivacyShieldOverlay
      ? PrivacyShieldController()
      : null;
  final privacyShieldCoordinator = privacyShieldController != null
      ? PrivacyShieldCoordinator(controller: privacyShieldController)
      : null;
  final privacyShieldBundle =
      (privacyShieldController != null && privacyShieldCoordinator != null)
      ? PrivacyShieldDependencyBundle(
          controller: privacyShieldController,
          coordinator: privacyShieldCoordinator,
        )
      : null;

  late final String databaseKey;
  try {
    databaseKey = await SecureStorageAppKeyManager().getOrCreateDatabaseKey();
    AttachmentCryptoService.init(databaseKey);
  } on AppStartupException {
    rethrow;
  } catch (_) {
    throw AppStartupException(
      AppStartupFailureType.unknown,
      '未知原因导致本机安全密钥初始化失败。',
    );
  }

  final runtime = RuntimeProvider.create(config, databaseKey: databaseKey);
  AppDatabase? database;
  try {
    database = AppDatabase.fromOpener(runtime.databaseOpener);
    // 预热连接并在显式启动边界补齐存量数据库的系统成员。
    await database.customSelect('SELECT 1;').getSingle();
    await AttachmentRestoreRecoveryService(
      database: database,
    ).recoverPendingRestore();
    await MemberRepository(database).ensureSystemMembersExist();
  } catch (error) {
    await database?.close();
    if (error is SqliteException) {
      var type = AppStartupFailureType.databaseOpenFailed;
      if (error.extendedResultCode == 26 ||
          error.message.contains('file is not a database')) {
        type = AppStartupFailureType.databaseKeyMismatch;
      } else if (error.message.contains('corrupt')) {
        type = AppStartupFailureType.databaseCorrupted;
      }
      throw AppStartupException(type, '打开加密数据库失败。');
    }
    throw AppStartupException(AppStartupFailureType.unknown, '未知原因导致数据库初始化失败。');
  }

  // 初始化 AppLock 依赖，只在显式启用验证时加载，不干扰默认状态。
  final appLockBundle = await _buildAppLockBundleForPrototype(
    enableAppLockGate: config.enableAppLockGate,
  );

  return AnchAppSession(
    runtime: runtime,
    database: database,
    appLockBundle: appLockBundle,
    privacyShieldBundle: privacyShieldBundle,
    screenProtectionBundle: screenProtectionBundle,
  );
}

Future<AppLockDependencyBundle?> _buildAppLockBundleForPrototype({
  required bool enableAppLockGate,
}) async {
  if (!enableAppLockGate) {
    return null;
  }

  final store = FlutterSecureKeyValueStore();
  final appPinManager = SecureStorageAppPinManager(store: store);
  final appLockSettingsManager = SecureStorageAppLockSettingsManager(
    store: store,
  );
  final preferencesManager = AppLockPreferencesManager(store);
  final attemptManager = AppLockAttemptManager(store);
  final biometricAuthenticator = AndroidStrongBiometricAuthenticator();
  final preferences = await preferencesManager.load();
  final bootstrapService = AppLockBootstrapService(
    appPinManager: appPinManager,
    appLockSettingsManager: appLockSettingsManager,
    attemptManager: attemptManager,
  );

  // 调用 bootstrap，决策显式网关开启
  final bootstrapResult = await bootstrapService.bootstrap(
    appLockGateExplicitlyEnabled: true,
  );

  // 使用 bootstrapResult.initialState 构建 AppLockController
  final appLockController = AppLockController(
    initialState: bootstrapResult.initialState,
    appPinManager: appPinManager,
    attemptManager: attemptManager,
    biometricEnabled: preferences.biometricEnabled,
    appLockEnabled: bootstrapResult.enabled,
  );

  final isRequireUnlock =
      bootstrapResult.decision == AppLockBootstrapDecision.requireUnlock;
  final appLockLifecycleController = AppLockLifecycleController(
    appLockController: appLockController,
    autoLockMode: preferences.autoLockMode,
    shouldLockOnForeground: isRequireUnlock,
  );

  return AppLockDependencyBundle(
    appPinManager: appPinManager,
    appLockSettingsManager: appLockSettingsManager,
    appLockBootstrapService: bootstrapService,
    appLockController: appLockController,
    appLockBootstrapResult: bootstrapResult,
    appLockLifecycleController: appLockLifecycleController,
    appBiometricAuthenticator: biometricAuthenticator,
    appLockPreferencesManager: preferencesManager,
    appLockAttemptManager: attemptManager,
    appLockPreferences: preferences,
  );
}

class AnchApp extends StatelessWidget {
  const AnchApp({super.key});

  @override
  Widget build(BuildContext context) {
    final di = DependencyProvider.of(context);

    final appLockBundle = di.appLockBundle;
    Widget app = const MainShell();

    if (appLockBundle != null) {
      final materialApp = MaterialApp(
        title: '安册',
        debugShowCheckedModeBanner: false,
        theme: AnchTheme.light,
        darkTheme: AnchTheme.dark,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        locale: const Locale('zh', 'CN'),
        home: AppLockBootstrapGate(
          decision: appLockBundle.appLockBootstrapResult.decision,
          appLockController: appLockBundle.appLockController,
          onForgotPin: (navigatorContext) =>
              _openPhysicalReset(navigatorContext, di),
          biometricAuthenticator: appLockBundle.appBiometricAuthenticator,
          biometricEnabled: appLockBundle.appLockController.biometricEnabled,
          onResetPinWithBiometric: (navigatorContext) =>
              _resetPinWithBiometric(navigatorContext, di),
          child: _AnchMainNavigator(
            appLockController: appLockBundle.appLockController,
          ),
        ),
      );
      if (appLockBundle.appLockLifecycleController != null) {
        app = AppLockLifecycleObserver(
          lifecycleController: appLockBundle.appLockLifecycleController!,
          child: materialApp,
        );
      } else {
        app = materialApp;
      }
    } else {
      app = MaterialApp(
        title: '安册',
        debugShowCheckedModeBanner: false,
        theme: AnchTheme.light,
        darkTheme: AnchTheme.dark,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
        locale: const Locale('zh', 'CN'),
        home: const MainShell(),
      );
    }

    return app;
  }

  void _openPhysicalReset(BuildContext context, DependencyProvider di) {
    final bundle = di.appLockBundle;
    if (bundle == null) return;
    final resetService = PhysicalAppDataResetService(
      appPinManager: bundle.appPinManager,
      appLockSettingsManager: bundle.appLockSettingsManager,
      keyStore: FlutterSecureKeyValueStore(),
      closeDatabase: di.db.close,
      documentsDirectoryProvider: getApplicationDocumentsDirectory,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AppDataResetPage(
          physicalReset: true,
          onConfirmReset: () =>
              resetService.resetAppData(AppDataResetPlans.forgotPinPhysical),
          onPhysicalResetCompleted: di.appSessionRestartController?.restart,
        ),
      ),
    );
  }

  Future<bool> _resetPinWithBiometric(
    BuildContext context,
    DependencyProvider di,
  ) async {
    final bundle = di.appLockBundle;
    final authenticator = bundle?.appBiometricAuthenticator;
    if (bundle == null || authenticator == null) return false;
    final privacyController = di.privacyShieldBundle?.controller;
    Future<AppBiometricResult> authenticate() =>
        bundle.appLockController.reauthenticateWithBiometric(authenticator);
    final result = privacyController == null
        ? await authenticate()
        : await privacyController.runWhileLifecycleShieldSuppressed(
            authenticate,
          );
    if (result != AppBiometricResult.success || !context.mounted) return false;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScreenProtectionScope(
          child: AppPinSetupPage(
            appPinManager: bundle.appPinManager,
            privacyShieldCoordinator: di.privacyShieldBundle?.coordinator,
          ),
        ),
      ),
    );
    if (changed == true) bundle.appLockController.markConfiguredAndLocked();
    return changed ?? false;
  }
}

class _AnchMainNavigator extends StatefulWidget {
  const _AnchMainNavigator({required this.appLockController});

  final AppLockController appLockController;

  @override
  State<_AnchMainNavigator> createState() => _AnchMainNavigatorState();
}

class _AnchMainNavigatorState extends State<_AnchMainNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLockState>(
      valueListenable: widget.appLockController,
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: (_) => const MainShell()),
      ),
      builder: (context, state, navigator) {
        final unlocked =
            state.status == AppLockStatus.disabledForDev ||
            state.status == AppLockStatus.unlocked;
        return NavigatorPopHandler<void>(
          enabled: unlocked,
          onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
          child: KeyedSubtree(
            key: const ValueKey('anch_main_navigator'),
            child: navigator!,
          ),
        );
      },
    );
  }
}
