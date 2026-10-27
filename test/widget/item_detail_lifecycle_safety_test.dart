import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/repository/models/member_model.dart';
import 'package:anch/core/attachment/attachment_model.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/core/widgets/anch_sensitive_field_row.dart';
import 'package:anch/core/widgets/anch_info_field_row.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';

class MockItemRepository extends ItemRepository {
  final ItemWithFields mockItem;
  MockItemRepository(super.db, this.mockItem);

  @override
  Future<ItemWithFields?> getItemWithFields(String id) async {
    return mockItem;
  }
}

class MockMemberRepository extends MemberRepository {
  MockMemberRepository(super.db);

  @override
  Future<MemberModel?> getMemberById(String id) async {
    return MemberModel(
      id: id,
      memberType: 'person',
      name: '测试成员',
      avatarKey: 'avatar_0',
      sortOrder: 0,
      isSystem: false,
      isArchived: false,
      createdAt: 0,
      updatedAt: 0,
    );
  }
}

void main() {
  late RuntimeContext runtime;
  late AppDatabase db;
  late MemberRepository memberRepo;
  String? copiedText;

  const MethodChannel pathChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return '.';
          }
          return null;
        });

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
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MockMemberRepository(db);
    copiedText = null;
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
  });

  void setupMockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = methodCall.arguments['text'] as String?;
          return null;
        }
        return null;
      },
    );
  }

  Widget buildTestWidget({
    required ItemRepository itemRepo,
    required String itemId,
  }) {
    final useCaseService = ItemUseCaseService(
      itemRepo: itemRepo,
      memberRepo: memberRepo,
      runtime: runtime,
    );
    return wrapTest(
      MaterialApp(
        routes: {
          '/': (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/detail'),
              child: const Text('Go To Detail'),
            ),
          ),
          '/detail': (context) => ItemDetailPage(itemId: itemId),
          '/dummy': (context) => const Scaffold(body: Text('Dummy Page')),
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
    );
  }

  group('ItemDetailPage 交互安全收口与生命周期生命力测试', () {
    testWidgets('1. 验证 none/low/medium/high 字段的复制决策流及 SnackBar 屏蔽', (
      WidgetTester tester,
    ) async {
      setupMockClipboard(tester);

      final itemFields = [
        ItemFieldModel(
          id: 'field_none',
          itemId: 'test_item',
          fieldKey: 'is_closed', // none
          valueType: 'boolean',
          valueText: 'true',
          templateFieldKnown: true,
          isArchivedField: false,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
        ItemFieldModel(
          id: 'field_low',
          itemId: 'test_item',
          fieldKey: 'bank_name', // low
          valueType: 'text',
          valueText: 'low_value',
          templateFieldKnown: true,
          isArchivedField: false,
          sortOrder: 1,
          createdAt: 0,
          updatedAt: 0,
        ),
        ItemFieldModel(
          id: 'field_medium',
          itemId: 'test_item',
          fieldKey: 'account_name', // medium
          valueType: 'text',
          valueText: 'medium_value',
          templateFieldKnown: true,
          isArchivedField: false,
          sortOrder: 2,
          createdAt: 0,
          updatedAt: 0,
        ),
        ItemFieldModel(
          id: 'field_high',
          itemId: 'test_item',
          fieldKey: 'card_number', // high
          valueType: 'text',
          valueText: 'high_value',
          templateFieldKnown: true,
          isArchivedField: false,
          sortOrder: 3,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final mockItem = ItemWithFields(
        id: 'test_item',
        memberId: 'test_member_id',
        categoryKey: 'card',
        typeKey: 'custom_type',
        templateVersion: 1,
        title: '测试安全决策卡',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        fields: itemFields,
      );

      final itemRepo = MockItemRepository(db, mockItem);
      await tester.pumpWidget(
        buildTestWidget(itemRepo: itemRepo, itemId: 'test_item'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigate to detail page
      await tester.tap(find.text('Go To Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final noneRow = tester.widget<AnchInfoFieldRow>(
        find.byWidgetPredicate(
          (w) => w is AnchInfoFieldRow && w.fieldId == 'field_none',
        ),
      );
      noneRow.onCopy!.call('field_none');
      await tester.pump();
      expect(copiedText, equals('true'));
      copiedText = null;

      final lowRow = tester.widget<AnchInfoFieldRow>(
        find.byWidgetPredicate(
          (w) => w is AnchInfoFieldRow && w.fieldId == 'field_low',
        ),
      );
      lowRow.onCopy!.call('field_low');
      await tester.pump();
      expect(copiedText, equals('low_value'));
      copiedText = null;

      final medRow = tester.widget<AnchInfoFieldRow>(
        find.byWidgetPredicate(
          (w) => w is AnchInfoFieldRow && w.fieldId == 'field_medium',
        ),
      );
      medRow.onCopy!.call('field_medium');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('确认复制敏感字段？'), findsNothing);
      expect(copiedText, equals('medium_value'));
      copiedText = null;

      // Sensitive field is rendered directly (masked), no need to expand a card
      expect(find.text('高敏信息'), findsNothing);

      final highRow = tester.widget<AnchSensitiveFieldRow>(
        find.byWidgetPredicate(
          (w) => w is AnchSensitiveFieldRow && w.fieldId == 'field_high',
        ),
      );
      highRow.onCopy!.call('field_high');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('确认复制敏感字段？'), findsNothing);
      expect(copiedText, equals('high_value'));
      copiedText = null;
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify that snackbar doesn't leak value
      expect(find.text('已复制'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('high_value'),
        ),
        findsNothing,
      );
    });

    testWidgets('2. 验证跳转前与返回后强制重新遮蔽及生命周期遮蔽', (WidgetTester tester) async {
      final itemFields = [
        ItemFieldModel(
          id: 'field_high',
          itemId: 'test_item',
          fieldKey: 'card_number', // high
          valueType: 'text',
          valueText: '1234567890123456',
          templateFieldKnown: true,
          isArchivedField: false,
          sortOrder: 0,
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final mockItem = ItemWithFields(
        id: 'test_item',
        memberId: 'test_member_id',
        categoryKey: 'card',
        typeKey: 'custom_type',
        templateVersion: 1,
        title: '测试遮蔽跳转卡',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        fields: itemFields,
      );

      final itemRepo = MockItemRepository(db, mockItem);
      await tester.pumpWidget(
        buildTestWidget(itemRepo: itemRepo, itemId: 'test_item'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigate to detail page
      await tester.tap(find.text('Go To Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Sensitive field is rendered directly (masked), no need to expand a card
      expect(find.text('高敏信息'), findsNothing);

      // Reveal the cleartext
      final eyeIcon = findAnchIcon(AnchIcons.visibility);
      expect(eyeIcon, findsOneWidget);
      await tester.tap(eyeIcon);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('1234567890123456'), findsOneWidget);

      // Simulate app lifecycle inactive
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verification: field has been masked
      expect(find.text('1234567890123456'), findsNothing);
      expect(find.text('******'), findsOneWidget);

      // Reveal again
      await tester.tap(findAnchIcon(AnchIcons.visibility));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1234567890123456'), findsOneWidget);

      // Simulate route push to edit page
      final editBtn = findAnchIcon(AnchIcons.more);
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      // Pop back from ItemEntryFlowPage
      Navigator.of(tester.element(find.byType(ItemEntryFlowPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verification: returning to page results in fields being masked
      expect(find.text('1234567890123456'), findsNothing);
      expect(find.text('******'), findsOneWidget);
    });

    testWidgets('3. 附件预览加载态不泄露文件元数据', (WidgetTester tester) async {
      final attachments = [
        AttachmentModel(
          id: 'att_id_1',
          itemId: 'test_item',
          linkedFieldKey: 'photo',
          attachmentRole: 'other',
          fileName: 'non_existent_file.png.enc',
          originalName: 'secret_document.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 150,
          sha256: 'some_sha',
          sortOrder: 0,
          status: 'active',
          createdAt: 0,
          updatedAt: 0,
        ),
      ];

      final mockItem = ItemWithFields(
        id: 'test_item',
        memberId: 'test_member_id',
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1,
        title: '测试附件安全卡',
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        fields: const [],
        attachments: attachments,
      );

      final itemRepo = MockItemRepository(db, mockItem);
      await tester.pumpWidget(
        buildTestWidget(itemRepo: itemRepo, itemId: 'test_item'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigate to detail page
      await tester.tap(find.text('Go To Detail'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Tap on the attachment thumbnail to open preview page
      final expandHeader = find.textContaining('附件照片');
      if (expandHeader.evaluate().isNotEmpty) {
        await tester.tap(expandHeader);
        await tester.pumpAndSettle();
      }
      final thumbnail = find.byKey(const Key('attachment_item_0'));
      await tester.tap(thumbnail);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('1 / 1'), findsOneWidget);

      // 加载尚未完成时也不能暴露文件名、路径或加密扩展名。
      final List<String> allTexts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .toList();
      for (final text in allTexts) {
        expect(
          text.contains('non_existent_file.png'),
          isFalse,
          reason: 'Exposed filename',
        );
        expect(
          text.contains('.enc'),
          isFalse,
          reason: 'Exposed encrypted extension',
        );
        expect(
          text.contains('secret_document.png'),
          isFalse,
          reason: 'Exposed original filename',
        );
        expect(
          text.contains('app_documents'),
          isFalse,
          reason: 'Exposed file path',
        );
      }
    });
  });
}
