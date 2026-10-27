import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/time/time_domain_source.dart';

Widget wrapTest(
  Widget child,
  RuntimeContext runtime, [
  DependencyProvider Function(Widget child)? builder,
]) {
  final di =
      builder?.call(child) ?? _providerFor(runtime).copyWith(child: child);
  return RuntimeScope(runtime: runtime, child: di);
}

final _providersByRuntime = Expando<DependencyProvider>('testProviders');

/// 受控故障夹具只替换仓储，保留同一数据库及安全、生命周期依赖。
DependencyProvider scopeWithTestRepositories(
  DependencyProvider parent,
  Widget child, {
  MemberRepository? memberRepo,
  ItemRepository? itemRepo,
}) => DependencyProvider.forTesting(
  runtime: parent.itemUseCaseService.runtime,
  db: parent.db,
  memberRepo: memberRepo ?? parent.memberRepo,
  itemRepo: itemRepo ?? parent.itemRepo,
  itemUseCaseService: parent.itemUseCaseService,
  attachmentRepo: parent.attachmentRepo,
  itemEventRepo: parent.itemEventRepo,
  appLockBundle: parent.appLockBundle,
  privacyShieldBundle: parent.privacyShieldBundle,
  screenProtectionBundle: parent.screenProtectionBundle,
  timeDomainSource: parent.timeDomainSource,
  mainShellController: parent.mainShellController,
  backupHistoryManager: parent.backupHistoryManager,
  appGuidanceManager: parent.appGuidanceManager,
  appSessionRestartController: parent.appSessionRestartController,
  child: child,
);

DependencyProvider _providerFor(RuntimeContext runtime) {
  final existing = _providersByRuntime[runtime];
  if (existing != null) return existing;

  final provider = DependencyProvider.create(
    runtime: runtime,
    child: const SizedBox.shrink(),
  );
  _providersByRuntime[runtime] = provider;
  addTearDown(provider.db.close);
  return provider;
}

class TestRepositoryContext {
  final RuntimeContext runtime;
  final DependencyProvider di;
  final AppDatabase db;
  final MemberRepository memberRepository;
  final ItemRepository itemRepository;
  final ItemUseCaseService itemUseCaseService;

  TestRepositoryContext._({
    required this.runtime,
    required this.di,
    required this.db,
    required this.memberRepository,
    required this.itemRepository,
    required this.itemUseCaseService,
  });
}

TestRepositoryContext createTestRepositoryContext({
  AnchSecurityRuntimeConfig config = const AnchSecurityRuntimeConfig(
    mode: AnchSecurityMode.dev,
    useEncryptedDatabase: false,
    enableSecureWindow: false,
    enablePrivacyShieldOverlay: false,
    enableAppLockGate: false,
    isFormalBlocked: false,
  ),
  TimeDomainSource? timeDomainSource,
}) {
  final runtime = RuntimeProvider.create(config);
  final di = DependencyProvider.create(
    runtime: runtime,
    timeDomainSource: timeDomainSource ?? const SystemTimeDomainSource(),
    child: const SizedBox.shrink(),
  );
  _providersByRuntime[runtime] = di;
  final db = di.db;
  addTearDown(() async {
    await db.close();
  });
  return TestRepositoryContext._(
    runtime: runtime,
    di: di,
    db: db,
    memberRepository: di.memberRepo,
    itemRepository: di.itemRepo,
    itemUseCaseService: di.itemUseCaseService,
  );
}

/// 进入唯一录入流程的字段页；先选择类型，再确认默认或指定归属。
Future<void> openEntryFields(
  WidgetTester tester,
  Finder type, {
  String? owner,
}) async {
  final grid = find
      .descendant(of: find.byType(GridView), matching: find.byType(Scrollable))
      .first;
  await tester.scrollUntilVisible(type, 120, scrollable: grid);
  await tester.tap(type);
  await tester.pumpAndSettle();
  expect(find.text('选择归属'), findsOneWidget);
  if (owner != null) {
    await tester.tap(find.text(owner));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('下一步：填写资料'));
  await tester.pumpAndSettle();
}
