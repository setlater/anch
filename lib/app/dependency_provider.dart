import 'package:flutter/material.dart';

import '../core/database/app_database.dart';
import '../core/app_guidance_manager.dart';
import '../core/backup/backup_history_manager.dart';
import '../core/repository/item_repository.dart';
import '../core/repository/member_repository.dart';
import '../core/repository/attachment_repository.dart';
import '../core/repository/item_event_repository.dart';
import '../core/service/item_use_case_service.dart';
import '../core/security/app_lock_dependency_bundle.dart';
import '../core/security/app_key_manager.dart';
import '../core/security/screen_protection_dependency_bundle.dart';
import '../features/privacy/privacy_shield_dependency_bundle.dart';
import '../core/runtime/runtime_context.dart';
import '../core/runtime/runtime_provider.dart';
import '../core/security/anch_security_runtime_config.dart';
import '../core/time/time_domain_source.dart';
import '../features/item_entry/controllers/item_auto_fill_engine.dart';
import '../features/item_entry/controllers/item_entry_flow_controller.dart';
import 'main_shell_controller.dart';
import 'app_session_restart_controller.dart';

/// 极其轻量级的依赖注入容器，向子树共享核心组件单例。
class DependencyProvider extends InheritedWidget {
  final AppDatabase db;
  final MemberRepository memberRepo;
  final ItemRepository itemRepo;
  final AttachmentRepository attachmentRepo;
  final ItemEventRepository itemEventRepo;
  final ItemUseCaseService itemUseCaseService;
  final AppLockDependencyBundle? appLockBundle;
  final PrivacyShieldDependencyBundle? privacyShieldBundle;
  final ScreenProtectionDependencyBundle? screenProtectionBundle;
  final TimeDomainSource timeDomainSource;
  final MainShellController mainShellController;
  final BackupHistoryManager backupHistoryManager;
  final AppGuidanceManager appGuidanceManager;
  final AppSessionRestartController? appSessionRestartController;

  const DependencyProvider._({
    super.key,
    required this.db,
    required this.memberRepo,
    required this.itemRepo,
    required this.attachmentRepo,
    required this.itemEventRepo,
    required this.itemUseCaseService,
    required super.child,
    this.appLockBundle,
    this.privacyShieldBundle,
    this.screenProtectionBundle,
    this.timeDomainSource = const SystemTimeDomainSource(),
    required this.mainShellController,
    required this.backupHistoryManager,
    required this.appGuidanceManager,
    this.appSessionRestartController,
  });

  /// WARNING: copyWith is ONLY for widget subtree composition.
  /// Do not use it for dependency mutation or runtime DI switching.
  DependencyProvider copyWith({required Widget child}) {
    assert(
      child.runtimeType != DependencyProvider,
      'Nested DependencyProvider via copyWith is not allowed',
    );
    return DependencyProvider._(
      key: key,
      db: db,
      memberRepo: memberRepo,
      itemRepo: itemRepo,
      attachmentRepo: attachmentRepo,
      itemEventRepo: itemEventRepo,
      itemUseCaseService: itemUseCaseService,
      appLockBundle: appLockBundle,
      privacyShieldBundle: privacyShieldBundle,
      screenProtectionBundle: screenProtectionBundle,
      timeDomainSource: timeDomainSource,
      mainShellController: mainShellController,
      backupHistoryManager: backupHistoryManager,
      appGuidanceManager: appGuidanceManager,
      appSessionRestartController: appSessionRestartController,
      child: child,
    );
  }

  /// 纯静态工厂方法，负责依赖关系（service graph）的装配与构造。
  static DependencyProvider create({
    required RuntimeContext runtime,
    required Widget child,
    AppDatabase? database,
    AppLockDependencyBundle? appLockBundle,
    PrivacyShieldDependencyBundle? privacyShieldBundle,
    ScreenProtectionDependencyBundle? screenProtectionBundle,
    TimeDomainSource timeDomainSource = const SystemTimeDomainSource(),
    BackupHistoryManager? backupHistoryManager,
    AppGuidanceManager? appGuidanceManager,
    AppSessionRestartController? appSessionRestartController,
  }) {
    final actualDatabase =
        database ?? AppDatabase.fromOpener(runtime.databaseOpener);
    final mRepo = MemberRepository(actualDatabase);
    final iRepo = ItemRepository(actualDatabase);
    final attachmentRepo = AttachmentRepository(actualDatabase);
    final itemEventRepo = ItemEventRepository(actualDatabase);
    final service = ItemUseCaseService(
      itemRepo: iRepo,
      memberRepo: mRepo,
      runtime: runtime,
    );

    return DependencyProvider._(
      db: actualDatabase,
      memberRepo: mRepo,
      itemRepo: iRepo,
      attachmentRepo: attachmentRepo,
      itemEventRepo: itemEventRepo,
      itemUseCaseService: service,
      appLockBundle: appLockBundle,
      privacyShieldBundle: privacyShieldBundle,
      screenProtectionBundle: screenProtectionBundle,
      timeDomainSource: timeDomainSource,
      mainShellController: MainShellController(),
      backupHistoryManager:
          backupHistoryManager ??
          BackupHistoryManager(FlutterSecureKeyValueStore()),
      appGuidanceManager:
          appGuidanceManager ?? const AppGuidanceManager.silent(),
      appSessionRestartController: appSessionRestartController,
      child: child,
    );
  }

