// ignore_for_file: avoid_print
@Timeout(Duration(minutes: 10))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/migration_dto.dart';
import 'package:anch/core/template/migration_service.dart';
import '../tool/migration_orchestrator.dart';

void main() {
  try {
    group('FIELD Schema Scaling and Complexity Analysis', () {
      test('Execute Scaling Benchmarks (100 -> 50k)', () async {
        await runScalingBenchmarks();
      });
    });
  } catch (e) {
    runScalingBenchmarks();
  }
}

Future<void> runScalingBenchmarks() async {
  final sizes = [100, 1000, 10000, 50000];
  final results = <int, Map<String, int>>{};

  print('=== [START] FIELD Schema Scaling Analysis Benchmarks ===');
  print('Warm-up phases will be executed at the beginning of each size test.');

  for (final size in sizes) {
    print('\n--- Seeding and testing size: $size ---');
    final opener = NativeAppDatabaseOpener(inMemory: true);
    final db = AppDatabase.fromOpener(opener);
    final itemRepo = ItemRepository(db);

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.batch((b) {
        for (int i = 0; i < size; i++) {
          final itemId = 'legacy_item_${size}_$i';
          b.insert(
            db.items,
            ItemsCompanion.insert(
              id: itemId,
              originId: itemId,
              memberId: Value(systemFamilyMemberId),
              categoryKey: const Value('card'),
              typeKey: const Value('debit_card'),
              templateVersion: const Value(1),
              title: Value('Outdated Card $i'),
              createdAt: now,
              updatedAt: now,
              sortOrder: const Value(0),
              status: const Value('active'),
            ),
          );
          b.insert(
            db.itemFields,
            ItemFieldsCompanion.insert(
              id: 'field_bank_${size}_$i',
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
              id: 'field_account_${size}_$i',
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
              id: 'field_card_${size}_$i',
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

    // Warm-up
    for (int i = 0; i < 15; i++) {
      await MigrationOrchestrator.scanInconsistentData(itemRepo);
    }
    final warmupFields = [
      const MigrationFieldInput(fieldKey: 'bank_name', valueText: '  建设银行  '),
      const MigrationFieldInput(fieldKey: 'card_number', valueText: '6222021234567890123'),
      const MigrationFieldInput(fieldKey: 'account_name', valueText: '测试账户'),
    ];
    for (int i = 0; i < 15; i++) {
      MigrationService.migrateFields(warmupFields);
    }
    for (int i = 0; i < 15; i++) {
      final warmupInput = SaveItemInput(
        id: 'warmup_${size}_$i',
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1,
        title: 'Warmup Card',
        fields: [
          SaveItemFieldInput(fieldKey: 'bank_name', valueType: FieldValueType.text, valueText: '  建设银行  ', sortOrder: 0),
          SaveItemFieldInput(fieldKey: 'card_number', valueType: FieldValueType.bankCardNumber, valueText: '6222021234567890123', sortOrder: 1),
          SaveItemFieldInput(fieldKey: 'account_name', valueType: FieldValueType.sensitiveText, valueText: '测试账户', sortOrder: 2),
        ],
      );
      await itemRepo.saveItemWithFields(warmupInput);
    }

    // 1. Scan-Only Benchmark (DB read)
    final stopwatchScan = Stopwatch()..start();
    final outdatedItems = await MigrationOrchestrator.scanInconsistentData(itemRepo);
    stopwatchScan.stop();
    final scanMs = stopwatchScan.elapsedMilliseconds;

    // 2. Migrate-Only Benchmark (Isolate Value Transformation)
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
    final List<MigrationIsolateItemOutput> migratedOutputs = await MigrationIsolateRunner.run(isolateInput);
    stopwatchMigrate.stop();
    final migrateMs = stopwatchMigrate.elapsedMilliseconds;

    // 3. Write-Only Benchmark (Chunked DB Batch persistence)
    final outputsMap = {
      for (final out in migratedOutputs) out.id: out
    };

    final List<SaveItemInput> saveInputs = [];
    for (int i = 0; i < outdatedItems.length; i++) {
      final item = outdatedItems[i];
      final out = outputsMap[item.id]!;
      final repoFields = <SaveItemFieldInput>[];
      for (var j = 0; j < out.fields.length; j++) {
        final f = out.fields[j];
        repoFields.add(SaveItemFieldInput(
          fieldKey: f.fieldKey,
          valueType: f.fieldKey == 'card_number'
              ? FieldValueType.bankCardNumber
              : (f.fieldKey == 'account_name' ? FieldValueType.sensitiveText : FieldValueType.text),
          valueText: f.valueText,
          normalizedValue: f.fieldKey == 'card_number' ? '0123' : null,
          sortOrder: j,
        ));
      }
      saveInputs.add(SaveItemInput(
        id: item.id,
        memberId: item.memberId,
        categoryKey: item.categoryKey,
        typeKey: item.typeKey,
        templateVersion: 2,
        title: 'Repaired Card $i',
        fields: repoFields,
      ));
    }

    final stopwatchWrite = Stopwatch()..start();
    await itemRepo.saveItemsInBatch(saveInputs);
    stopwatchWrite.stop();
    final writeMs = stopwatchWrite.elapsedMilliseconds;

    results[size] = {
      'scan': scanMs,
      'migrate': migrateMs,
      'write': writeMs,
    };

    print('Size $size timings: Scan: $scanMs ms | Migrate: $migrateMs ms | Write: $writeMs ms');

    await db.close();
  }

  print('\n=== FIELD SCHEMA SCALING ANALYSIS REPORT ===');
  
  final baseSize = 100;
  final baseTimings = results[baseSize]!;

  print('| Workload | Size | Time (ms) | Per-Item Cost (ms) | Growth Ratio | Complexity Indicator |');
  print('|---|---|---|---|---|---|');

  for (final size in sizes) {
    final timings = results[size]!;
    for (final phase in ['scan', 'migrate', 'write']) {
      final ms = timings[phase]!;
      final baseMs = baseTimings[phase]!;

      final perItem = ms / size;
      final basePerItem = baseMs / baseSize;

      final ratio = basePerItem == 0 ? 0.0 : perItem / basePerItem;
      
      String complexity = 'O(N)';
      if (ratio > 1.3) {
        complexity = 'O(N log N) / O(N²)';
      } else if (ratio < 0.8) {
        complexity = 'Sublinear';
      }

      print('| ${phase.toUpperCase()} | $size | $ms | ${perItem.toStringAsFixed(5)} | ${ratio.toStringAsFixed(3)} | $complexity |');
    }
  }

  print('\n=== [END] FIELD Schema Scaling Analysis Benchmarks ===');
}
