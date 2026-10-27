import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/models/item_event_model.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/service/insurance_renewal_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DependencyProvider dependencies;

  setUp(() {
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
  });

  tearDown(() => db.close());

  test('归档排除默认查询，取消置顶且使用明确事件', () async {
    final id = await dependencies.itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        title: '虚构归档资料',
        searchText: '虚构归档关键词',
        isPinned: true,
        fields: const [],
      ),
      recordUserEvent: true,
    );

    expect(
      (await dependencies.itemUseCaseService.archiveItem(id)).success,
      isTrue,
    );
    expect(await dependencies.itemRepo.getActiveItems(), isEmpty);
    expect(await dependencies.itemRepo.searchItems('虚构归档关键词'), isEmpty);
    final archived = await dependencies.itemRepo.getArchivedItems();
    expect(archived.single.id, id);
    expect(archived.single.isPinned, isFalse);
    expect(
      (await dependencies.itemEventRepo.getForItem(
        id,
      )).map((event) => event.eventType),
      contains(ItemEventType.archived),
    );

    expect(
      (await dependencies.itemUseCaseService.unarchiveItem(id)).success,
      isTrue,
    );
    final restored = (await dependencies.itemRepo.getActiveItems()).single;
    expect(restored.isPinned, isFalse);
    expect(
      (await dependencies.itemEventRepo.getForItem(
        id,
      )).map((event) => event.eventType),
      contains(ItemEventType.unarchived),
    );
  });

  test('归档资料移入最近删除后恢复到归档状态', () async {
    final id = await dependencies.itemRepo.saveItemWithFields(
      SaveItemInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        title: '虚构归档删除资料',
        fields: const [],
      ),
      recordUserEvent: true,
    );
    await dependencies.itemUseCaseService.archiveItem(id);
    expect(
      (await dependencies.itemUseCaseService.deleteItem(id)).success,
      isTrue,
    );
    final deleted = await dependencies.itemRepo.getItemWithFields(id);
    expect(deleted?.status, 'deleted');
    expect(deleted?.statusBeforeDeletion, 'archived');

    expect(
      (await dependencies.itemUseCaseService.restoreItem(deleted!)).success,
      isTrue,
    );
    final restored = await dependencies.itemRepo.getItemWithFields(id);
    expect(restored?.status, 'archived');
    expect(restored?.statusBeforeDeletion, isNull);
  });

  test('续保草稿只复制白名单字段和归属，不复制其他状态', () async {
    final result = await dependencies.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'insurance',
        typeKey: 'insurance',
        note: '不应复制的虚构备注',
        isPinned: true,
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'insurance_company',
            valueText: '虚构保险公司',
          ),
          ItemFieldDraftInput(fieldKey: 'policy_name', valueText: '虚构保单'),
          ItemFieldDraftInput(
            fieldKey: 'policy_number',
            valueText: 'TEST-POLICY-OLD',
          ),
          ItemFieldDraftInput(fieldKey: 'insurance_type', valueText: '虚构险种'),
          ItemFieldDraftInput(fieldKey: 'applicant', valueText: '虚构投保人'),
          ItemFieldDraftInput(fieldKey: 'insured_person', valueText: '虚构被保险人'),
          ItemFieldDraftInput(fieldKey: 'start_date', valueText: '2025-01-01'),
          ItemFieldDraftInput(fieldKey: 'end_date', valueText: '2026-01-01'),
          ItemFieldDraftInput(fieldKey: 'premium', valueText: '100'),
          ItemFieldDraftInput(fieldKey: 'coverage_amount', valueText: '10000'),
          ItemFieldDraftInput(
            fieldKey: 'service_phone',
            valueText: '400-000-0000',
          ),
        ],
      ),
    );
    final source = await dependencies.itemRepo.getItemWithFields(
      result.itemId!,
    );
    final draft = InsuranceRenewalService.createDraft(source!);
    final values = {
      for (final field in draft.fields) field.fieldKey: field.valueText,
    };

    expect(draft.id, isNull);
    expect(draft.memberId, source.memberId);
    expect(draft.note, isNull);
    expect(draft.isPinned, isFalse);
    expect(draft.attachments, isEmpty);
    expect(values.keys, InsuranceRenewalService.copiedFieldKeys);
    expect(values, isNot(contains('policy_number')));
    expect(values, isNot(contains('start_date')));
    expect(values, isNot(contains('end_date')));
    expect(values, isNot(contains('premium')));
    expect(values, isNot(contains('coverage_amount')));
  });
}
