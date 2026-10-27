// 仅供隔离虚构资料的测试与基准调用，不接入应用或真实资料迁移。
import 'dart:isolate';
import 'dart:math';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/builder/item_text_builder.dart';
import 'package:anch/core/template/migration_dto.dart';
import 'package:anch/core/template/migration_service.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/core/template/field_definition.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'package:anch/core/template/migration_checkpoint.dart';
import 'package:anch/core/template/migration_failure_log.dart';
import 'package:anch/core/template/migration_state_store.dart';

/// Worker responsible strictly for executing the stateless value transformation on a background Isolate (Stage 1).
class MigrationIsolateRunner {
  /// Entry point running in the spawned Isolate.
  /// It executes only stateless field-to-field value transformations (Stage 1).
  static Future<List<MigrationIsolateItemOutput>> run(
    MigrationIsolateInput input,
  ) async {
    return Isolate.run(() {
      final outputs = <MigrationIsolateItemOutput>[];
      for (final item in input.items) {
        final migratedFields = MigrationService.migrateFields(item.fields);
        outputs.add(
          MigrationIsolateItemOutput(id: item.id, fields: migratedFields),
        );
      }
      return outputs;
    });
  }
}

/// Result returned from a single chunk migration execution.
class MigrationChunkResult {
  final int migratedCount;
  final int failedCount;

  MigrationChunkResult({
    required this.migratedCount,
    required this.failedCount,
  });
}

/// Orchestrator responsible for managing the batch migration pipeline.
/// It implements:
/// 1. Paged Streaming Scan
/// 2. Pre-Processing (Main Isolate)
/// 3. Isolate Value Transformation (Stage 1, Background Isolate)
/// 4. Domain Builder & Normalization Processing (Stage 2, Main Isolate)
/// 5. Chunk-based SQLite Transactions (Chunk Size = 300 to 500)
class MigrationOrchestrator {
  /// Scans all stored items using paginated streaming to keep memory footprint at O(batch)
  static Future<List<ItemWithFields>> scanInconsistentData(
    ItemRepository itemRepo,
  ) async {
    final inconsistent = <ItemWithFields>[];
    int offset = 0;
    const int batchSize = 500;
    while (true) {
      final batch = await itemRepo.getItemsWithFieldsPaged(batchSize, offset);
      if (batch.isEmpty) break;
      for (final item in batch) {
        if (item.typeKey == null) continue;
        final latest = TemplateRegistry.getTemplate(item.typeKey!);
        final storedTemplate = TemplateRegistry.getTemplate(
          item.typeKey!,
          item.templateVersion,
        );
        if (latest != null &&
            item.templateVersion < latest.version &&
            storedTemplate?.supportsLegacyEditing != true) {
          inconsistent.add(item);
        }
      }
      offset += batchSize;
    }
    return inconsistent;
  }

  /// Migrates outdated items using the Isolate pipeline and chunked batch writes.
  /// Executes the chunked migration and returns count of migrated vs failed items.
  static Future<MigrationChunkResult> repairLegacyData({
    required ItemRepository itemRepo,
    required MemberRepository memberRepo,
    required List<ItemWithFields> items,
    MigrationStateStore? stateStore,
  }) async {
    if (items.isEmpty) {
      return MigrationChunkResult(migratedCount: 0, failedCount: 0);
    }

    final store = stateStore ?? MigrationStateStore();
    int migratedCount = 0;
    int failedCount = 0;

    // Chunk size is constrained to 300-500 items per transaction block
    const int chunkSize = 500;

    for (
      int chunkOffset = 0;
      chunkOffset < items.length;
      chunkOffset += chunkSize
    ) {
      final chunkItems = items.sublist(
        chunkOffset,
        min(chunkOffset + chunkSize, items.length),
      );

      int retries = 1;
      bool chunkSuccess = false;
      MigrationChunkResult? chunkResult;

      while (retries >= 0 && !chunkSuccess) {
        try {
          chunkResult = await _migrateChunk(
            itemRepo: itemRepo,
            memberRepo: memberRepo,
            chunkItems: chunkItems,
            stateStore: store,
          );
          chunkSuccess = true;
        } catch (e) {
          if (retries == 0) {
            rethrow; // Propagate chunk failure to abort execution
          }
          retries--;
        }
      }

      if (chunkResult != null) {
        migratedCount += chunkResult.migratedCount;
        failedCount += chunkResult.failedCount;
      }
    }

    return MigrationChunkResult(
      migratedCount: migratedCount,
      failedCount: failedCount,
    );
  }

