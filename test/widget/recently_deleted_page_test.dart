import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/features/mine/recently_deleted_page.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  late AppDatabase db;
  late ItemRepository itemRepo;
  late ItemUseCaseService service;
  late DependencyProvider dependencies;

  setUp(() async {
    final runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    db = AppDatabase.fromOpener(NativeAppDatabaseOpener(inMemory: true));
    dependencies = DependencyProvider.create(
      runtime: runtime,
      database: db,
      child: const SizedBox.shrink(),
    );
    itemRepo = dependencies.itemRepo;
    service = dependencies.itemUseCaseService;
  });

  tearDown(() => db.close());

  Widget buildPage() {
    return wrapTest(
      const MaterialApp(home: RecentlyDeletedPage()),
      RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      ),
      (child) => dependencies.copyWith(child: child),
    );
  }

  Future<String> seedDeletedItem(String title) async {
    final itemId = await itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        templateVersion: 1,
        title: title,
        status: 'active',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        fields: const [],
      ),
      recordUserEvent: true,
    );
    expect((await service.deleteItem(itemId)).success, isTrue);
    return itemId;
  }

  testWidgets('最近删除可恢复资料', (tester) async {
    final itemId = await seedDeletedItem('TEST-RESTORE-ITEM');

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('TEST-RESTORE-ITEM'), findsOneWidget);

    await tester.tap(find.text('恢复'));
    await tester.pumpAndSettle();

    expect(find.text('暂无最近删除的资料'), findsOneWidget);
    final restored = await itemRepo.getItemWithFields(itemId);
    expect(restored?.status, 'active');
    expect(restored?.deletedAt, isNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('永久删除需要二次确认并清除数据库记录', (tester) async {
    final itemId = await seedDeletedItem('TEST-PERMANENT-DELETE-ITEM');

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    final deleteButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '永久删除'),
    );
    final colors = tester.element(find.text('永久删除')).anchColors;
    expect(deleteButton.style?.foregroundColor?.resolve({}), colors.danger);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '恢复'))
          .style
          ?.foregroundColor
          ?.resolve({}),
      isNot(colors.danger),
    );
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();
    expect(find.text('永久删除资料？'), findsOneWidget);
    final confirmButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '永久删除').last,
    );
    expect(confirmButton.style?.foregroundColor?.resolve({}), colors.danger);

    await tester.tap(find.text('永久删除').last);
    await tester.pumpAndSettle();

    expect(find.text('暂无最近删除的资料'), findsOneWidget);
    expect(await itemRepo.getItemWithFields(itemId), isNull);
    await tester.pump(const Duration(seconds: 2));
  });
}
