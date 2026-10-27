import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;

  setUp(() {
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
    di = DependencyProvider.create(runtime: runtime, child: const SizedBox());
    db = di.db;
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('首页不再提供重复设置入口', (tester) async {
    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(home: HomePage(isActive: true)),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home_settings_entry')), findsNothing);
  });
}