  @visibleForTesting
  factory DependencyProvider.forTesting({
    Key? key,
    RuntimeContext? runtime,
    AppDatabase? db,
    MemberRepository? memberRepo,
    ItemRepository? itemRepo,
    AttachmentRepository? attachmentRepo,
    ItemEventRepository? itemEventRepo,
    ItemUseCaseService? itemUseCaseService,
    required Widget child,
    AppLockDependencyBundle? appLockBundle,
    PrivacyShieldDependencyBundle? privacyShieldBundle,
    ScreenProtectionDependencyBundle? screenProtectionBundle,
    TimeDomainSource? timeDomainSource,
    MainShellController? mainShellController,
    BackupHistoryManager? backupHistoryManager,
    AppGuidanceManager? appGuidanceManager,
    AppSessionRestartController? appSessionRestartController,
  }) {
    final actualRuntime =
        runtime ??
        RuntimeProvider.create(
          const AnchSecurityRuntimeConfig(
            mode: AnchSecurityMode.dev,
            useEncryptedDatabase: false,
            enableSecureWindow: false,
            enablePrivacyShieldOverlay: false,
            enableAppLockGate: false,
            isFormalBlocked: false,
            enableAutoFillScaffold: true,
          ),
        );
    final actualDb = db ?? AppDatabase.fromOpener(actualRuntime.databaseOpener);
    final actualMemberRepo = memberRepo ?? MemberRepository(actualDb);
    final actualItemRepo = itemRepo ?? ItemRepository(actualDb);
    return DependencyProvider._(
      key: key,
      db: actualDb,
      memberRepo: actualMemberRepo,
      itemRepo: actualItemRepo,
      attachmentRepo: attachmentRepo ?? AttachmentRepository(actualDb),
      itemEventRepo: itemEventRepo ?? ItemEventRepository(actualDb),
      itemUseCaseService:
          itemUseCaseService ??
          ItemUseCaseService(
            itemRepo: actualItemRepo,
            memberRepo: actualMemberRepo,
            runtime: actualRuntime,
          ),
      appLockBundle: appLockBundle,
      privacyShieldBundle: privacyShieldBundle,
      screenProtectionBundle: screenProtectionBundle,
      timeDomainSource: timeDomainSource ?? const SystemTimeDomainSource(),
      mainShellController: mainShellController ?? MainShellController(),
      backupHistoryManager:
          backupHistoryManager ??
          BackupHistoryManager(MemorySecureKeyValueStore()),
      appGuidanceManager:
          appGuidanceManager ?? const AppGuidanceManager.silent(),
      appSessionRestartController: appSessionRestartController,
      child: child,
    );
  }

  ItemEntryFlowController createEntryFlowController({
    required bool enableAutoFillScaffold,
  }) {
    final engine = ItemAutoFillEngine(timeDomainSource: timeDomainSource);
    return ItemEntryFlowController(
      enableAutoFillScaffold: enableAutoFillScaffold,
      autoFillEngine: engine,
    );
  }

  static DependencyProvider of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<DependencyProvider>();
    assert(provider != null, 'No DependencyProvider found in context');
    return provider!;
  }

  static DependencyProvider? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DependencyProvider>();
  }

  @override
  bool updateShouldNotify(DependencyProvider oldWidget) {
    return db != oldWidget.db ||
        memberRepo != oldWidget.memberRepo ||
        itemRepo != oldWidget.itemRepo ||
        attachmentRepo != oldWidget.attachmentRepo ||
        itemEventRepo != oldWidget.itemEventRepo ||
        itemUseCaseService != oldWidget.itemUseCaseService ||
        appLockBundle != oldWidget.appLockBundle ||
        privacyShieldBundle != oldWidget.privacyShieldBundle ||
        screenProtectionBundle != oldWidget.screenProtectionBundle ||
        backupHistoryManager != oldWidget.backupHistoryManager ||
        appGuidanceManager != oldWidget.appGuidanceManager ||
        appSessionRestartController != oldWidget.appSessionRestartController ||
        mainShellController != oldWidget.mainShellController;
  }
}
