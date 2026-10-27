import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/app_database.dart';
import '../database/item_query_data_source.dart';
import '../attachment/attachment_model.dart';
import '../attachment/attachment_preview_cache.dart';
import '../attachment/attachment_thumbnail_cache.dart';
import '../service/validation/field_validation_error.dart';
import '../template/field_value_type.dart';
import '../template/sensitive_level.dart';
import '../template/template_registry.dart';
import 'models/item_model.dart';
import 'models/item_with_fields.dart';
import 'models/save_item_input.dart';
import 'models/item_child_entry_model.dart';
import 'models/item_event_model.dart';

List<Warning> _parseWarnings(String? metadataJson) {
  if (metadataJson == null || metadataJson.isEmpty) {
    return const [];
  }
  try {
    final Map<String, dynamic> data = jsonDecode(metadataJson);
    final warningsList = data['diagnostics'] ?? data['warnings'];
    if (warningsList is List) {
      return warningsList
          .map((w) {
            if (w is Map<String, dynamic>) {
              return Warning(
                fieldKey: w['fieldKey'] as String?,
                errorCode: w['errorCode'] as String? ?? '',
                errorMessage: w['errorMessage'] as String? ?? '',
              );
            }
            return null;
          })
          .whereType<Warning>()
          .toList();
    }
  } catch (_) {
    // Ignore malformed JSON
  }
  return const [];
}

class _StagedAttachmentFile {
  const _StagedAttachmentFile({required this.source, required this.staged});

  final File source;
  final File staged;
}

class _StagedAttachmentDeletion {
  const _StagedAttachmentDeletion(this.directory, this.files);

  final Directory directory;
  final List<_StagedAttachmentFile> files;

  Future<void> rollback() async {
    for (final file in files.reversed) {
      if (await file.staged.exists()) {
        await file.staged.rename(file.source.path);
      }
    }
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> commit() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

class _PendingEventChange {
  const _PendingEventChange({
    required this.kind,
    required this.subjectKey,
    required this.subjectLabel,
    this.oldValue,
    this.newValue,
  });

  final ItemEventChangeKind kind;
  final String subjectKey;
  final String subjectLabel;
  final String? oldValue;
  final String? newValue;
}

String? _parseDayFromMetadata(String? metadataJson, String fieldKey) {
  if (metadataJson == null || metadataJson.isEmpty) return null;
  try {
    final Map<String, dynamic> data = jsonDecode(metadataJson);
    final rawState = data['raw_state'];
    if (rawState is Map) {
      final fields = rawState['fields'];
      if (fields is Map) {
        final val = fields[fieldKey];
        if (val != null) {
          return val.toString();
        }
      }
    }
  } catch (_) {
    // Ignore malformed JSON
  }
  return null;
}

String? _parseRepaymentDay(String? metadataJson) {
  return _parseDayFromMetadata(metadataJson, 'repayment_day');
}

String? _parseBillDay(String? metadataJson) {
  return _parseDayFromMetadata(metadataJson, 'bill_day');
}

/// 资料主数据持久化访问 Repository (完全隔离 Drift 实体)
class ItemRepository {
  final AppDatabase db;
  final ItemQueryDataSource dataSource;

  /// DO NOT instantiate directly outside DI layer.
  ItemRepository(this.db, {ItemQueryDataSource? dataSource})
    : dataSource = dataSource ?? ItemQueryDataSource(db);

  /// 原生生成高安全强度的 UUID v4 字符串，无需外部第三方包依赖
  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));

    // 强制设定 UUID v4 版本与变体属性
    values[6] = (values[6] & 0x0f) | 0x40; // version 4
    values[8] = (values[8] & 0x3f) | 0x80; // variant RFC4122

