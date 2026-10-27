import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_scope.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import '../support/test_bootstrap.dart';

void main() {
  test('依赖根的仓储与用例共享同一数据库和依赖实例', () {
    final context = createTestRepositoryContext();
    final di = context.di;
    expect(di.itemRepo.db, same(di.db));
    expect(di.memberRepo.db, same(di.db));
    expect(di.itemUseCaseService.itemRepo, same(di.itemRepo));
    expect(di.itemUseCaseService.memberRepo, same(di.memberRepo));
  });
  group('RuntimeScope Tests', () {
    testWidgets('propagates RuntimeContext down the widget tree', (
      WidgetTester tester,
    ) async {
      final config = AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      );
      final runtime = RuntimeProvider.create(config);

      late RuntimeContext lookupResult;

      await tester.pumpWidget(
        RuntimeScope(
          runtime: runtime,
          child: Builder(
            builder: (context) {
              lookupResult = RuntimeScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(lookupResult, equals(runtime));
      expect(lookupResult.isDevMode, isTrue);
      expect(lookupResult.isEncrypted, isFalse);
    });

    testWidgets(
      'throws AssertionError when RuntimeScope is missing in context',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              expect(() => RuntimeScope.of(context), throwsAssertionError);
              return const SizedBox();
            },
          ),
        );
      },
    );
  });
}
