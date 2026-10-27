import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/app_guidance_manager.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  test('首次确认与备份提醒时间可持久化且不包含业务资料', () async {
    final store = MemorySecureKeyValueStore();
    final manager = AppGuidanceManager(store);

    expect((await manager.load()).firstUseAcknowledged, isFalse);
    await manager.acknowledgeFirstUse();
    await manager.recordBackupReminderShown(123456);

    final state = await manager.load();
    expect(state.firstUseAcknowledged, isTrue);
    expect(state.lastBackupReminderAt, 123456);
  });

  group('备份提醒策略', () {
    const policy = BackupReminderPolicy();
    final now = DateTime(2026, 8, 19);

    test('无资料或刚提醒过时不提示', () {
      expect(
        policy.evaluate(
          now: now,
          hasSavedItems: false,
          guidance: const AppGuidanceState(firstUseAcknowledged: true),
          lastBackupAt: null,
        ),
        BackupReminderKind.none,
      );
      expect(
        policy.evaluate(
          now: now,
          hasSavedItems: true,
          guidance: AppGuidanceState(
            firstUseAcknowledged: true,
            lastBackupReminderAt: now
                .subtract(const Duration(days: 3))
                .millisecondsSinceEpoch,
          ),
          lastBackupAt: null,
        ),
        BackupReminderKind.none,
      );
    });

    test('从未备份与超过 30 天分别给出低频提醒', () {
      expect(
        policy.evaluate(
          now: now,
          hasSavedItems: true,
          guidance: const AppGuidanceState(firstUseAcknowledged: true),
          lastBackupAt: null,
        ),
        BackupReminderKind.neverBackedUp,
      );
      expect(
        policy.evaluate(
          now: now,
          hasSavedItems: true,
          guidance: const AppGuidanceState(firstUseAcknowledged: true),
          lastBackupAt: now
              .subtract(const Duration(days: 31))
              .millisecondsSinceEpoch,
        ),
        BackupReminderKind.stale,
      );
    });
  });

  testWidgets('首次使用提示确认一次后不再重复展示', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 568));
    final runtime = _runtime();
    final store = MemorySecureKeyValueStore();
    final manager = AppGuidanceManager(store);
    final dependencies = DependencyProvider.create(
      runtime: runtime,
      appGuidanceManager: manager,
      child: const SizedBox(),
    );
    addTearDown(dependencies.db.close);

    Widget buildApp() => wrapTest(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: const MainShell(),
        ),
      ),
      runtime,
      (child) => dependencies.copyWith(child: child),
    );

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump();
    expect(find.text('使用安册前请确认'), findsOneWidget);

    await tester.tap(find.text('我已了解'));
    await tester.pumpAndSettle();
    expect((await manager.load()).firstUseAcknowledged, isTrue);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump();
    expect(find.text('使用安册前请确认'), findsNothing);
  });

  testWidgets('有资料且从未备份时只显示可忽略的底部提醒', (tester) async {
    final runtime = _runtime();
    final store = MemorySecureKeyValueStore();
    final manager = AppGuidanceManager(store);
    await manager.acknowledgeFirstUse();
    final dependencies = DependencyProvider.create(
      runtime: runtime,
      appGuidanceManager: manager,
      child: const SizedBox(),
    );
    addTearDown(dependencies.db.close);
    final saved = await dependencies.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'document',
        typeKey: 'other_document',
        title: '虚构资料',
        fields: const [],
      ),
    );
    expect(saved.success, isTrue);

    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(home: MainShell()),
        runtime,
        (child) => dependencies.copyWith(child: child),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('当前资料还没有可用备份，建议导出一份。'), findsOneWidget);
    expect(find.text('去备份'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
    expect(find.text('当前资料还没有可用备份，建议导出一份。'), findsNothing);
    expect(find.text('去备份'), findsNothing);
  });
}

RuntimeContext _runtime() {
  return RuntimeProvider.create(
    const AnchSecurityRuntimeConfig(
      mode: AnchSecurityMode.dev,
      useEncryptedDatabase: false,
      enableSecureWindow: false,
      enablePrivacyShieldOverlay: false,
      enableAppLockGate: false,
      isFormalBlocked: false,
    ),
  );
}