    final buffer = StringBuffer();
    for (var i = 0; i < 16; i++) {
      if (i == 4 || i == 6 || i == 8 || i == 10) {
        buffer.write('-');
      }
      buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  /// 转换数据库物理实体至业务主表模型
  ItemModel _mapToModel(
    Item item, {
    Map<String, String?> fieldValues = const {},
  }) {
    return ItemModel(
      id: item.id,
      originId: item.originId,
      memberId: item.memberId,
      categoryKey: item.categoryKey,
      typeKey: item.typeKey,
      templateVersion: item.templateVersion,
      title: item.title,
      primaryText: item.primaryText,
      secondaryText: item.secondaryText,
      summaryText: item.summaryText,
      searchText: item.searchText,
      repaymentDay: _parseRepaymentDay(item.metadata),
      billDay: _parseBillDay(item.metadata),
      note: item.note,
      isFavorite: item.isFavorite,
      isPinned: item.isPinned,
      pinnedAt: item.pinnedAt,
      sortOrder: item.sortOrder,
      status: item.status,
      deletedAt: item.deletedAt,
      statusBeforeDeletion: item.statusBeforeDeletion,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      lastViewedAt: item.lastViewedAt,
      metadata: item.metadata,
      fieldValues: fieldValues,
      validationWarnings: _parseWarnings(item.metadata),
    );
  }

  Future<List<ItemModel>> _mapListSummaries(List<Item> items) async {
    if (items.isEmpty) return const [];

    final itemIds = items.map((item) => item.id).toList();
    final fieldValuesByItem = <String, Map<String, String?>>{};
    final insuranceIds = items
        .where((item) => item.typeKey == 'insurance')
        .map((item) => item.id)
        .toList();
    final bankCardIds = items
        .where(
          (item) =>
              item.typeKey == 'debit_card' || item.typeKey == 'credit_card',
        )
        .map((item) => item.id)
        .toList();
    final summaryFields =
        await (db.select(db.itemFields)..where(
              (field) =>
                  field.itemId.isIn(itemIds) &
                      field.fieldKey.isIn(const [
                        'bill_day',
                        'repayment_day',
                        'valid_until',
                        'end_date',
                        'is_long_term',
                      ]) |
                  (field.itemId.isIn(insuranceIds) &
                      field.fieldKey.isIn(const ['insurance_type'])) |
                  (field.itemId.isIn(bankCardIds) &
                      field.fieldKey.isIn(const ['bank_name', 'is_closed'])),
            ))
            .get();
    for (final field in summaryFields) {
      fieldValuesByItem.putIfAbsent(
        field.itemId,
        () => <String, String?>{},
      )[field.fieldKey] = field.valueText;
    }

    return items
        .map(
          (item) => _mapToModel(
            item,
            fieldValues: fieldValuesByItem[item.id] ?? const {},
          ).toListSummary(),
        )
        .toList();
  }

  /// 事务内安全写入一条资料以及其关联的所有字段属性（新建或更新一站式覆盖）
  Future<String> saveItemWithFields(
    SaveItemInput input, {
    bool recordUserEvent = false,
  }) async {
    final itemId = input.id ?? _generateUuid();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pinnedAt = input.isPinned ? (input.pinnedAt ?? now) : null;

    List<Attachment> filesToDelete = [];

    await db.transaction(() async {
      // 1. 若是更新且已存在资料，拉取其原本的创建时间，确保满足 drift 的非空 integrity 校验
      int createdAtVal = now;
      var existedBeforeSave = false;
      Item? existingItem;
      var existingFields = const <ItemField>[];
      if (input.id != null) {
        existingItem = await (db.select(
          db.items,
        )..where((tbl) => tbl.id.equals(itemId))).getSingleOrNull();
        if (existingItem != null) {
          existedBeforeSave = true;
          createdAtVal = existingItem.createdAt;
          existingFields = await (db.select(
            db.itemFields,
          )..where((field) => field.itemId.equals(itemId))).get();
        }
      }

      final existingAttachments = await (db.select(
        db.attachments,
      )..where((tbl) => tbl.itemId.equals(itemId))).get();
      final eventChanges = existedBeforeSave
          ? await _buildSaveEventChanges(
              existingItem!,
              existingFields,
              existingAttachments,
              input,
            )
          : const <_PendingEventChange>[];

      // 2. 组装插入或覆盖的 Items Companion 实体
      final itemCompanion = ItemsCompanion(
        id: Value(itemId),
        originId: Value(existingItem?.originId ?? input.originId ?? itemId),
        memberId: Value(input.memberId),
        categoryKey: Value(input.categoryKey),
        typeKey: Value(input.typeKey),
        templateVersion: Value(input.templateVersion),
        title: Value(input.title),
        primaryText: Value(input.primaryText),
        secondaryText: Value(input.secondaryText),
        summaryText: Value(input.summaryText),
        searchText: Value(input.searchText),
        note: Value(input.note),
        isFavorite: Value(input.isFavorite),
        isPinned: Value(input.isPinned),
        pinnedAt: Value(pinnedAt),
        sortOrder: Value(input.sortOrder),
        status: Value(input.status),
        deletedAt: Value(input.deletedAt),
        statusBeforeDeletion: Value(input.statusBeforeDeletion),
        updatedAt: Value(now),
        createdAt: Value(createdAtVal),
        metadata: Value(input.metadata),
      );

      await db.into(db.items).insertOnConflictUpdate(itemCompanion);

      // 2. 清理当前资料下挂的所有老字段属性，确保更新时为全量覆盖状态，防历史数据垃圾残留
      await (db.delete(
        db.itemFields,
      )..where((tbl) => tbl.itemId.equals(itemId))).go();

      // 3. 批量将新传入的字段集插入
      for (final field in input.fields) {
        final fieldId = _generateUuid();
        await db
            .into(db.itemFields)
            .insert(
              ItemFieldsCompanion.insert(
                id: fieldId,
                itemId: itemId,
                fieldKey: field.fieldKey,
                valueType: field.valueType.toKey(), // 将强类型枚举转换入库存储
                valueText: Value(field.valueText),
                normalizedValue: Value(field.normalizedValue),
                fieldNote: Value(field.fieldNote),
                sortOrder: Value(field.sortOrder),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      // 4. 同步附件关系，并计算需要物理删除的文件清单
      final newFileNames = input.attachments.map((a) => a.fileName).toSet();
      filesToDelete = existingAttachments
          .where((ea) => !newFileNames.contains(ea.fileName))
          .toList();

      await (db.delete(
        db.attachments,
      )..where((tbl) => tbl.itemId.equals(itemId))).go();

      for (final att in input.attachments) {
        final attId = att.id ?? _generateUuid();
        final existingOriginAttachmentId = existingAttachments
            .where((existing) => existing.id == attId)
            .map((existing) => existing.originAttachmentId)
            .firstOrNull;
        await db
            .into(db.attachments)
            .insert(
              AttachmentsCompanion.insert(
                id: attId,
                originAttachmentId:
                    existingOriginAttachmentId ??
                    att.originAttachmentId ??
                    attId,
                itemId: itemId,
                linkedFieldKey: Value(att.linkedFieldKey),
                attachmentRole: att.attachmentRole,
                fileName: att.fileName,
                originalName: Value(att.originalName),
                mimeType: att.mimeType,
                plainSize: Value(att.plainSize),
                encryptedSize: Value(att.encryptedSize),
                sha256: Value(att.sha256),
                sortOrder: Value(att.sortOrder),
                status: const Value('active'),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      // 5. 同步子项及子字段 (三态语义: null 表示保留已有，[] 表示清空，非空表示覆盖)
      if (input.childEntries != null) {
        await (db.delete(
          db.itemChildEntries,
        )..where((tbl) => tbl.itemId.equals(itemId))).go();

        for (final entry in input.childEntries!) {
          final entryId = entry.id ?? _generateUuid();
          await db
              .into(db.itemChildEntries)
              .insert(
                ItemChildEntriesCompanion.insert(
                  id: entryId,
                  itemId: itemId,
                  childType: entry.childType,
                  sortOrder: Value(entry.sortOrder),
                  createdAt: now,
                  updatedAt: now,
                ),
              );

          for (final field in entry.fields) {
            final fieldId = _generateUuid();
            await db
                .into(db.itemChildFields)
                .insert(
                  ItemChildFieldsCompanion.insert(
                    id: fieldId,
                    childEntryId: entryId,
                    fieldKey: field.fieldKey,
                    label: field.label,
                    valueText: Value(field.valueText),
                    valueType: field.valueType,
                    sensitiveLevel: field.sensitiveLevel,
                    copyable: Value(field.copyable),
                    searchable: Value(field.searchable),
                    summary: Value(field.summary),
                    sortOrder: Value(field.sortOrder),
                    createdAt: now,
                    updatedAt: now,
                  ),
                );
          }
        }
      }

      if (recordUserEvent) {
        if (!existedBeforeSave) {
          await _insertItemEvent(itemId, ItemEventType.created, now);
        } else if (eventChanges.isNotEmpty) {
          await _insertItemEvent(
            itemId,
            ItemEventType.updated,
            now,
            changes: eventChanges,
          );
        }
      }
    });

    // 5. 事务提交成功后，物理清理已被移除附件的文件系统密文文件
    if (filesToDelete.isNotEmpty) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final attachmentsDir = Directory(p.join(docDir.path, 'attachments'));
        for (final ea in filesToDelete) {
          final file = File(p.join(attachmentsDir.path, ea.fileName));
          if (await file.exists()) {
            await file.delete();
          }
          await AttachmentPreviewCache.deleteForFileName(
            ea.fileName,
            documentsDirectoryProvider: () async => docDir,
          );
          await AttachmentThumbnailCache.deleteForFileName(
            ea.fileName,
            documentsDirectoryProvider: () async => docDir,
          );
        }
      } catch (_) {
        // 静默防崩，脏物理文件可由垃圾清理服务兜底清除
      }
    }

    return itemId;
  }

  /// 查询指定 ID 的完整资料对象（自动联表组装属性字段列表）
  Future<ItemWithFields?> getItemWithFields(String itemId) async {
    final item = await (db.select(
      db.items,
    )..where((tbl) => tbl.id.equals(itemId))).getSingleOrNull();
    if (item == null) {
      return null;
    }

    final fieldsFuture =
        (db.select(db.itemFields)
              ..where((tbl) => tbl.itemId.equals(itemId))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();
    final attachmentsFuture =
        (db.select(db.attachments)
              ..where(
                (tbl) =>
                    tbl.itemId.equals(itemId) & tbl.status.equals('active'),
              )
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();
    final relatedRecords = await Future.wait<Object>([
      fieldsFuture,
      attachmentsFuture,
    ]);
    final fields = relatedRecords[0] as List<ItemField>;
    final attachmentRecords = relatedRecords[1] as List<Attachment>;

    final mappedFields = fields.map(_mapField).toList();
    final mappedAttachments = attachmentRecords.map(_mapAttachment).toList();

    return _buildItemWithFields(item, mappedFields, mappedAttachments);
  }

  /// 物理删除资料数据，由 SQLite 外键级联 CASCADE 机制删除 item_fields、reminders、attachments 的关联记录
  Future<void> deleteItem(String itemId) async {
    // 1. 查询关联的附件，以便删除其对应的物理加密文件
    final attachmentsList = await (db.select(
      db.attachments,
    )..where((tbl) => tbl.itemId.equals(itemId))).get();

    // 2. 先把附件原子移动到删除暂存区。数据库删除失败时可移回原位。
    _StagedAttachmentDeletion? stagedDeletion;
    if (attachmentsList.isNotEmpty) {
      stagedDeletion = await _stageAttachmentsForDeletion(
        itemId,
        attachmentsList,
      );
    }

    // 3. 删除数据库记录 (物理删除 cascade)。失败时恢复附件。
    try {
      await (db.delete(db.items)..where((tbl) => tbl.id.equals(itemId))).go();
    } catch (_) {
      if (stagedDeletion != null) {
        await stagedDeletion.rollback();
      }
      rethrow;
    }

    // 4. 数据库提交后清理暂存密文。清理失败只会留下不可达密文，后续可安全重试。
    if (stagedDeletion != null) {
      try {
        await stagedDeletion.commit();
        final docDir = await getApplicationDocumentsDirectory();
        for (final attachment in attachmentsList) {
          await AttachmentPreviewCache.deleteForFileName(
            attachment.fileName,
            documentsDirectoryProvider: () async => docDir,
          );
          await AttachmentThumbnailCache.deleteForFileName(
            attachment.fileName,
            documentsDirectoryProvider: () async => docDir,
          );
        }
      } catch (_) {
        // 不回滚已提交的数据库永久删除。
      }
    }
  }

  Future<_StagedAttachmentDeletion> _stageAttachmentsForDeletion(
    String itemId,
    List<Attachment> attachments,
  ) async {
    final docDir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(docDir.path, 'attachments'));
    final stagingDir = Directory(
      p.join(docDir.path, '.attachment-delete-staging', itemId),
    );
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    final movedFiles = <_StagedAttachmentFile>[];
    try {
      for (final attachment in attachments) {
        final source = File(p.join(attachmentsDir.path, attachment.fileName));
        if (!await source.exists()) continue;
        final staged = File(p.join(stagingDir.path, attachment.fileName));
        await source.rename(staged.path);
        movedFiles.add(_StagedAttachmentFile(source: source, staged: staged));
      }
      return _StagedAttachmentDeletion(stagingDir, movedFiles);
    } catch (_) {
      final deletion = _StagedAttachmentDeletion(stagingDir, movedFiles);
      await deletion.rollback();
      rethrow;
    }
  }

  Future<bool> moveToTrash(String itemId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updated = 0;
    await db.transaction(() async {
      final existing =
          await (db.select(db.items)..where(
                (item) =>
                    item.id.equals(itemId) &
                    item.status.isIn(const ['active', 'archived']),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      updated =
          await (db.update(db.items)..where(
                (item) =>
                    item.id.equals(itemId) &
                    item.status.isIn(const ['active', 'archived']),
              ))
              .write(
                ItemsCompanion(
                  status: const Value('deleted'),
                  deletedAt: Value(now),
                  statusBeforeDeletion: Value(existing.status),
                  isPinned: const Value(false),
                  pinnedAt: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (updated == 1) {
        final changes = <_PendingEventChange>[
          _PendingEventChange(
            kind: ItemEventChangeKind.valueChanged,
            subjectKey: 'status',
            subjectLabel: '资料状态',
            oldValue: _statusLabel(existing.status),
            newValue: '最近删除',
          ),
          if (existing.isPinned)
            const _PendingEventChange(
              kind: ItemEventChangeKind.valueChanged,
              subjectKey: 'is_pinned',
              subjectLabel: '置顶状态',
              oldValue: '已置顶',
              newValue: '未置顶',
            ),
        ];
        await _insertItemEvent(
          itemId,
          ItemEventType.movedToTrash,
          now,
          changes: changes,
        );
      }
    });
    return updated == 1;
  }

  Future<bool> restoreFromTrash(String itemId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updated = 0;
    await db.transaction(() async {
      final existing =
          await (db.select(db.items)..where(
                (item) =>
                    item.id.equals(itemId) & item.status.equals('deleted'),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      final restoredStatus = existing.statusBeforeDeletion ?? 'active';
      updated =
          await (db.update(db.items)..where(
                (item) =>
                    item.id.equals(itemId) & item.status.equals('deleted'),
              ))
              .write(
                ItemsCompanion(
                  status: Value(restoredStatus),
                  deletedAt: const Value(null),
                  statusBeforeDeletion: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (updated == 1) {
        await _insertItemEvent(
          itemId,
          ItemEventType.restored,
          now,
          changes: [
            _PendingEventChange(
              kind: ItemEventChangeKind.valueChanged,
              subjectKey: 'status',
              subjectLabel: '资料状态',
              oldValue: '最近删除',
              newValue: _statusLabel(restoredStatus),
            ),
          ],
        );
      }
    });
    return updated == 1;
  }

  Future<List<ItemModel>> getDeletedItems() async {
    final items =
        await (db.select(db.items)
              ..where((item) => item.status.equals('deleted'))
              ..orderBy([
                (item) => OrderingTerm(
                  expression: item.deletedAt,
                  mode: OrderingMode.desc,
                ),
                (item) =>
                    OrderingTerm(expression: item.id, mode: OrderingMode.desc),
              ]))
            .get();
    return _mapListSummaries(items);
  }

  Future<int> getDeletedItemCount() async {
    final count = db.items.id.count();
    final query = db.selectOnly(db.items)
      ..addColumns([count])
      ..where(db.items.status.equals('deleted'));
    return (await query.getSingle()).read(count) ?? 0;
  }

  Future<bool> archiveItem(String itemId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updated = 0;
    await db.transaction(() async {
      final existing =
          await (db.select(db.items)..where(
                (item) => item.id.equals(itemId) & item.status.equals('active'),
              ))
              .getSingleOrNull();
      if (existing == null) return;
      updated =
          await (db.update(db.items)..where(
                (item) => item.id.equals(itemId) & item.status.equals('active'),
              ))
              .write(
                ItemsCompanion(
                  status: const Value('archived'),
                  isPinned: const Value(false),
                  pinnedAt: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (updated == 1) {
        await _insertItemEvent(
          itemId,
          ItemEventType.archived,
          now,
          changes: [
            const _PendingEventChange(
              kind: ItemEventChangeKind.valueChanged,
              subjectKey: 'status',
              subjectLabel: '资料状态',
              oldValue: '使用中',
              newValue: '已归档',
            ),
            if (existing.isPinned)
              const _PendingEventChange(
                kind: ItemEventChangeKind.valueChanged,
                subjectKey: 'is_pinned',
                subjectLabel: '置顶状态',
                oldValue: '已置顶',
                newValue: '未置顶',
              ),
          ],
        );
      }
    });
    return updated == 1;
  }

  Future<bool> unarchiveItem(String itemId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updated = 0;
    await db.transaction(() async {
      updated =
          await (db.update(db.items)..where(
                (item) =>
                    item.id.equals(itemId) & item.status.equals('archived'),
              ))
              .write(
                ItemsCompanion(
                  status: const Value('active'),
                  isPinned: const Value(false),
                  pinnedAt: const Value(null),
                  updatedAt: Value(now),
                ),
              );
      if (updated == 1) {
        await _insertItemEvent(
          itemId,
          ItemEventType.unarchived,
          now,
          changes: const [
            _PendingEventChange(
              kind: ItemEventChangeKind.valueChanged,
              subjectKey: 'status',
              subjectLabel: '资料状态',
              oldValue: '已归档',
              newValue: '使用中',
            ),
          ],
        );
      }
    });
    return updated == 1;
  }

  Future<List<ItemModel>> getArchivedItems({String? keyword}) async {
    final normalized = keyword?.trim() ?? '';
    final query = db.select(db.items)
      ..where((item) {
        final archived = item.status.equals('archived');
        if (normalized.isEmpty) return archived;
        final pattern = '%$normalized%';
        return archived &
            (item.title.like(pattern) |
                item.summaryText.like(pattern) |
                item.searchText.like(pattern));
      })
      ..orderBy([
        (item) =>
            OrderingTerm(expression: item.updatedAt, mode: OrderingMode.desc),
      ]);
    return _mapListSummaries(await query.get());
  }

  Future<int> getArchivedItemCount({String? keyword}) async {
    final normalized = keyword?.trim() ?? '';
    final variables = <Variable>[Variable.withString('archived')];
    var sql = 'SELECT COUNT(*) AS c FROM items WHERE status = ?';
    if (normalized.isNotEmpty) {
      sql += ' AND (title LIKE ? OR summary_text LIKE ? OR search_text LIKE ?)';
      final pattern = '%$normalized%';
      variables.addAll([
        Variable.withString(pattern),
        Variable.withString(pattern),
        Variable.withString(pattern),
      ]);
    }
    final row = await db.customSelect(sql, variables: variables).getSingle();
    return row.read<int>('c');
  }

  Future<List<_PendingEventChange>> _buildSaveEventChanges(
    Item existing,
    List<ItemField> existingFields,
    List<Attachment> existingAttachments,
    SaveItemInput input,
  ) async {
    final changes = <_PendingEventChange>[];

    void addValueChange(
      String key,
      String label,
      String? oldValue,
      String? newValue,
    ) {
      if (oldValue == newValue) return;
      changes.add(
        _PendingEventChange(
          kind: ItemEventChangeKind.valueChanged,
          subjectKey: key,
          subjectLabel: label,
          oldValue: _displayEmpty(oldValue),
          newValue: _displayEmpty(newValue),
        ),
      );
    }

    void addFieldChange(String key, String label) {
      changes.add(
        _PendingEventChange(
          kind: ItemEventChangeKind.fieldChanged,
          subjectKey: key,
          subjectLabel: label,
        ),
      );
    }

    if (existing.memberId != input.memberId) {
      addValueChange(
        'member_id',
        '归属成员',
        await _memberLabel(existing.memberId),
        await _memberLabel(input.memberId),
      );
    }
    addValueChange(
      'category_key',
      '资料分类',
      _categoryLabel(existing.categoryKey),
      _categoryLabel(input.categoryKey),
    );
    addValueChange(
      'type_key',
      '资料类型',
      _typeLabel(existing.typeKey, existing.templateVersion),
      _typeLabel(input.typeKey, input.templateVersion),
    );
    if (existing.title != input.title) addFieldChange('title', '资料标题');
    if (existing.note != input.note) addFieldChange('note', '备注');
    addValueChange(
      'is_favorite',
      '常用状态',
      existing.isFavorite ? '已设为常用' : '未设为常用',
      input.isFavorite ? '已设为常用' : '未设为常用',
    );
    addValueChange(
      'is_pinned',
      '置顶状态',
      existing.isPinned ? '已置顶' : '未置顶',
      input.isPinned ? '已置顶' : '未置顶',
    );
    addValueChange(
      'status',
      '资料状态',
      _statusLabel(existing.status),
      _statusLabel(input.status),
    );

    final template = input.typeKey == null
        ? null
        : TemplateRegistry.getTemplate(input.typeKey!, input.templateVersion);
    final definitions = {
      for (final definition in template?.fields ?? const [])
        definition.fieldKey: definition,
    };
    final oldFields = {
      for (final field in existingFields) field.fieldKey: field,
    };
    final newFields = {for (final field in input.fields) field.fieldKey: field};
    final fieldKeys = {...oldFields.keys, ...newFields.keys}.toList()..sort();
    for (final key in fieldKeys) {
      final oldField = oldFields[key];
      final newField = newFields[key];
      final oldValue = oldField?.valueText;
      final newValue = newField?.valueText;
      final noteChanged = oldField?.fieldNote != newField?.fieldNote;
      if (oldValue == newValue && !noteChanged) continue;

      final definition = definitions[key];
      final label = definition?.label ?? oldField?.rawFieldLabel ?? '历史字段';
      final valueType =
          newField?.valueType ??
          (oldField == null
              ? FieldValueType.text
              : FieldValueType.fromKey(oldField.valueType));
      final mayPersistValue =
          definition != null &&
          (definition.sensitiveLevel == SensitiveLevel.none ||
              definition.sensitiveLevel == SensitiveLevel.low) &&
          const {
            FieldValueType.date,
            FieldValueType.monthDay,
            FieldValueType.dayOfMonth,
          }.contains(valueType);
      if (oldValue != newValue) {
        if (mayPersistValue) {
          addValueChange(key, label, oldValue, newValue);
        } else {
          addFieldChange(key, label);
        }
      }
      if (noteChanged) {
        addFieldChange('${key}_note', '$label备注');
      }
    }

    final oldFileNames = existingAttachments
        .map((attachment) => attachment.fileName)
        .toSet();
    final newFileNames = input.attachments
        .map((attachment) => attachment.fileName)
        .toSet();
    final removedCount = oldFileNames.difference(newFileNames).length;
    final addedCount = newFileNames.difference(oldFileNames).length;
    if (removedCount > 0 || addedCount > 0) {
      changes.add(
        _PendingEventChange(
          kind: ItemEventChangeKind.attachmentCountChanged,
          subjectKey: 'attachments',
          subjectLabel: '附件',
          oldValue: removedCount.toString(),
          newValue: addedCount.toString(),
        ),
      );
    }

    if (input.childEntries != null &&
        await _childEntriesChanged(existing.id, input.childEntries!)) {
      addFieldChange('child_entries', '户内成员信息');
    }
    return changes;
  }

  Future<bool> _childEntriesChanged(
    String itemId,
    List<SaveItemChildEntryInput> inputEntries,
  ) async {
    final entries =
        await (db.select(db.itemChildEntries)
              ..where((entry) => entry.itemId.equals(itemId))
              ..orderBy([
                (entry) => OrderingTerm(expression: entry.sortOrder),
                (entry) => OrderingTerm(expression: entry.id),
              ]))
            .get();
    final fields = entries.isEmpty
        ? const <ItemChildField>[]
        : await (db.select(db.itemChildFields)
                ..where(
                  (field) => field.childEntryId.isIn(
                    entries.map((entry) => entry.id).toList(growable: false),
                  ),
                )
                ..orderBy([
                  (field) => OrderingTerm(expression: field.sortOrder),
                  (field) => OrderingTerm(expression: field.fieldKey),
                ]))
              .get();
    final fieldsByEntry = <String, List<ItemChildField>>{};
    for (final field in fields) {
      fieldsByEntry.putIfAbsent(field.childEntryId, () => []).add(field);
    }
    final oldState = entries
        .map(
          (entry) => [
            entry.childType,
            entry.sortOrder,
            for (final field in fieldsByEntry[entry.id] ?? const [])
              [
                field.fieldKey,
                field.valueText,
                field.valueType,
                field.sensitiveLevel,
                field.sortOrder,
              ],
          ],
        )
        .toList(growable: false);
    final sortedInputEntries = [...inputEntries]
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : (a.id ?? '').compareTo(b.id ?? '');
      });
    final newState = sortedInputEntries
        .map(
          (entry) => [
            entry.childType,
            entry.sortOrder,
            for (final field
                in [...entry.fields]..sort((a, b) {
                  final order = a.sortOrder.compareTo(b.sortOrder);
                  return order != 0 ? order : a.fieldKey.compareTo(b.fieldKey);
                }))
              [
                field.fieldKey,
                field.valueText,
                field.valueType,
                field.sensitiveLevel,
                field.sortOrder,
              ],
          ],
        )
        .toList(growable: false);
    return jsonEncode(oldState) != jsonEncode(newState);
  }

  Future<String?> _memberLabel(String? memberId) async {
    if (memberId == null) return null;
    return (await (db.select(
      db.members,
    )..where((member) => member.id.equals(memberId))).getSingleOrNull())?.name;
  }

  String? _categoryLabel(String? categoryKey) {
    if (categoryKey == null) return null;
    for (final category in TemplateRegistry.getCategories()) {
      if (category.categoryKey == categoryKey) return category.label;
    }
    return categoryKey;
  }

  String? _typeLabel(String? typeKey, int version) {
    if (typeKey == null) return null;
    return TemplateRegistry.getTemplate(typeKey, version)?.label ?? typeKey;
  }

  String _statusLabel(String status) => switch (status) {
    'active' => '使用中',
    'archived' => '已归档',
    'deleted' => '最近删除',
    _ => status,
  };

  String _displayEmpty(String? value) =>
      value == null || value.isEmpty ? '未设置' : value;

  Future<void> _insertItemEvent(
    String itemId,
    ItemEventType eventType,
    int occurredAt, {
    List<_PendingEventChange> changes = const [],
  }) async {
    final eventId = _generateUuid();
    await db
        .into(db.itemEvents)
        .insert(
          ItemEventsCompanion.insert(
            id: eventId,
            itemId: itemId,
            eventType: eventType.key,
            occurredAt: occurredAt,
          ),
        );
    for (var index = 0; index < changes.length; index++) {
      final change = changes[index];
      await db
          .into(db.itemEventChanges)
          .insert(
            ItemEventChangesCompanion.insert(
              id: _generateUuid(),
              eventId: eventId,
              changeKind: change.kind.key,
              subjectKey: change.subjectKey,
              subjectLabel: change.subjectLabel,
              oldValue: Value(change.oldValue),
              newValue: Value(change.newValue),
              sortOrder: Value(index),
            ),
          );
    }
  }

  /// 仅更新资料置顶状态，不重写字段或附件。
  Future<bool> updateItemPinned(String itemId, {required bool isPinned}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    var updatedCount = 0;
    await db.transaction(() async {
      final existing =
          await (db.select(db.items)..where(
                (item) => item.id.equals(itemId) & item.status.equals('active'),
              ))
              .getSingleOrNull();
      if (existing == null || existing.isPinned == isPinned) return;
      updatedCount =
          await (db.update(
            db.items,
          )..where((item) => item.id.equals(itemId))).write(
            ItemsCompanion(
              isPinned: Value(isPinned),
              pinnedAt: isPinned ? Value(now) : const Value(null),
              updatedAt: Value(now),
            ),
          );
      if (updatedCount == 1) {
        await _insertItemEvent(
          itemId,
          ItemEventType.updated,
          now,
          changes: [
            _PendingEventChange(
              kind: ItemEventChangeKind.valueChanged,
              subjectKey: 'is_pinned',
              subjectLabel: '置顶状态',
              oldValue: existing.isPinned ? '已置顶' : '未置顶',
              newValue: isPinned ? '已置顶' : '未置顶',
            ),
          ],
        );
      }
    });
    return updatedCount == 1;
  }

  /// 获取所有活跃资料：置顶优先，置顶内按最近置顶时间，其余按更新时间。
  Future<List<ItemModel>> getActiveItems({
    String? memberId,
    String? typeKey,
  }) async {
    final list =
        await (db.select(db.items)
              ..where((tbl) {
                var predicate = tbl.status.equals('active');
                if (memberId != null) {
                  predicate &= tbl.memberId.equals(memberId);
                }
                if (typeKey != null) predicate &= tbl.typeKey.equals(typeKey);
                return predicate;
              })
              ..orderBy([
                (tbl) => OrderingTerm(
                  expression: tbl.isPinned,
                  mode: OrderingMode.desc,
                ),
                (tbl) => OrderingTerm(
                  expression: tbl.pinnedAt,
                  mode: OrderingMode.desc,
                ),
                (tbl) => OrderingTerm(
                  expression: tbl.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ]))
            .get();
    return _mapListSummaries(list);
  }

  /// 数量统计不构造资料或读取状态字段。
  Future<int> getActiveItemCount() async {
    final count = db.items.id.count();
    final query = db.selectOnly(db.items)
      ..addColumns([count])
      ..where(db.items.status.equals('active'));
    return (await query.getSingle()).read(count) ?? 0;
  }

  /// 获取最近保存的会话活跃资料列表，最多限制 20 条，按更新时间倒序
  Future<List<ItemModel>> getRecentItemsForSession() async {
    final list =
        await (db.select(db.items)
              ..where((tbl) => tbl.status.equals('active'))
              ..orderBy([
                (tbl) => OrderingTerm(
                  expression: tbl.updatedAt,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(20))
            .get();
    return _mapListSummaries(list);
  }

  /// 搜寻匹配关键词的低敏资料，返回过滤后的 ItemModel 列表 (不含排序与打分)
  Future<List<ItemModel>> searchItems(String keyword) async {
    final rawItems = await dataSource.queryRawItemsByKeyword(keyword);
    return _mapListSummaries(rawItems);
  }

  Future<Set<String>> getBankCardItemIdsBySuffix(String suffix) {
    return dataSource.queryBankCardItemIdsBySuffix(suffix);
  }

  /// 备份专项：获取所有资料（包含已归档），联表加载对应的属性字段明细列表
  Future<List<ItemWithFields>> getAllItemsWithFieldsForBackup() async {
    // 1. 查询所有 items 记录，按 createdAt 排序
    final itemsList = await (db.select(
      db.items,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.createdAt)])).get();

    if (itemsList.isEmpty) {
      return [];
    }

    // 2. 一次性查询所有的 item_fields 记录
    final fieldsList = await (db.select(
      db.itemFields,
    )..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)])).get();

    // 3. 将 fields 按 itemId 分类归档，避免在循环中重复读库
    final Map<String, List<ItemFieldModel>> fieldsMap = {};
    for (final f in fieldsList) {
      final model = _mapField(f);
      fieldsMap.putIfAbsent(f.itemId, () => []).add(model);
    }

    // 4. 一次性查询所有的 attachments 记录
    final attachmentsList =
        await (db.select(db.attachments)
              ..where((tbl) => tbl.status.equals('active'))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();

    // 5. 将 attachments 按 itemId 分类归档
    final Map<String, List<AttachmentModel>> attachmentsMap = {};
    for (final a in attachmentsList) {
      final model = _mapAttachment(a);
      attachmentsMap.putIfAbsent(a.itemId, () => []).add(model);
    }

    // 6. 组装返回 ItemWithFields 实体列表
    return itemsList.map((item) {
      final itemFields = fieldsMap[item.id] ?? [];
      final itemAttachments = attachmentsMap[item.id] ?? [];
      return _buildItemWithFields(item, itemFields, itemAttachments);
    }).toList();
  }

  /// Paged query for items with fields (ordered by id to support stable offset/cursor paging)
  Future<List<ItemWithFields>> getItemsWithFieldsPaged(
    int limit,
    int offset,
  ) async {
    // 1. Query a slice of items
    final itemsList =
        await (db.select(db.items)
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.id)])
              ..limit(limit, offset: offset))
            .get();

    if (itemsList.isEmpty) {
      return [];
    }

    final itemIds = itemsList.map((item) => item.id).toList();

    // 2. Query fields for only these items
    final fieldsList =
        await (db.select(db.itemFields)
              ..where((tbl) => tbl.itemId.isIn(itemIds))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();

    final Map<String, List<ItemFieldModel>> fieldsMap = {};
    for (final f in fieldsList) {
      final model = _mapField(f);
      fieldsMap.putIfAbsent(f.itemId, () => []).add(model);
    }

    // 3. Query attachments for only these items
    final attachmentsList =
        await (db.select(db.attachments)
              ..where(
                (tbl) => tbl.itemId.isIn(itemIds) & tbl.status.equals('active'),
              )
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();

    final Map<String, List<AttachmentModel>> attachmentsMap = {};
    for (final a in attachmentsList) {
      final model = _mapAttachment(a);
      attachmentsMap.putIfAbsent(a.itemId, () => []).add(model);
    }

    // 4. Assemble
    return itemsList.map((item) {
      final itemFields = fieldsMap[item.id] ?? [];
      final itemAttachments = attachmentsMap[item.id] ?? [];
      return _buildItemWithFields(item, itemFields, itemAttachments);
    }).toList();
  }

  /// Batch save multiple items and their fields/attachments in a single outer database transaction
  Future<void> saveItemsInBatch(List<SaveItemInput> inputs) async {
    if (inputs.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction(() async {
      for (final input in inputs) {
        final itemId = input.id ?? _generateUuid();
        final pinnedAt = input.isPinned ? (input.pinnedAt ?? now) : null;

        // 1. Resolve creation time if exists
        int createdAtVal = now;
        Item? existingItem;
        if (input.id != null) {
          existingItem = await (db.select(
            db.items,
          )..where((tbl) => tbl.id.equals(itemId))).getSingleOrNull();
          if (existingItem != null) {
            createdAtVal = existingItem.createdAt;
          }
        }

        // 2. Insert/Update Item
        final itemCompanion = ItemsCompanion(
          id: Value(itemId),
          originId: Value(existingItem?.originId ?? input.originId ?? itemId),
          memberId: Value(input.memberId),
          categoryKey: Value(input.categoryKey),
          typeKey: Value(input.typeKey),
          templateVersion: Value(input.templateVersion),
          title: Value(input.title),
          primaryText: Value(input.primaryText),
          secondaryText: Value(input.secondaryText),
          summaryText: Value(input.summaryText),
          searchText: Value(input.searchText),
          note: Value(input.note),
          isFavorite: Value(input.isFavorite),
          isPinned: Value(input.isPinned),
          pinnedAt: Value(pinnedAt),
          sortOrder: Value(input.sortOrder),
          status: Value(input.status),
          deletedAt: Value(input.deletedAt),
          statusBeforeDeletion: Value(input.statusBeforeDeletion),
          updatedAt: Value(now),
          createdAt: Value(createdAtVal),
          metadata: Value(input.metadata),
        );
        await db.into(db.items).insertOnConflictUpdate(itemCompanion);

        // 3. Clear fields and attachments for this item
        await (db.delete(
          db.itemFields,
        )..where((tbl) => tbl.itemId.equals(itemId))).go();
        await (db.delete(
          db.attachments,
        )..where((tbl) => tbl.itemId.equals(itemId))).go();

        // 4. Batch insert fields
        for (final field in input.fields) {
          final fieldId = _generateUuid();
          await db
              .into(db.itemFields)
              .insert(
                ItemFieldsCompanion.insert(
                  id: fieldId,
                  itemId: itemId,
                  fieldKey: field.fieldKey,
                  valueType: field.valueType.toKey(),
                  valueText: Value(field.valueText),
                  normalizedValue: Value(field.normalizedValue),
                  fieldNote: Value(field.fieldNote),
                  sortOrder: Value(field.sortOrder),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }

        // 5. Batch insert attachments
        for (final att in input.attachments) {
          final attId = att.id ?? _generateUuid();
          await db
              .into(db.attachments)
              .insert(
                AttachmentsCompanion.insert(
                  id: attId,
                  originAttachmentId: att.originAttachmentId ?? attId,
                  itemId: itemId,
                  linkedFieldKey: Value(att.linkedFieldKey),
                  attachmentRole: att.attachmentRole,
                  fileName: att.fileName,
                  originalName: Value(att.originalName),
                  mimeType: att.mimeType,
                  plainSize: Value(att.plainSize),
                  encryptedSize: Value(att.encryptedSize),
                  sha256: Value(att.sha256),
                  sortOrder: Value(att.sortOrder),
                  status: const Value('active'),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        }
      }
    });
  }

  /// 读取成员唯一活跃身份证可复用的基础信息。
  ///
  /// 仅查询姓名、性别和出生日期；存在多份活跃身份证时不猜测来源。
  Future<Map<String, String>?> getSingleActiveIdentityProfile(
    String memberId,
  ) async {
    final identityCards =
        await (db.select(db.items)..where(
              (tbl) =>
                  tbl.memberId.equals(memberId) &
                  tbl.typeKey.equals('id_card') &
                  tbl.status.equals('active'),
            ))
            .get();
    if (identityCards.length != 1) return null;

    const profileKeys = {'name', 'gender', 'birth_date'};
    final fields =
        await (db.select(db.itemFields)..where(
              (tbl) =>
                  tbl.itemId.equals(identityCards.single.id) &
                  tbl.fieldKey.isIn(profileKeys),
            ))
            .get();
    final profile = <String, String>{};
    for (final field in fields) {
      final value = field.valueText?.trim() ?? '';
      if (value.isNotEmpty) {
        profile[field.fieldKey] = value;
      }
    }
    return profile.isEmpty ? null : Map.unmodifiable(profile);
  }

  /// 获取所有活跃资料按子类型 (type_key) 分组的条目数量 (用于分类首屏展示)
  Future<Map<String, int>> getActiveTypeCounts() async {
    final rows = await db
        .customSelect(
          'SELECT type_key, COUNT(*) as c FROM items WHERE status = ? AND type_key IS NOT NULL AND type_key != \'\' GROUP BY type_key',
          variables: [Variable.withString('active')],
        )
        .get();

    final Map<String, int> result = {};
    for (final row in rows) {
      final key = row.read<String>('type_key');
      final count = row.read<int>('c');
      result[key] = count;
    }
    return result;
  }

  /// 获取所有活跃资料按成员分组的数量，避免仅为统计而加载完整资料模型。
  Future<Map<String, int>> getActiveMemberCounts() async {
    final rows = await db
        .customSelect(
          'SELECT member_id, COUNT(*) AS c FROM items '
          'WHERE status = ? AND member_id IS NOT NULL AND member_id != \'\' '
          'GROUP BY member_id',
          variables: [Variable.withString('active')],
        )
        .get();
    return {
      for (final row in rows) row.read<String>('member_id'): row.read<int>('c'),
    };
  }

  /// 获取所有活跃资料按大类分组的数量，避免仅为统计而加载完整资料模型。
  Future<Map<String, int>> getActiveCategoryCounts() async {
    final rows = await db
        .customSelect(
          'SELECT category_key, COUNT(*) AS c FROM items '
          'WHERE status = ? AND category_key IS NOT NULL '
          'AND category_key != \'\' GROUP BY category_key',
          variables: [Variable.withString('active')],
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('category_key'): row.read<int>('c'),
    };
  }

  /// 查询指定资料下的所有子项及其子字段列表
  Future<List<ItemChildEntryModel>> getChildEntries(String itemId) async {
    final entries =
        await (db.select(db.itemChildEntries)
              ..where((tbl) => tbl.itemId.equals(itemId))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();

    if (entries.isEmpty) return const [];
    final fields =
        await (db.select(db.itemChildFields)
              ..where((tbl) => tbl.childEntryId.isIn(entries.map((e) => e.id)))
              ..orderBy([(tbl) => OrderingTerm(expression: tbl.sortOrder)]))
            .get();
    final fieldsByEntry = <String, List<ItemChildFieldModel>>{};
    for (final field in fields) {
      fieldsByEntry
          .putIfAbsent(field.childEntryId, () => [])
          .add(
            ItemChildFieldModel(
              id: field.id,
              childEntryId: field.childEntryId,
              fieldKey: field.fieldKey,
              label: field.label,
              valueText: field.valueText,
              valueType: field.valueType,
              sensitiveLevel: field.sensitiveLevel,
              copyable: field.copyable,
              searchable: field.searchable,
              summary: field.summary,
              sortOrder: field.sortOrder,
              createdAt: field.createdAt,
              updatedAt: field.updatedAt,
            ),
          );
    }
    return entries
        .map(
          (entry) => ItemChildEntryModel(
            id: entry.id,
            itemId: entry.itemId,
            childType: entry.childType,
            sortOrder: entry.sortOrder,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            fields: fieldsByEntry[entry.id] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  /// 删除单个子项，因外键关联这会自动删除该子项下所有子字段
  Future<void> deleteChildEntry(String childEntryId) async {
    await (db.delete(
      db.itemChildEntries,
    )..where((tbl) => tbl.id.equals(childEntryId))).go();
  }

  ItemFieldModel _mapField(ItemField f, {bool forceLegacy = false}) {
    return ItemFieldModel(
      id: f.id,
      itemId: f.itemId,
      fieldKey: f.fieldKey,
      valueType: f.valueType,
      valueText: f.valueText,
      normalizedValue: f.normalizedValue,
      fieldNote: f.fieldNote,
      templateFieldKnown: true,
      isArchivedField: false,
      archivedReason: null,
      rawFieldLabel: forceLegacy ? null : f.rawFieldLabel,
      sortOrder: f.sortOrder,
      createdAt: f.createdAt,
      updatedAt: f.updatedAt,
    );
  }

  AttachmentModel _mapAttachment(Attachment a) {
    return AttachmentModel(
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
      status: a.status,
      createdAt: a.createdAt,
      updatedAt: a.updatedAt,
    );
  }

  String? _extractRepaymentDay(List<ItemFieldModel> fields) {
    for (final f in fields) {
      if (f.fieldKey == 'repayment_day') {
        return f.valueText;
      }
    }
    return null;
  }

  ItemWithFields _buildItemWithFields(
    Item item,
    List<ItemFieldModel> fields,
    List<AttachmentModel> attachments,
  ) {
    return ItemWithFields(
      id: item.id,
      originId: item.originId,
      memberId: item.memberId,
      categoryKey: item.categoryKey,
      typeKey: item.typeKey,
      templateVersion: item.templateVersion,
      title: item.title,
      primaryText: item.primaryText,
      secondaryText: item.secondaryText,
      summaryText: item.summaryText,
      searchText: item.searchText,
      repaymentDay: _extractRepaymentDay(fields),
      note: item.note,
      isFavorite: item.isFavorite,
      isPinned: item.isPinned,
      pinnedAt: item.pinnedAt,
      sortOrder: item.sortOrder,
      status: item.status,
      deletedAt: item.deletedAt,
      statusBeforeDeletion: item.statusBeforeDeletion,
      createdAt: item.createdAt,
      updatedAt: item.updatedAt,
      lastViewedAt: item.lastViewedAt,
      fields: fields,
      attachments: attachments,
      metadata: item.metadata,
      validationWarnings: _parseWarnings(item.metadata),
    );
  }
}