  /// Inner processing for a single chunk. Isolates single-item migration failures.
  static Future<MigrationChunkResult> _migrateChunk({
    required ItemRepository itemRepo,
    required MemberRepository memberRepo,
    required List<ItemWithFields> chunkItems,
    required MigrationStateStore stateStore,
  }) async {
    // 1. Pre-Processing (Main Isolate)
    // Resolve member names and category labels in memory
    final memberIds = chunkItems
        .map((item) => item.memberId)
        .whereType<String>()
        .toSet()
        .toList();
    final memberMap = <String, String?>{};
    for (final memberId in memberIds) {
      try {
        final member = await memberRepo.getMemberById(memberId);
        memberMap[memberId] = member?.name;
      } catch (_) {
        memberMap[memberId] = null;
      }
    }

    final categoryLabels = <String, String>{};
    final categories = TemplateRegistry.getCategories();
    for (final cat in categories) {
      categoryLabels[cat.categoryKey] = cat.label;
    }

    // Pre-align input fields to the target template schema
    final isolateItemInputs = <MigrationIsolateItemInput>[];
    final validItems = <ItemWithFields>[];
    int failedCount = 0;

    for (final item in chunkItems) {
      try {
        if (item.typeKey == null) {
          failedCount++;
          continue;
        }
        final storedTemplate = TemplateRegistry.getTemplate(
          item.typeKey!,
          item.templateVersion,
        );
        if (storedTemplate?.supportsLegacyEditing == true) {
          continue;
        }
        final latestTypeDef = TemplateRegistry.getTemplate(item.typeKey!);
        if (latestTypeDef == null) {
          throw Exception(
            'Template definition not found for key: ${item.typeKey}',
          );
        }
        final inputFields = <MigrationFieldInput>[];
        final existingKeys = item.fields.map((f) => f.fieldKey).toSet();

        // Preserves existing fields (maintains deprecated/unknown warnings)
        for (final f in item.fields) {
          inputFields.add(
            MigrationFieldInput(
              fieldKey: f.fieldKey,
              valueText: f.valueText,
              fieldNote: f.fieldNote,
            ),
          );
        }

        // Fills missing fields in target schema with null
        for (final fDef in latestTypeDef.fields) {
          if (!existingKeys.contains(fDef.fieldKey)) {
            inputFields.add(
              MigrationFieldInput(
                fieldKey: fDef.fieldKey,
                valueText: null,
                fieldNote: null,
              ),
            );
          }
        }

        isolateItemInputs.add(
          MigrationIsolateItemInput(
            id: item.id,
            typeKey: item.typeKey!,
            fields: inputFields,
          ),
        );
        validItems.add(item);
      } catch (_) {
        failedCount++;
        final log = MigrationFailureLog(
          errorType: 'PreProcessingError',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await stateStore.saveFailureLog(log);
      }
    }

    if (isolateItemInputs.isEmpty) {
      return MigrationChunkResult(migratedCount: 0, failedCount: failedCount);
    }

    final isolateInput = MigrationIsolateInput(items: isolateItemInputs);

    // 2. Stage 1: Isolate Value Transformation (Background Isolate)
    final List<MigrationIsolateItemOutput> isolateOutputs =
        await MigrationIsolateRunner.run(isolateInput);

    // Map outputs back by ID for fast lookup
    final outputsMap = {for (final out in isolateOutputs) out.id: out};

    // 3. Stage 2: Main Isolate Domain Builder & Normalization Processing
    final chunkSaveInputs = <SaveItemInput>[];
    int migratedCount = 0;

    for (final item in validItems) {
      try {
        final out = outputsMap[item.id];
        if (out == null) {
          throw Exception('Isolate output missing for item ${item.id}');
        }
        final latestTypeDef = TemplateRegistry.getTemplate(item.typeKey!)!;
        final categoryLabel = categoryLabels[item.categoryKey] ?? '其他资料';

        // Reconstruct ItemDraftInput
        final draft = ItemDraftInput(
          id: item.id,
          memberId: item.memberId,
          categoryKey: item.categoryKey,
          typeKey: item.typeKey,
          templateVersion: latestTypeDef.version,
          title: item.title,
          isPinned: item.isPinned,
          pinnedAt: item.pinnedAt,
          fields: out.fields
              .map(
                (f) => ItemFieldDraftInput(
                  fieldKey: f.fieldKey,
                  valueText: f.valueText,
                  fieldNote: f.fieldNote,
                ),
              )
              .toList(),
        );

        // Normalize sensitive values on the Main Isolate
        final normalizedValues = <String, String?>{};
        for (final inputField in draft.fields) {
          final FieldDefinition? fieldDef =
              latestTypeDef.fields.any((f) => f.fieldKey == inputField.fieldKey)
              ? latestTypeDef.fields.firstWhere(
                  (f) => f.fieldKey == inputField.fieldKey,
                )
              : null;
          if (fieldDef == null) continue;

          normalizedValues[inputField.fieldKey] =
              SensitiveFieldGuard.normalizeSensitiveField(
                fieldKey: inputField.fieldKey,
                valueText: inputField.valueText,
                level: fieldDef.sensitiveLevel,
              );
        }

        // Build domain texts on the Main Isolate
        final resolvedMemberName = item.memberId != null
            ? memberMap[item.memberId]
            : null;
        final title = TitleSummaryBuilder.buildTitle(
          draft: draft,
          typeDef: latestTypeDef,
          memberName: resolvedMemberName,
        );

        final primaryText = TitleSummaryBuilder.buildPrimaryText(
          draft: draft,
          typeDef: latestTypeDef,
          title: title,
        );

        final secondaryText = TitleSummaryBuilder.buildSecondaryText(
          draft: draft,
          typeDef: latestTypeDef,
          primaryVal: primaryText,
        );

        final summaryText = TitleSummaryBuilder.buildSummaryText(
          draft: draft,
          typeDef: latestTypeDef,
        );

        final searchText = SearchTextBuilder.buildSearchText(
          title: title,
          typeDef: latestTypeDef,
          categoryLabel: categoryLabel,
          fields: draft.fields,
          normalizedValues: normalizedValues,
        );

        final repoFields = <SaveItemFieldInput>[];
        for (var i = 0; i < draft.fields.length; i++) {
          final inputField = draft.fields[i];
          final FieldDefinition? fieldDef =
              latestTypeDef.fields.any((f) => f.fieldKey == inputField.fieldKey)
              ? latestTypeDef.fields.firstWhere(
                  (f) => f.fieldKey == inputField.fieldKey,
                )
              : null;

          final int sortOrder = fieldDef == null
              ? i
              : latestTypeDef.fields.indexWhere(
                  (f) => f.fieldKey == inputField.fieldKey,
                );

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

        chunkSaveInputs.add(
          SaveItemInput(
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
            isPinned: item.isPinned,
            pinnedAt: item.pinnedAt,
            fields: repoFields,
            // Retain attachments
            attachments: item.attachments
                .map(
                  (a) => SaveAttachmentInput(
                    id: a.id,
                    originAttachmentId: a.originAttachmentId,
                    itemId: a.itemId,
                    linkedFieldKey: a.linkedFieldKey,
                    attachmentRole: a.attachmentRole,
                    fileName: a.fileName,
                    originalName: a.originalName,
                    mimeType: a.mimeType,
                    plainSize: a.plainSize,
                    encryptedSize: a.encryptedSize,
                    sha256: a.sha256,
                    sortOrder: a.sortOrder,
                  ),
                )
                .toList(),
          ),
        );
        migratedCount++;
      } catch (_) {
        failedCount++;
        final log = MigrationFailureLog(
          errorType: 'Stage2OrDomainBuilderError',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
        await stateStore.saveFailureLog(log);
      }
    }

    // 4. Chunked DB Write (One transaction per chunk, rollback on failure)
    if (chunkSaveInputs.isNotEmpty) {
      await itemRepo.saveItemsInBatch(chunkSaveInputs);
    }

    return MigrationChunkResult(
      migratedCount: migratedCount,
      failedCount: failedCount,
    );
  }

  /// Scans and repairs all outdated items using a paged serial execution loop
  static Future<void> migrateAll({
    required ItemRepository itemRepo,
    required MemberRepository memberRepo,
    MigrationStateStore? stateStore,
    int batchSize = 500,
  }) async {
    final store = stateStore ?? MigrationStateStore();
    MigrationCheckpoint? checkpoint = await store.getMigrationCheckpoint();

    int offset = 0;
    int totalItems = 0;
    int migratedCount = 0;
    int failedCount = 0;

    if (checkpoint != null) {
      offset = checkpoint.lastProcessedOffset;
      totalItems = checkpoint.totalItems;
      migratedCount = checkpoint.migratedCount;
      failedCount = checkpoint.failedCount;

      if (checkpoint.status == 'completed') {
        return; // Already completed
      }
    } else {
      // Calculate total items count from database dynamically
      final countResult = await itemRepo.db
          .customSelect('SELECT COUNT(*) as c FROM items')
          .map((row) => row.read<int>('c'))
          .getSingle();
      totalItems = countResult;

      checkpoint = MigrationCheckpoint(
        lastProcessedOffset: 0,
        totalItems: totalItems,
        migratedCount: 0,
        failedCount: 0,
        batchSize: batchSize,
        status: 'running',
      );
      await store.saveMigrationCheckpoint(checkpoint);
    }

    while (true) {
      final batch = await itemRepo.getItemsWithFieldsPaged(batchSize, offset);
      if (batch.isEmpty) {
        break;
      }

      // Filter inconsistent items in the current batch
      final inconsistent = <ItemWithFields>[];
      for (final item in batch) {
        if (item.typeKey == null) continue;
        final latest = TemplateRegistry.getTemplate(item.typeKey!);
        final storedTemplate = TemplateRegistry.getTemplate(
          item.typeKey!,
          item.templateVersion,
        );
        if (latest != null &&
            item.templateVersion < latest.version &&
            storedTemplate?.supportsLegacyEditing != true) {
          inconsistent.add(item);
        }
      }

      if (inconsistent.isNotEmpty) {
        int retries = 1;
        bool chunkSuccess = false;
        MigrationChunkResult? chunkResult;

        while (retries >= 0 && !chunkSuccess) {
          try {
            chunkResult = await repairLegacyData(
              itemRepo: itemRepo,
              memberRepo: memberRepo,
              items: inconsistent,
              stateStore: store,
            );
            chunkSuccess = true;
          } catch (e) {
            if (retries == 0) {
              // mark checkpoint as failed and abort
              checkpoint = MigrationCheckpoint(
                lastProcessedOffset: offset,
                totalItems: totalItems,
                migratedCount: migratedCount,
                failedCount: failedCount,
                batchSize: batchSize,
                status: 'failed',
              );
              await store.saveMigrationCheckpoint(checkpoint);
              rethrow;
            }
            retries--;
          }
        }

        if (chunkResult != null) {
          migratedCount += chunkResult.migratedCount;
          failedCount += chunkResult.failedCount;
        }
      }

      // Increment offset by batchSize to load next page sequentially
      offset += batchSize;

      // After each successful chunk:
      // - update lastProcessedOffset
      // - increment migratedCount
      // - persist checkpoint immediately
      checkpoint = MigrationCheckpoint(
        lastProcessedOffset: offset,
        totalItems: totalItems,
        migratedCount: migratedCount,
        failedCount: failedCount,
        batchSize: batchSize,
        status: offset >= totalItems ? 'completed' : 'running',
      );
      await store.saveMigrationCheckpoint(checkpoint);
    }

    // Mark completed
    checkpoint = MigrationCheckpoint(
      lastProcessedOffset: offset,
      totalItems: totalItems,
      migratedCount: migratedCount,
      failedCount: failedCount,
      batchSize: batchSize,
      status: 'completed',
    );
    await store.saveMigrationCheckpoint(checkpoint);

    // Clean up checkpoint ONLY when migration completes successfully
    await store.clearMigrationCheckpoint();
  }
}
