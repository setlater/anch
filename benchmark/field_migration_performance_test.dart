// ignore_for_file: avoid_print
@Timeout(Duration(minutes: 5))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/template/field_definition.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/migration_dto.dart';
import 'package:anch/core/template/migration_service.dart';
import '../tool/migration_orchestrator.dart';

void main() {
  late AppDatabase db;
  late ItemRepository itemRepo;

  setUp(() async {
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    itemRepo = ItemRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> populateDatabaseWithOutdatedItems(int count) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.delete(db.items).go();
    await db.transaction(() async {
      await db.batch((b) {
        for (int i = 0; i < count; i++) {
          final itemId = 'legacy_item_$i';
          b.insert(
            db.items,
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: Value(systemFamilyMemberId),
              categoryKey: const Value('card'),
              typeKey: const Value('debit_card'),
              templateVersion: const Value(1),
              title: Value('Outdated Debit Card $i'),
              createdAt: now,
              updatedAt: now,
              sortOrder: const Value(0),
              status: const Value('active'),
            ),
          );
          b.insert(
            db.itemFields,
            ItemFieldsCompanion.insert(
              id: 'field_bank_$i',
              itemId: itemId,
              fieldKey: 'bank_name',
              valueType: 'text',
              valueText: const Value('  建设银行  '),
              createdAt: now,
              updatedAt: now,
              sortOrder: const Value(0),
            ),
          );
          b.insert(
            db.itemFields,
            ItemFieldsCompanion.insert(
              id: 'field_account_$i',
              itemId: itemId,
              fieldKey: 'account_name',
              valueType: 'sensitiveText',
              valueText: const Value('测试账户'),
              createdAt: now,
              updatedAt: now,
              sortOrder: const Value(1),
            ),
          );
          b.insert(
            db.itemFields,
            ItemFieldsCompanion.insert(
              id: 'field_card_$i',
              itemId: itemId,
              fieldKey: 'card_number',
              valueType: 'bankCardNumber',
              valueText: const Value('6222021234567890123'),
              createdAt: now,
              updatedAt: now,
              sortOrder: const Value(2),
            ),
          );
        }
      });
    });
  }

  Future<void> performWarmup() async {
    final tempOpener = NativeAppDatabaseOpener(inMemory: true);
    final tempDb = AppDatabase.fromOpener(tempOpener);
    final tempItemRepo = ItemRepository(tempDb);

    for (int i = 0; i < 15; i++) {
      await MigrationOrchestrator.scanInconsistentData(tempItemRepo);
    }

    final mockFields = [
      const MigrationFieldInput(fieldKey: 'bank_name', valueText: '  招商银行  '),
      const MigrationFieldInput(fieldKey: 'card_number', valueText: '6225881234567890'),
      const MigrationFieldInput(fieldKey: 'account_name', valueText: '测试账户'),
    ];
    for (int i = 0; i < 15; i++) {
      MigrationService.migrateFields(mockFields);
    }

    for (int i = 0; i < 15; i++) {
      final input = SaveItemInput(
        id: 'warmup_item_$i',
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1,
        title: 'Warmup Card $i',
        fields: [
          SaveItemFieldInput(fieldKey: 'bank_name', valueType: FieldValueType.text, valueText: '  建设银行  ', sortOrder: 0),
          SaveItemFieldInput(fieldKey: 'card_number', valueType: FieldValueType.bankCardNumber, valueText: '6222021234567890123', sortOrder: 1),
          SaveItemFieldInput(fieldKey: 'account_name', valueType: FieldValueType.sensitiveText, valueText: '测试账户', sortOrder: 2),
        ],
      );
      await tempItemRepo.saveItemWithFields(input);
    }

    await tempDb.close();
  }

  group('FIELD System Decoupled Performance Benchmarks (N=1000)', () {
    test('Execute Baseline Split-Phase Benchmarks', () async {
      const int targetCount = 1000;
      
      print('=== [START] Baseline Performance Benchmarks (N=$targetCount) ===');

      await populateDatabaseWithOutdatedItems(targetCount);
      print('Database seeded with $targetCount outdated items.');

      await performWarmup();
      print('Warm-up phase completed successfully.');

      // 1. Scan-Only Benchmark (DB read)
      final stopwatchScan = Stopwatch()..start();
      final outdatedItems = await MigrationOrchestrator.scanInconsistentData(itemRepo);
      stopwatchScan.stop();
      print('Scan-Only (DB read): ${stopwatchScan.elapsedMilliseconds} ms');
      expect(outdatedItems.length, equals(targetCount));

      // 2. Migrate-Only Benchmark (Pure Memory DTO value transformation on Isolate runner)
      final isolateItemInputs = outdatedItems.map((item) {
        return MigrationIsolateItemInput(
          id: item.id,
          typeKey: item.typeKey!,
          fields: item.fields.map((f) => MigrationFieldInput(
            fieldKey: f.fieldKey,
            valueText: f.valueText,
            fieldNote: f.fieldNote,
          )).toList(),
        );
      }).toList();

      final isolateInput = MigrationIsolateInput(items: isolateItemInputs);

      final stopwatchMigrate = Stopwatch()..start();
      // Runs value transformation
      final List<MigrationIsolateItemOutput> migratedOutputs = await MigrationIsolateRunner.run(isolateInput);
      stopwatchMigrate.stop();
      print('Migrate-Only (Isolate Stateless DTO Conversion): ${stopwatchMigrate.elapsedMilliseconds} ms');
      expect(migratedOutputs.length, equals(targetCount));

      final outputsMap = {
        for (final out in migratedOutputs) out.id: out
      };

      // 3. Builder-Only Benchmark (Main Isolate CPU Text Generation)
      final typeDefLatest = TemplateRegistry.getTemplate('debit_card')!;
      final memberName = '家庭';
      final categoryLabel = '卡片资料';

      final stopwatchBuilder = Stopwatch()..start();
      final List<SaveItemInput> saveInputs = [];
      for (final item in outdatedItems) {
        final out = outputsMap[item.id]!;
        
        final draft = ItemDraftInput(
          id: item.id,
          memberId: item.memberId,
          categoryKey: item.categoryKey,
          typeKey: item.typeKey,
          templateVersion: typeDefLatest.version,
          title: item.title,
          fields: out.fields.map((o) => ItemFieldDraftInput(
            fieldKey: o.fieldKey,
            valueText: o.valueText,
            fieldNote: o.fieldNote,
          )).toList(),
        );

        final normalizedValues = <String, String?>{};
        for (final inputField in draft.fields) {
          final FieldDefinition? fieldDef = typeDefLatest.fields.any((f) => f.fieldKey == inputField.fieldKey)
              ? typeDefLatest.fields.firstWhere((f) => f.fieldKey == inputField.fieldKey)
              : null;
          if (fieldDef == null) continue;
          
          normalizedValues[inputField.fieldKey] = SensitiveFieldGuard.normalizeSensitiveField(
            fieldKey: inputField.fieldKey,
            valueText: inputField.valueText,
            level: fieldDef.sensitiveLevel,
          );
        }

        final title = TitleSummaryBuilder.buildTitle(
          draft: draft,
          typeDef: typeDefLatest,
          memberName: memberName,
        );

        final primaryText = TitleSummaryBuilder.buildPrimaryText(
          draft: draft,
          typeDef: typeDefLatest,
          title: title,
        );

        final secondaryText = TitleSummaryBuilder.buildSecondaryText(
          draft: draft,
          typeDef: typeDefLatest,
          primaryVal: primaryText,
        );

        final summaryText = TitleSummaryBuilder.buildSummaryText(
          draft: draft,
          typeDef: typeDefLatest,
        );

        final searchText = SearchTextBuilder.buildSearchText(
          title: title,
          typeDef: typeDefLatest,
          categoryLabel: categoryLabel,
          fields: draft.fields,
          normalizedValues: normalizedValues,
        );

        final repoFields = <SaveItemFieldInput>[];
        for (var i = 0; i < draft.fields.length; i++) {
          final inputField = draft.fields[i];
          final FieldDefinition? fieldDef = typeDefLatest.fields.any((f) => f.fieldKey == inputField.fieldKey)
              ? typeDefLatest.fields.firstWhere((f) => f.fieldKey == inputField.fieldKey)
              : null;

          final int sortOrder = fieldDef == null 
              ? i 
              : typeDefLatest.fields.indexWhere((f) => f.fieldKey == inputField.fieldKey);

          repoFields.add(
            SaveItemFieldInput(
              fieldKey: inputField.fieldKey,
              valueType: fieldDef?.valueType ?? FieldValueType.text,
              valueText: inputField.valueText,
              normalizedValue: normalizedValues[inputField.fieldKey],
              fieldNote: inputField.fieldNote,
              sortOrder: sortOrder == -1 ? i : sortOrder,
            ),
          );
        }

        saveInputs.add(SaveItemInput(
          id: draft.id,
          memberId: draft.memberId,
          categoryKey: draft.categoryKey,
          typeKey: draft.typeKey,
          templateVersion: draft.templateVersion,
          title: title,
          primaryText: primaryText,
          secondaryText: secondaryText,
          summaryText: summaryText,
          searchText: searchText,
          fields: repoFields,
        ));
      }
      stopwatchBuilder.stop();
      print('Builder-Only (Main Isolate CPU Text Generation): ${stopwatchBuilder.elapsedMilliseconds} ms');
      expect(saveInputs.length, equals(targetCount));

      // 4. Write-Only (Individual Transactions Loop - Before Optimization)
      final stopwatchWriteBefore = Stopwatch()..start();
      for (final saveInput in saveInputs) {
        await itemRepo.saveItemWithFields(saveInput);
      }
      stopwatchWriteBefore.stop();
      print('Write-Only BEFORE (Individual Transaction Loop): ${stopwatchWriteBefore.elapsedMilliseconds} ms');

      // 5. Write-Only (Chunked Batch Transaction - After Optimization)
      // Reset items in DB to outdated version first
      await populateDatabaseWithOutdatedItems(targetCount);
      
      final stopwatchWriteAfter = Stopwatch()..start();
      await itemRepo.saveItemsInBatch(saveInputs);
      stopwatchWriteAfter.stop();
      print('Write-Only AFTER (Chunked Batch Transaction): ${stopwatchWriteAfter.elapsedMilliseconds} ms');

      print('=== [END] Baseline Performance Benchmarks ===');
    });
  });
}
