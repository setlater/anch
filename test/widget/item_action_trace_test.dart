import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/item_event_model.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart'
    hide ItemEventType;
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/core/template/field_value_type.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late ItemUseCaseService service;

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
    di = DependencyProvider.create(
      runtime: runtime,
      child: const SizedBox.shrink(),
    );
    db = di.db;
    memberRepo = di.memberRepo;
    itemRepo = di.itemRepo;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildDetailWidget(String itemId) {
    return wrapTest(
      MaterialApp(
        home: _DetailTestRoot(key: ValueKey(itemId), itemId: itemId),
      ),
      runtime,
      (child) => DependencyProvider.forTesting(
        runtime: runtime,
        db: db,
        memberRepo: memberRepo,
        itemRepo: itemRepo,
        itemUseCaseService: service,
        child: child,
      ),
    );
  }

  group('ItemDetailPage & ItemEntryFlowPage Widget Trace Tests', () {
    testWidgets(
      'verify history trace shows in DetailPage, is folded by default, and rebuilds on notifier updates',
      (WidgetTester tester) async {
        final draft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'credit_card',
          title: '测试轨迹卡片',
          fields: [
            ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '民生银行'),
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ),
          ],
        );
        final saveResult = await service.saveDraft(draft);
        expect(saveResult.success, isTrue);
        final itemId = saveResult.itemId!;

        await tester.pumpWidget(buildDetailWidget(itemId));
        await tester.pumpAndSettle();

        // 1. Verify collapsed action panel is present by default
        expect(find.text('操作记录'), findsOneWidget);
        // Content should not be visible initially since it is collapsed
        expect(find.text('已创建'), findsNothing);

        // 2. Expand the trace history section
        final actionTraceFinder = find.text('操作记录');
        await tester.ensureVisible(actionTraceFinder);
        await tester.tap(actionTraceFinder);
        await tester.pumpAndSettle();

        // Now, the recorded create trace should show up
        expect(find.text('已创建'), findsOneWidget);
        expect(find.textContaining('测试轨迹卡片'), findsOneWidget);

        // 3. 真实保存更新后，持久化事件流应驱动详情页刷新。
        final updateResult = await service.saveDraft(
          ItemDraftInput(
            id: itemId,
            memberId: draft.memberId,
            categoryKey: draft.categoryKey,
            typeKey: draft.typeKey,
            title: draft.title,
            fields: [
              ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '虚构银行乙'),
              draft.fields.last,
            ],
          ),
        );
        expect(updateResult.success, isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(buildDetailWidget(itemId));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('操作记录'));
        await tester.tap(find.text('操作记录'));
        await tester.pumpAndSettle();

        expect(find.text('已更新'), findsOneWidget);
        expect(find.text('银行名称已修改'), findsOneWidget);
      },
    );

    testWidgets('verify events stay isolated by item and restore is persisted', (
      WidgetTester tester,
    ) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '待删除卡片',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '民生银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final saveResult = await service.saveDraft(draft);
      expect(saveResult.success, isTrue);
      final itemId = saveResult.itemId!;

      // We need another item so we can inspect detail page after deleting the target one
      final secondDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '保留卡片',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '保留银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567891',
          ),
        ],
      );
      final secondResult = await service.saveDraft(secondDraft);
      expect(secondResult.success, isTrue);
      final secondItemId = secondResult.itemId!;

      // Load target detail page
      await tester.pumpWidget(buildDetailWidget(itemId));
      await tester.pumpAndSettle();

      // Trigger deletion BottomSheet via edit button bottom sheet
      final editButton = findAnchIcon(AnchIcons.more);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      // Tap "删除" option in the edit options bottom sheet
      await tester.tap(find.text('删除'));
      await tester.pumpAndSettle();

      // Tap confirm move-to-trash in BottomSheet
      await tester.tap(find.text('移入最近删除'));
      // Wait for delayed pop in DeleteRecordSheet
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();

      // Active list excludes the soft-deleted item, while its data remains restorable.
      final allItemsBefore = await itemRepo.getActiveItems();
      expect(allItemsBefore.length, equals(1));
      expect(allItemsBefore.first.id, equals(secondItemId));
      final deletedSnapshot = await itemRepo.getItemWithFields(itemId);
      expect(deletedSnapshot, isNotNull);
      expect(deletedSnapshot!.status, equals('deleted'));
      expect(deletedSnapshot.deletedAt, isNotNull);

      // Another item's detail must never show the target item's delete event.
      await tester.pumpWidget(buildDetailWidget(secondItemId));
      await tester.pumpAndSettle();

      // Expand trace section
      final actionTraceFinder = find.text('操作记录');
      await tester.ensureVisible(actionTraceFinder);
      await tester.tap(actionTraceFinder);
      await tester.pumpAndSettle();

      expect(find.text('移入最近删除'), findsNothing);

      final restoreResult = await service.restoreItem(deletedSnapshot);
      expect(restoreResult.success, isTrue);

      final allItemsAfter = await itemRepo.getActiveItems();
      expect(allItemsAfter.length, equals(2));
      expect(
        allItemsAfter.map((item) => item.id),
        containsAll([itemId, secondItemId]),
      );
      final restoredEvents = await di.itemEventRepo.getForItem(itemId);
      expect(
        restoredEvents.map((event) => event.eventType.name),
        containsAll(['created', 'movedToTrash', 'restored']),
      );
    });
  });

  group('资料操作历史安全差异', () {
    test('低敏日期保留新旧值，中高敏及普通文本只保留字段名称', () async {
      final itemId = await itemRepo.saveItemWithFields(
        SaveItemInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'property_certificate',
          title: '虚构产权资料甲',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'registration_date',
              valueType: FieldValueType.date,
              valueText: '2026-01-01',
            ),
            SaveItemFieldInput(
              fieldKey: 'certificate_number',
              valueType: FieldValueType.text,
              valueText: '虚构证号甲',
            ),
            SaveItemFieldInput(
              fieldKey: 'owner_name',
              valueType: FieldValueType.text,
              valueText: '虚构成员甲',
            ),
          ],
        ),
        recordUserEvent: true,
      );

      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: systemMeMemberId,
          categoryKey: 'other',
          typeKey: 'property_certificate',
          title: '虚构产权资料乙',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'registration_date',
              valueType: FieldValueType.date,
              valueText: '2027-02-02',
            ),
            SaveItemFieldInput(
              fieldKey: 'certificate_number',
              valueType: FieldValueType.text,
              valueText: '虚构证号乙',
            ),
            SaveItemFieldInput(
              fieldKey: 'owner_name',
              valueType: FieldValueType.text,
              valueText: '虚构成员乙',
            ),
          ],
        ),
        recordUserEvent: true,
      );

      final event = (await di.itemEventRepo.getForItem(itemId)).first;
      expect(event.eventType, ItemEventType.updated);
      final changes = {
        for (final change in event.changes) change.subjectKey: change,
      };
      expect(changes['registration_date']?.oldValue, '2026-01-01');
      expect(changes['registration_date']?.newValue, '2027-02-02');
      expect(
        changes['registration_date']?.changeKind,
        ItemEventChangeKind.valueChanged,
      );
      expect(changes['certificate_number']?.oldValue, isNull);
      expect(changes['certificate_number']?.newValue, isNull);
      expect(changes['owner_name']?.oldValue, isNull);
      expect(changes['owner_name']?.newValue, isNull);
      expect(changes['title']?.oldValue, isNull);
      expect(changes['member_id']?.oldValue, '家庭');
      expect(changes['member_id']?.newValue, '我');
      expect(
        event.changes.any(
          (change) =>
              change.oldValue == '虚构证号甲' ||
              change.newValue == '虚构证号乙' ||
              change.oldValue == '虚构成员甲' ||
              change.newValue == '虚构成员乙',
        ),
        isFalse,
      );
    });

    test('内容未变化时不追加虚假的更新事件', () async {
      final input = SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '虚构卡片甲',
        fields: [
          SaveItemFieldInput(
            fieldKey: 'bank_name',
            valueType: FieldValueType.text,
            valueText: '虚构银行甲',
          ),
        ],
      );
      final itemId = await itemRepo.saveItemWithFields(
        input,
        recordUserEvent: true,
      );
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: input.memberId,
          categoryKey: input.categoryKey,
          typeKey: input.typeKey,
          title: input.title,
          fields: input.fields,
        ),
        recordUserEvent: true,
      );
      final events = await di.itemEventRepo.getForItem(itemId);
      expect(events.map((event) => event.eventType), [ItemEventType.created]);
    });

    test('附件历史只记录添加和移除数量', () async {
      const itemId = 'fictional-attachment-item';
      SaveAttachmentInput attachment(String id, String fileName, int order) {
        return SaveAttachmentInput(
          id: id,
          itemId: itemId,
          attachmentRole: 'other',
          fileName: fileName,
          originalName: '虚构附件',
          mimeType: 'application/octet-stream',
          plainSize: 10,
          encryptedSize: 20,
          sortOrder: order,
        );
      }

      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          title: '虚构附件资料',
          fields: const [],
          attachments: [attachment('attachment-a', 'fictional-a.enc', 0)],
        ),
        recordUserEvent: true,
      );
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: itemId,
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          title: '虚构附件资料',
          fields: const [],
          attachments: [
            attachment('attachment-b', 'fictional-b.enc', 0),
            attachment('attachment-c', 'fictional-c.enc', 1),
          ],
        ),
        recordUserEvent: true,
      );

      final change = (await di.itemEventRepo.getForItem(
        itemId,
      )).first.changes.single;
      expect(change.changeKind, ItemEventChangeKind.attachmentCountChanged);
      expect(change.oldValue, '1');
      expect(change.newValue, '2');
      expect(change.subjectLabel, '附件');
      expect(change.oldValue, isNot(contains('fictional-a')));
      expect(change.newValue, isNot(contains('fictional-b')));
    });
  });
}

/// 测试专用根页面：在 [initState] 中注册一次 postFrameCallback，
/// 仅推入一次 [ItemDetailPage]，避免 Builder.build 多次调用导致
/// 删除弹出后二次 push 的问题。
class _DetailTestRoot extends StatefulWidget {
  final String itemId;
  const _DetailTestRoot({super.key, required this.itemId});

  @override
  State<_DetailTestRoot> createState() => _DetailTestRootState();
}

class _DetailTestRootState extends State<_DetailTestRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ItemDetailPage(itemId: widget.itemId),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Root Page')));
  }
}
