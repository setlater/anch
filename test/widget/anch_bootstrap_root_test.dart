import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const config = AnchSecurityRuntimeConfig(
    mode: AnchSecurityMode.dev,
    useEncryptedDatabase: false,
    enableSecureWindow: false,
    enablePrivacyShieldOverlay: false,
    enableAppLockGate: false,
    isFormalBlocked: false,
  );

  testWidgets('物理清空后的会话重建替换旧依赖树，页面只读取新数据库', (WidgetTester tester) async {
    final firstDatabase = AppDatabase.fromOpener(
      NativeAppDatabaseOpener(inMemory: true),
    );
    AppDatabase? secondDatabase;
    final runtime = RuntimeProvider.create(
      config,
      databaseOpenerOverride: NativeAppDatabaseOpener(inMemory: true),
    );
    var sessionCreations = 0;

    Future<AnchAppSession> createSession() async {
      sessionCreations++;
      return AnchAppSession(
        runtime: runtime,
        database: sessionCreations == 1
            ? firstDatabase
            : (secondDatabase = AppDatabase.fromOpener(
                NativeAppDatabaseOpener(inMemory: true),
              )),
      );
    }

    await tester.pumpWidget(
      AnchBootstrapRoot(
        config: config,
        createSessionForTest: createSession,
        childBuilderForTest: () => MaterialApp(
          home: Builder(
            builder: (context) {
              final database = DependencyProvider.of(context).db;
              final sessionLabel = identical(database, firstDatabase)
                  ? '旧会话资料'
                  : '新会话资料';
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(sessionLabel),
                      ElevatedButton(
                        onPressed: () async {
                          await database.close();
                          await DependencyProvider.of(
                            context,
                          ).appSessionRestartController!.restart();
                        },
                        child: const Text('重建会话'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('旧会话资料'), findsOneWidget);

    await tester.tap(find.text('重建会话'));
    await tester.pumpAndSettle();

    expect(sessionCreations, 2);
    expect(find.text('旧会话资料'), findsNothing);
    expect(find.text('新会话资料'), findsOneWidget);

    await secondDatabase?.close();
  });
}
