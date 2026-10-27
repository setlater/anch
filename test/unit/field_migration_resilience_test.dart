import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/migration_checkpoint.dart';
import 'package:anch/core/template/migration_failure_log.dart';
import 'package:anch/core/template/migration_state_store.dart';
import '../../tool/migration_orchestrator.dart';

class ThrowingItemRepository extends ItemRepository {
  int saveBatchCallCount = 0;
  bool shouldThrow = true;
  bool shouldThrowOnlyFirstTime = false;

  ThrowingItemRepository(super.db);

  @override
  Future<void> saveItemsInBatch(List<SaveItemInput> inputs) async {
    saveBatchCallCount++;
    if (shouldThrow) {
      if (shouldThrowOnlyFirstTime) {
        shouldThrow = false;
      }
      throw Exception('Database write failure');
    }
    await super.saveItemsInBatch(inputs);
  }
}

class CustomBatchRepo extends ItemRepository {
  final void Function(List<SaveItemInput> inputs) onSaveBatch;

  CustomBatchRepo(super.db, this.onSaveBatch);

  @override
  Future<void> saveItemsInBatch(List<SaveItemInput> inputs) async {
    onSaveBatch(inputs);
    await super.saveItemsInBatch(inputs);
  }
}

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late Directory tempDir;
  late MigrationStateStore stateStore;

  setUp(() {
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);

    tempDir = Directory.systemTemp.createTempSync('field_migration_resilience_test');
    stateStore = MigrationStateStore(baseDirectory: tempDir);
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<void> saveLegacyItem(ItemRepository repo, String id, String bankName) async {
    final oldInput = SaveItemInput(
      id: id,
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      templateVersion: 1,
      title: 'Legacy Card $id',
      fields: [
        SaveItemFieldInput(
          fieldKey: 'bank_name',
          valueType: FieldValueType.text,
          valueText: bankName,
          sortOrder: 0,
        ),
        SaveItemFieldInput(
          fieldKey: 'card_number',
          valueType: FieldValueType.bankCardNumber,
          valueText: '6222021234567890123',
          sortOrder: 1,
        ),
      ],
    );
    await repo.saveItemWithFields(oldInput);
  }

  group('Migration Checkpoint & Failure Log Persistence tests', () {
    test('Checkpoint save/load and clear correctness', () async {
      final checkpoint = MigrationCheckpoint(
        lastProcessedOffset: 500,
        totalItems: 1500,
        migratedCount: 480,
        failedCount: 20,
        batchSize: 500,
        status: 'running',
      );

      await stateStore.saveMigrationCheckpoint(checkpoint);

      final loaded = await stateStore.getMigrationCheckpoint();
      expect(loaded, isNotNull);
      expect(loaded!.lastProcessedOffset, equals(500));
      expect(loaded.totalItems, equals(1500));
      expect(loaded.migratedCount, equals(480));
      expect(loaded.failedCount, equals(20));
      expect(loaded.batchSize, equals(500));
      expect(loaded.status, equals('running'));

      final newCheckpoint = MigrationCheckpoint(
        lastProcessedOffset: 1000,
        totalItems: 1500,
        migratedCount: 960,
        failedCount: 40,
        batchSize: 500,
        status: 'running',
      );
      await stateStore.saveMigrationCheckpoint(newCheckpoint);
      final reloaded = await stateStore.getMigrationCheckpoint();
      expect(reloaded!.lastProcessedOffset, equals(1000));

      await stateStore.clearMigrationCheckpoint();
      final cleared = await stateStore.getMigrationCheckpoint();
      expect(cleared, isNull);
    });

    test('Failure Log persists only anonymized diagnostics', () async {
      final log1 = MigrationFailureLog(
        errorType: 'PreProcessingError',
        timestamp: 1234567,
      );
      final log2 = MigrationFailureLog(
        errorType: 'Stage2Error',
        timestamp: 1234568,
      );

      await stateStore.saveFailureLog(log1);
      await stateStore.saveFailureLog(log2);

      final logs = await stateStore.getFailureLogs();
      expect(logs.length, equals(2));
      expect(logs[0].errorType, equals('PreProcessingError'));
      expect(logs[0].timestamp, equals(1234567));

      expect(logs[1].errorType, equals('Stage2Error'));
      expect(logs[1].timestamp, equals(1234568));

      final persisted = await File(
        '${tempDir.path}/${MigrationStateStore.failureLogFileName}',
      ).readAsString();
      expect(persisted, isNot(contains('itemId')));
      expect(persisted, isNot(contains('stackTrace')));

      await stateStore.clearMigrationFailureLogs();
      final cleared = await stateStore.getFailureLogs();
      expect(cleared, isEmpty);
    });
  });

  group('Migration Orchestrator Resilience & Recovery Tests', () {
    test('Resume from mid-migration offset', () async {
      // 1. Seed 8 legacy items (version 1)
      for (int i = 1; i <= 8; i++) {
        await saveLegacyItem(itemRepo, 'item_$i', '  Bank $i  ');
      }

      // 2. Pre-create checkpoint indicating offset 5 is already processed
      final checkpoint = MigrationCheckpoint(
        lastProcessedOffset: 5,
        totalItems: 8,
        migratedCount: 5,
        failedCount: 0,
        batchSize: 5,
        status: 'running',
      );
      await stateStore.saveMigrationCheckpoint(checkpoint);

      // 3. Run migrateAll
      await MigrationOrchestrator.migrateAll(
        itemRepo: itemRepo,
        memberRepo: memberRepo,
        stateStore: stateStore,
        batchSize: 5,
      );

      // 4. Verify checkpoint is cleared on successful completion
      final activeCheckpoint = await stateStore.getMigrationCheckpoint();
      expect(activeCheckpoint, isNull);

      // 5. Verify database state
      // Items 1-5 must NOT be migrated (still version 1, bank name still has spaces)
      for (int i = 1; i <= 5; i++) {
        final item = await itemRepo.getItemWithFields('item_$i');
        expect(item, isNotNull);
        expect(item!.templateVersion, equals(1));
        final bankField = item.fields.firstWhere((f) => f.fieldKey == 'bank_name');
        expect(bankField.valueText, equals('  Bank $i  '));
      }

      // Items 6-8 MUST be migrated (version 2, bank name cleaned)
      for (int i = 6; i <= 8; i++) {
        final item = await itemRepo.getItemWithFields('item_$i');
        expect(item, isNotNull);
        expect(item!.templateVersion, equals(2));
        final bankField = item.fields.firstWhere((f) => f.fieldKey == 'bank_name');
        expect(bankField.valueText, equals('Bank $i'));
      }
    });

    test('Failure isolation - single item failure does not stop batch', () async {
      // 1. Seed 3 legacy items, item_2 has an invalid template typeKey causing failure
      await saveLegacyItem(itemRepo, 'item_1', '  Bank 1  ');

      final invalidInput = SaveItemInput(
        id: 'item_2',
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'non_existent_card_template_type',
        templateVersion: 1,
        title: 'Invalid Legacy Card',
        fields: [
          SaveItemFieldInput(
            fieldKey: 'bank_name',
            valueType: FieldValueType.text,
            valueText: '  Bank 2  ',
            sortOrder: 0,
          ),
        ],
      );
      await itemRepo.saveItemWithFields(invalidInput);

      await saveLegacyItem(itemRepo, 'item_3', '  Bank 3  ');

      // 2. Fetch items and call repairLegacyData
      final items = [
        await itemRepo.getItemWithFields('item_1'),
        await itemRepo.getItemWithFields('item_2'),
        await itemRepo.getItemWithFields('item_3'),
      ].whereType<ItemWithFields>().toList();

      final result = await MigrationOrchestrator.repairLegacyData(
        itemRepo: itemRepo,
        memberRepo: memberRepo,
        items: items,
        stateStore: stateStore,
      );

      // 3. Verify counts
      expect(result.migratedCount, equals(2));
      expect(result.failedCount, equals(1));

      // 4. Verify database state
      final res1 = await itemRepo.getItemWithFields('item_1');
      expect(res1!.templateVersion, equals(2));

      final res2 = await itemRepo.getItemWithFields('item_2');
      expect(res2!.templateVersion, equals(1)); // Skipped

      final res3 = await itemRepo.getItemWithFields('item_3');
      expect(res3!.templateVersion, equals(2));

      // 5. Verify failure logs
      final logs = await stateStore.getFailureLogs();
      expect(logs.length, equals(1));
      expect(logs[0].errorType, equals('PreProcessingError'));
    });

    test('Retry policy for failed chunks - persistent failure aborts', () async {
      await saveLegacyItem(itemRepo, 'item_1', '  Bank 1  ');

      final throwingRepo = ThrowingItemRepository(db)..shouldThrow = true;
      final items = [await itemRepo.getItemWithFields('item_1')].whereType<ItemWithFields>().toList();

      await expectLater(
        () => MigrationOrchestrator.repairLegacyData(
          itemRepo: throwingRepo,
          memberRepo: memberRepo,
          items: items,
          stateStore: stateStore,
        ),
        throwsA(isA<Exception>()),
      );

      // Verify called twice (1 original + 1 retry)
      expect(throwingRepo.saveBatchCallCount, equals(2));
    });

    test('Retry policy for failed chunks - transient failure succeeds on retry', () async {
      await saveLegacyItem(itemRepo, 'item_1', '  Bank 1  ');

      final throwingRepo = ThrowingItemRepository(db)
        ..shouldThrow = true
        ..shouldThrowOnlyFirstTime = true;

      final items = [await itemRepo.getItemWithFields('item_1')].whereType<ItemWithFields>().toList();

      final result = await MigrationOrchestrator.repairLegacyData(
        itemRepo: throwingRepo,
        memberRepo: memberRepo,
        items: items,
        stateStore: stateStore,
      );

      expect(result.migratedCount, equals(1));
      expect(throwingRepo.saveBatchCallCount, equals(2));

      final res = await itemRepo.getItemWithFields('item_1');
      expect(res!.templateVersion, equals(2));
    });

    test('Full migration completion with resume simulation', () async {
      // 1. Seed 6 legacy items
      for (int i = 1; i <= 6; i++) {
        await saveLegacyItem(itemRepo, 'item_$i', '  Bank $i  ');
      }

      int saveCallCount = 0;
      final customRepo = CustomBatchRepo(db, (inputs) {
        saveCallCount++;
        if (saveCallCount >= 2) {
          throw Exception('Simulated crash during batch 2');
        }
      });

      // 2. Start migration with batch size = 2.
      // Expected:
      // Batch 1 (items 1-2) succeeds. Checkpoint saved with offset = 2, status = running.
      // Batch 2 (items 3-4) fails. Checkpoint saved with offset = 2, status = failed.
      await expectLater(
        () => MigrationOrchestrator.migrateAll(
          itemRepo: customRepo,
          memberRepo: memberRepo,
          stateStore: stateStore,
          batchSize: 2,
        ),
        throwsA(isA<Exception>()),
      );

      // Check checkpoint state is retained as failed
      final checkpointAfterCrash = await stateStore.getMigrationCheckpoint();
      expect(checkpointAfterCrash, isNotNull);
      expect(checkpointAfterCrash!.lastProcessedOffset, equals(2));
      expect(checkpointAfterCrash.status, equals('failed'));

      // 3. Resume migration with normal repo (or reset failure condition)
      await MigrationOrchestrator.migrateAll(
        itemRepo: itemRepo, // normal repository that won't crash
        memberRepo: memberRepo,
        stateStore: stateStore,
        batchSize: 2,
      );

      // Check checkpoint cleared
      final checkpointAfterSuccess = await stateStore.getMigrationCheckpoint();
      expect(checkpointAfterSuccess, isNull);

      // Verify all 6 items are successfully migrated
      for (int i = 1; i <= 6; i++) {
        final item = await itemRepo.getItemWithFields('item_$i');
        expect(item, isNotNull);
        expect(item!.templateVersion, equals(2));
        final bankField = item.fields.firstWhere((f) => f.fieldKey == 'bank_name');
        expect(bankField.valueText, equals('Bank $i'));
      }
    });
  });
}
