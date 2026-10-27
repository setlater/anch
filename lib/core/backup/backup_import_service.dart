import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../attachment/attachment_payload_reader.dart';
import '../attachment/attachment_preview_cache.dart';
import '../attachment/attachment_thumbnail_cache.dart';
import '../database/app_database.dart';
import '../repository/member_repository.dart';
import '../template/field_value_type.dart';
import '../template/sensitive_level.dart';
import '../template/template_registry.dart';
import 'attachment_restore_recovery_service.dart';
import 'backup_envelope.dart';
import 'backup_payload.dart';
import 'backup_payload_migration_service.dart';
import 'backup_crypto.dart';
import 'backup_v2_attachment_directory_staging.dart';

/// 导入恢复异常类。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类实例的 [toString] 或是抛出的 [message]，**绝对严禁**包含用户的明文密码、派生的加密 key、
///    `TEST-*` 假数据明文、完整密文串、完整 payload、JSON 串或任何底层异常堆栈原文，以防敏感信息泄漏。
class BackupImportException implements Exception {
  final BackupImportErrorType type;
  final String message;

  BackupImportException(this.type, this.message);

  @override
  String toString() => 'BackupImportException[${type.name}]: $message';
}

/// 导入恢复异常分类。
enum BackupImportErrorType {
  invalidPayload,
  unsupportedSchemaVersion,
  missingSystemMember,
  missingMemberReference,
  missingItemReference,
  duplicatedId,
  databaseWriteFailed,
  invalidPasswordOrCorruptedData,
  unknown,
}

/// 导入恢复摘要结果。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本类仅用于向外部返回导入成功的度量指标与时间戳。
/// 2. 绝对禁止包含任何敏感字段值、资料标题、成员名称、密码或备份原文。
class BackupImportResult {
  final int restoredMembersCount;
  final int restoredItemsCount;
  final int restoredItemFieldsCount;
  final int restoredAppSettingsCount;
  final int restoredAt;

  BackupImportResult({
    required this.restoredMembersCount,
    required this.restoredItemsCount,
    required this.restoredItemFieldsCount,
    required this.restoredAppSettingsCount,
    required this.restoredAt,
  });
}

class _AttachmentRestoreStage {
  final Directory liveDirectory;
  final Directory stagingDirectory;
  final Directory rollbackDirectory;
  final AttachmentRestoreRecoveryService recoveryService;
  final String token;
  bool _movedLiveDirectory = false;
  bool _activated = false;

  _AttachmentRestoreStage({
    required this.liveDirectory,
    required this.stagingDirectory,
    required this.rollbackDirectory,
    required this.recoveryService,
    required this.token,
  });

  Future<void> activate() async {
    if (await liveDirectory.exists()) {
      await liveDirectory.rename(rollbackDirectory.path);
      _movedLiveDirectory = true;
    }
    try {
      await stagingDirectory.rename(liveDirectory.path);
      _activated = true;
    } catch (_) {
      if (_movedLiveDirectory && await rollbackDirectory.exists()) {
        await rollbackDirectory.rename(liveDirectory.path);
        _movedLiveDirectory = false;
      }
      rethrow;
    }
  }

  Future<void> rollback() async {
    if (_activated && await liveDirectory.exists()) {
      await liveDirectory.delete(recursive: true);
    }
    if (_movedLiveDirectory && await rollbackDirectory.exists()) {
      await rollbackDirectory.rename(liveDirectory.path);
    }
    if (await stagingDirectory.exists()) {
      await stagingDirectory.delete(recursive: true);
    }
    await recoveryService.deleteJournalIfExists();
  }

  Future<void> commit() async {
    if (await rollbackDirectory.exists()) {
      await rollbackDirectory.delete(recursive: true);
    }
    await recoveryService.deleteJournalIfExists();
  }
}

class _HistoricalAttachmentNotRecoverable implements Exception {
  const _HistoricalAttachmentNotRecoverable();
}

/// 导入恢复最小内存级服务。
///
/// 职责：
/// 1. 接收密文信封与密码，在内存中完成解密。
/// 2. 对明文 payload 做严格的前置完整性及依赖规则校验。
/// 3. 在数据库事务中以正确的依赖顺序覆盖写入，并在失败时自动回滚。
class BackupImportService {
  final AppDatabase database;
  final Future<Directory> Function()? documentsDirectoryProvider;

  BackupImportService({
    required this.database,
    this.documentsDirectoryProvider,
  });

  /// 执行解密、校验并在数据库事务中覆盖恢复数据。
  ///
  /// 若解密、附件准备或写入发生任何失败，保留原数据库与原附件目录。
  Future<BackupImportResult> restoreFromEnvelope({
    required BackupEnvelopeV1 envelope,
    required String backupPassword,
  }) {
    return _restorePayload(envelope: envelope, backupPassword: backupPassword);
  }

  Future<BackupImportResult> _restorePayload({
    BackupEnvelopeV1? envelope,
    String? backupPassword,
    BackupPayloadV1? preparedPayload,
    _AttachmentRestoreStage? preparedAttachmentStage,
  }) async {
    // 1. V1 调用解密服务；V2 只会传入已经逐帧认证完成的临时 payload。
    final BackupPayloadV1 decryptedPayload;
    if (preparedPayload != null) {
      decryptedPayload = preparedPayload;
    } else {
      if (envelope == null || backupPassword == null) {
        throw BackupImportException(
          BackupImportErrorType.invalidPasswordOrCorruptedData,
          '备份密码错误或数据已损坏',
        );
      }
      try {
        decryptedPayload = await BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: backupPassword,
        );
      } on BackupCryptoException catch (e) {
        if (e.type == BackupCryptoErrorType.emptyPassword) {
          throw BackupImportException(
            BackupImportErrorType.invalidPasswordOrCorruptedData,
            '备份密码不能为空',
          );
        }
        throw BackupImportException(
          BackupImportErrorType.invalidPasswordOrCorruptedData,
          '备份密码错误或数据已损坏',
        );
      } catch (_) {
        throw BackupImportException(
          BackupImportErrorType.invalidPasswordOrCorruptedData,
          '解密失败，备份密码错误或密文不合法',
        );
      }
    }

    final BackupPayloadV1 payload;
    try {
      payload = BackupPayloadMigrationService.migrateToSchema(
        decryptedPayload,
        targetSchemaVersion: database.schemaVersion,
      );
    } on BackupPayloadMigrationException {
      throw BackupImportException(
        BackupImportErrorType.unsupportedSchemaVersion,
        '备份的数据库版本高于当前 App 版本，无法执行恢复',
      );
    }

    // 2. 校验迁移后的 payload 数据合法性与完整性
    _validatePayload(payload);

    final existingAttachments = await database
        .select(database.attachments)
        .get();
    final hasAttachments =
        existingAttachments.isNotEmpty || payload.data.attachments.isNotEmpty;
    final attachmentStage =
        preparedAttachmentStage ??
        (hasAttachments ? await _prepareAttachmentStage(payload) : null);

    // 3. 先切换已校验完成的附件目录，再在数据库事务中执行覆盖恢复。
    // 若事务失败，立即恢复旧目录；事务成功后才删除旧目录。
    try {
      await attachmentStage?.activate();

      await database.transaction(() async {
        // a. 按逆向依赖顺序删除旧数据。
        await database.delete(database.itemChildFields).go();
        await database.delete(database.itemChildEntries).go();
        await database.delete(database.itemEventChanges).go();
        await database.delete(database.itemEvents).go();
        await database.delete(database.attachments).go();
        await database.delete(database.itemFields).go();
        await database.delete(database.items).go();
        await database.delete(database.members).go();

        // TODO: appSettings 未来可恢复范围的处理。本批次暂不写入 app_settings，也不清空 app_settings

        // b. 按正向依赖顺序插入新数据 (保留备份中原 id、createdAt、updatedAt、title 等属性)
        // 1) 插入 members
        for (final m in payload.data.members) {
          final String resolvedMemberType = (m.id == systemFamilyMemberId)
              ? 'family'
              : 'person';
          await database
              .into(database.members)
              .insert(
                MembersCompanion.insert(
                  id: m.id,
                  memberType: resolvedMemberType,
                  name: m.name,
                  isSystem: Value(m.isSystem),
                  sortOrder: Value(m.sortOrder),
                  createdAt: m.createdAt,
                  updatedAt: m.updatedAt,
                  note: Value(m.note),
                  isArchived: Value(m.isArchived),
                  avatarKey: const Value(null),
                ),
              );
        }

        // 2) 插入 items
        for (final item in payload.data.items) {
          await database
              .into(database.items)
              .insert(
                ItemsCompanion.insert(
                  id: item.id,
                  originId: item.originId,
                  memberId: Value(item.memberId),
                  categoryKey: Value(item.categoryKey),
                  typeKey: Value(item.typeKey),
                  templateVersion: Value(item.templateVersion),
                  title: Value(item.title),
                  primaryText: Value(item.primaryText),
                  secondaryText: Value(item.secondaryText),
                  summaryText: Value(item.summaryText),
                  searchText: Value(item.searchText),
                  note: Value(item.note),
                  isFavorite: Value(item.isFavorite),
                  isPinned: Value(item.isPinned),
                  pinnedAt: Value(
                    item.isPinned ? (item.pinnedAt ?? item.updatedAt) : null,
                  ),
                  sortOrder: Value(item.sortOrder),
                  status: Value(item.status),
                  deletedAt: Value(item.deletedAt),
                  statusBeforeDeletion: Value(item.statusBeforeDeletion),
                  createdAt: item.createdAt,
                  updatedAt: item.updatedAt,
                  lastViewedAt: const Value(null),
                ),
              );
        }

        // 3) 插入 item_fields
        for (final field in payload.data.itemFields) {
          await database
              .into(database.itemFields)
              .insert(
                ItemFieldsCompanion.insert(
                  id: field.id,
                  itemId: field.itemId,
                  fieldKey: field.fieldKey,
                  valueType: field.valueType,
                  valueText: Value(field.valueText),
                  normalizedValue: Value(field.normalizedValue),
                  fieldNote: Value(field.fieldNote),
                  sortOrder: Value(field.sortOrder),
                  createdAt: field.createdAt,
                  updatedAt: field.updatedAt,
                ),
              );
        }

        // 4) 插入已写入 staging 目录的附件元数据。
        for (final att in payload.data.attachments) {
          await database
              .into(database.attachments)
              .insert(
                AttachmentsCompanion.insert(
                  id: att.id,
                  originAttachmentId: att.originAttachmentId,
                  itemId: att.itemId,
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
                  createdAt: att.createdAt,
                  updatedAt: att.updatedAt,
                ),
              );
        }

        for (final event in payload.data.itemEvents) {
          await database
              .into(database.itemEvents)
              .insert(
                ItemEventsCompanion.insert(
                  id: event.id,
                  itemId: event.itemId,
                  eventType: event.eventType,
                  occurredAt: event.occurredAt,
                ),
              );
        }

        for (final change in payload.data.itemEventChanges) {
          await database
              .into(database.itemEventChanges)
              .insert(
                ItemEventChangesCompanion.insert(
                  id: change.id,
                  eventId: change.eventId,
                  changeKind: change.changeKind,
                  subjectKey: change.subjectKey,
                  subjectLabel: change.subjectLabel,
                  oldValue: Value(change.oldValue),
                  newValue: Value(change.newValue),
                  sortOrder: Value(change.sortOrder),
                ),
              );
        }

        // 5) 插入 childEntries
        for (final entry in payload.data.childEntries) {
          await database
              .into(database.itemChildEntries)
              .insert(
                ItemChildEntriesCompanion.insert(
                  id: entry.id,
                  itemId: entry.itemId,
                  childType: entry.childType,
                  sortOrder: Value(entry.sortOrder),
                  createdAt: entry.createdAt,
                  updatedAt: entry.updatedAt,
                ),
              );
        }

        // 6) 插入 childFields
        for (final field in payload.data.childFields) {
          await database
              .into(database.itemChildFields)
              .insert(
                ItemChildFieldsCompanion.insert(
                  id: field.id,
                  childEntryId: field.childEntryId,
                  fieldKey: field.fieldKey,
                  label: field.label,
                  valueText: Value(field.valueText),
                  valueType: field.valueType,
                  sensitiveLevel: field.sensitiveLevel,
                  copyable: Value(field.copyable),
                  searchable: Value(field.searchable),
                  summary: Value(field.summary),
                  sortOrder: Value(field.sortOrder),
                  createdAt: field.createdAt,
                  updatedAt: field.updatedAt,
                ),
              );
        }

        await MemberRepository(database).ensureSystemMembersExist();
        if (attachmentStage != null) {
          await database
              .into(database.appSettings)
              .insertOnConflictUpdate(
                AppSettingsCompanion.insert(
                  key: attachmentRestoreOperationSettingKey,
                  value: Value(attachmentStage.token),
                  valueType: 'internal',
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );
        }
      });
    } catch (_) {
      await attachmentStage?.rollback();
      throw BackupImportException(
        BackupImportErrorType.databaseWriteFailed,
        '覆盖恢复写入数据库失败，事务已安全回滚',
      );
    }

    if (attachmentStage != null) {
      try {
        await attachmentStage.commit();
        await (database.delete(database.appSettings)..where(
              (table) =>
                  table.key.equals(attachmentRestoreOperationSettingKey) &
                  table.value.equals(attachmentStage.token),
            ))
            .go();
      } catch (_) {
        // 数据库已提交。清理失败时保留日志与提交标记，下次启动仍按已提交恢复处理。
      }
    }

    // 预览缓存不属于备份内容。恢复成功后清空旧缓存，避免它与新附件错配。
    try {
      await AttachmentPreviewCache.clearAll(
        documentsDirectoryProvider: documentsDirectoryProvider,
      );
      await AttachmentThumbnailCache.clearAll(
        documentsDirectoryProvider: documentsDirectoryProvider,
      );
    } catch (_) {
      // 缓存不影响资料完整性；私有目录极端清理失败不应把已提交恢复误报为失败。
    }

    // 4. 返回恢复摘要信息
    return BackupImportResult(
      restoredMembersCount: payload.data.members.length,
      restoredItemsCount: payload.data.items.length,
      restoredItemFieldsCount: payload.data.itemFields.length,
      restoredAppSettingsCount: payload.data.appSettings.length,
      restoredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// 应用 V2 已认证完成的 payload 和附件 staging。
  ///
  /// V2 的附件已经逐帧写入新的私有 staging 目录；本方法只在迁移与载荷校验通过后将其移交给既有附件目录原子
  /// 切换和数据库事务，不回读为 Base64，也不重新进入 V1 内存容器。
  Future<BackupImportResult> restoreFromV2PreparedPayload({
    required BackupPayloadV1 payload,
    required BackupV2AttachmentDirectoryStaging attachmentStaging,
  }) async {
    final BackupPayloadV1 migratedPayload;
    try {
      migratedPayload = BackupPayloadMigrationService.migrateToSchema(
        payload,
        targetSchemaVersion: database.schemaVersion,
      );
    } on BackupPayloadMigrationException {
      await attachmentStaging.abort();
      throw BackupImportException(
        BackupImportErrorType.unsupportedSchemaVersion,
        '备份的数据库版本高于当前 App 版本，无法执行恢复',
      );
    }
    try {
      _validatePayload(migratedPayload);
    } on BackupImportException {
      await attachmentStaging.abort();
      rethrow;
    }

    final existingAttachments = await database
        .select(database.attachments)
        .get();
    final hasAttachments =
        existingAttachments.isNotEmpty ||
        migratedPayload.data.attachments.isNotEmpty;
    if (!hasAttachments) {
      await attachmentStaging.abort();
      return _restorePayload(preparedPayload: migratedPayload);
    }

    final directory = await attachmentStaging.takeDirectoryForRestore();
    final stage = await _prepareAttachmentStageFromV2Directory(
      migratedPayload,
      directory,
    );
    return _restorePayload(
      preparedPayload: migratedPayload,
      preparedAttachmentStage: stage,
    );
  }

  Future<_AttachmentRestoreStage> _prepareAttachmentStage(
    BackupPayloadV1 payload,
  ) async {
    final docDir =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final liveDirectory = Directory(p.join(docDir.path, 'attachments'));
    final stagingDirectory = Directory(
      p.join(docDir.path, '.attachments-restore-staging-$token'),
    );
    final rollbackDirectory = Directory(
      p.join(docDir.path, '.attachments-restore-rollback-$token'),
    );
    final recoveryService = AttachmentRestoreRecoveryService(
      database: database,
      documentsDirectoryProvider: documentsDirectoryProvider,
    );
    final stage = _AttachmentRestoreStage(
      liveDirectory: liveDirectory,
      stagingDirectory: stagingDirectory,
      rollbackDirectory: rollbackDirectory,
      recoveryService: recoveryService,
      token: token,
    );

    try {
      await recoveryService.writePreparedJournal(token);
      await stagingDirectory.create();
      final fileNames = <String>{};
      for (final attachment in payload.data.attachments) {
        final fileName = attachment.fileName;
        if (fileName.isEmpty ||
            fileName == '.' ||
            fileName == '..' ||
            fileName.contains('/') ||
            fileName.contains('\\') ||
            !fileNames.add(fileName)) {
          throw const FormatException();
        }

        final bytes = base64Url.decode(attachment.encryptedData);
        if (bytes.length != attachment.encryptedSize) {
          throw const FormatException();
        }

        final file = File(p.join(stagingDirectory.path, fileName));
        await file.writeAsBytes(bytes, flush: true);
        if (await file.length() != bytes.length) {
          throw const FileSystemException();
        }
        try {
          await AttachmentPayloadReader.validatePathInBackground(
            file.path,
            expectedPlainSize: attachment.plainSize,
          );
        } catch (_) {
          throw const _HistoricalAttachmentNotRecoverable();
        }
      }
      return stage;
    } on _HistoricalAttachmentNotRecoverable {
      await stage.rollback();
      throw BackupImportException(
        BackupImportErrorType.invalidPayload,
        '此历史备份中的附件无法在当前设备恢复，原数据未改动',
      );
    } on FormatException {
      await stage.rollback();
      throw BackupImportException(
        BackupImportErrorType.invalidPayload,
        '备份附件数据校验失败',
      );
    } catch (_) {
      await stage.rollback();
      throw BackupImportException(
        BackupImportErrorType.databaseWriteFailed,
        '备份附件暂存失败，原数据未改动',
      );
    }
  }

  Future<_AttachmentRestoreStage> _prepareAttachmentStageFromV2Directory(
    BackupPayloadV1 payload,
    Directory sourceDirectory,
  ) async {
    final docDir =
        await (documentsDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    final token = DateTime.now().microsecondsSinceEpoch.toString();
    final stage = _AttachmentRestoreStage(
      liveDirectory: Directory(p.join(docDir.path, 'attachments')),
      stagingDirectory: Directory(
        p.join(docDir.path, '.attachments-restore-staging-$token'),
      ),
      rollbackDirectory: Directory(
        p.join(docDir.path, '.attachments-restore-rollback-$token'),
      ),
      recoveryService: AttachmentRestoreRecoveryService(
        database: database,
        documentsDirectoryProvider: documentsDirectoryProvider,
      ),
      token: token,
    );

    try {
      final names = <String>{};
      for (final attachment in payload.data.attachments) {
        final fileName = attachment.fileName;
        if (fileName.isEmpty ||
            fileName == '.' ||
            fileName == '..' ||
            fileName.contains('/') ||
            fileName.contains('\\') ||
            !names.add(fileName)) {
          throw const FormatException();
        }
        final file = File(p.join(sourceDirectory.path, fileName));
        if (!await file.exists() ||
            await file.length() != attachment.encryptedSize) {
          throw const FormatException();
        }
      }
      await sourceDirectory.rename(stage.stagingDirectory.path);
      await stage.recoveryService.writePreparedJournal(token);
      return stage;
    } on FormatException {
      await stage.rollback();
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
      throw BackupImportException(
        BackupImportErrorType.invalidPayload,
        '备份附件数据校验失败',
      );
    } catch (_) {
      await stage.rollback();
      if (await sourceDirectory.exists()) {
        await sourceDirectory.delete(recursive: true);
      }
      throw BackupImportException(
        BackupImportErrorType.databaseWriteFailed,
        '备份附件暂存失败，原数据未改动',
      );
    }
  }

  /// 严密的前置校验逻辑。
  void _validatePayload(BackupPayloadV1 payload) {
    // 1. 基础校验
    if (payload.format != 'anch.backup.payload') {
      throw BackupImportException(
        BackupImportErrorType.invalidPayload,
        '备份数据格式不受支持',
      );
    }
    if (payload.version != 1) {
      throw BackupImportException(
        BackupImportErrorType.invalidPayload,
        '备份数据版本不受支持',
      );
    }
    if (payload.schemaVersion > database.schemaVersion) {
      throw BackupImportException(
        BackupImportErrorType.unsupportedSchemaVersion,
        '备份的数据库版本高于当前 App 版本，无法执行恢复',
      );
    }

    // 2. ID 重复性校验
    final memberIds = <String>{};
    for (final m in payload.data.members) {
      if (!memberIds.add(m.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的成员记录 ID',
        );
      }
    }

    final itemIds = <String>{};
    final itemOriginIds = <String>{};
    for (final item in payload.data.items) {
      if (!itemIds.add(item.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的资料条目 ID',
        );
      }
      if (item.originId.isEmpty || !itemOriginIds.add(item.originId)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在无效或重复的资料来源标识',
        );
      }
      if (!const {'active', 'archived', 'deleted'}.contains(item.status)) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中存在不支持的资料状态',
        );
      }
      if ((item.status == 'deleted') != (item.deletedAt != null)) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中的最近删除状态不完整',
        );
      }
      if ((item.status == 'deleted') != (item.statusBeforeDeletion != null) ||
          (item.statusBeforeDeletion != null &&
              !const {
                'active',
                'archived',
              }.contains(item.statusBeforeDeletion))) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中的删除前收纳状态不完整',
        );
      }
    }

    final fieldIds = <String>{};
    for (final field in payload.data.itemFields) {
      if (!fieldIds.add(field.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的字段记录 ID',
        );
      }
    }

    final settingKeys = <String>{};
    for (final setting in payload.data.appSettings) {
      if (!settingKeys.add(setting.key)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的设置项 Key',
        );
      }
    }

    final attachmentIds = <String>{};
    final attachmentOriginIds = <String>{};
    for (final att in payload.data.attachments) {
      if (!attachmentIds.add(att.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的附件记录 ID',
        );
      }
      if (att.originAttachmentId.isEmpty ||
          !attachmentOriginIds.add(att.originAttachmentId)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在无效或重复的附件来源标识',
        );
      }
    }

    final childEntryIds = <String>{};
    for (final entry in payload.data.childEntries) {
      if (!childEntryIds.add(entry.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的子项记录 ID',
        );
      }
    }

    final childFieldIds = <String>{};
    for (final field in payload.data.childFields) {
      if (!childFieldIds.add(field.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的子项字段记录 ID',
        );
      }
    }

    final itemEventIds = <String>{};
    final eventsById = <String, BackupItemEventV1>{};
    for (final event in payload.data.itemEvents) {
      if (!itemEventIds.add(event.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的资料事件 ID',
        );
      }
      if (!const {
        'created',
        'updated',
        'archived',
        'unarchived',
        'moved_to_trash',
        'restored',
        'imported',
      }.contains(event.eventType)) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中存在不支持的资料事件类型',
        );
      }
      eventsById[event.id] = event;
    }
    final itemsById = {for (final item in payload.data.items) item.id: item};
    final itemEventChangeIds = <String>{};
    for (final change in payload.data.itemEventChanges) {
      if (!itemEventChangeIds.add(change.id)) {
        throw BackupImportException(
          BackupImportErrorType.duplicatedId,
          '备份数据中存在重复的资料事件变更 ID',
        );
      }
      if (!const {
        'value_changed',
        'field_changed',
        'attachment_count_changed',
      }.contains(change.changeKind)) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中存在不支持的资料事件变更类型',
        );
      }
      if (change.subjectKey.trim().isEmpty ||
          change.subjectLabel.trim().isEmpty) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中的资料事件变更主题不完整',
        );
      }
      final valuesMustBeAbsent = change.changeKind == 'field_changed';
      final valuesRequired = change.changeKind != 'field_changed';
      final removedCount = int.tryParse(change.oldValue ?? '');
      final addedCount = int.tryParse(change.newValue ?? '');
      final countsRequired = change.changeKind == 'attachment_count_changed';
      if ((valuesMustBeAbsent &&
              (change.oldValue != null || change.newValue != null)) ||
          (valuesRequired &&
              (change.oldValue == null || change.newValue == null)) ||
          (countsRequired &&
              (removedCount == null ||
                  addedCount == null ||
                  removedCount < 0 ||
                  addedCount < 0))) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中的资料事件变更值不符合类型约束',
        );
      }
      if (change.changeKind == 'value_changed' &&
          !_mayRestoreEventValues(change, eventsById, itemsById)) {
        throw BackupImportException(
          BackupImportErrorType.invalidPayload,
          '备份数据中的资料事件变更不允许保留历史值',
        );
      }
    }

    // 3. 系统内置家庭虚拟成员存在性校验
    final hasSystemFamily = payload.data.members.any(
      (m) => m.id == systemFamilyMemberId && m.isSystem == true,
    );
    if (!hasSystemFamily) {
      throw BackupImportException(
        BackupImportErrorType.missingSystemMember,
        '备份数据中缺失系统保留家庭虚拟成员，拒绝恢复',
      );
    }

    // 4. 引用完整性/外键约束校验
    // 所有 item.memberId 必须在 members 中存在 (若不为 null)
    for (final item in payload.data.items) {
      if (item.memberId != null && !memberIds.contains(item.memberId)) {
        throw BackupImportException(
          BackupImportErrorType.missingMemberReference,
          '资料条目引用的家庭成员在备份数据中不存在',
        );
      }
    }

    // 所有 itemField.itemId 必须在 items 中存在
    for (final field in payload.data.itemFields) {
      if (!itemIds.contains(field.itemId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '资料属性字段引用的条目在备份数据中不存在',
        );
      }
    }

    for (final event in payload.data.itemEvents) {
      if (!itemIds.contains(event.itemId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '资料事件引用的条目在备份数据中不存在',
        );
      }
    }
    for (final change in payload.data.itemEventChanges) {
      if (!itemEventIds.contains(change.eventId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '资料事件变更引用的事件不存在',
        );
      }
    }

    // 所有 attachment.itemId 必须在 items 中存在
    for (final att in payload.data.attachments) {
      if (!itemIds.contains(att.itemId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '附件引用的资料条目在备份数据中不存在',
        );
      }
    }

    // 所有 childEntry.itemId 必须在 items 中存在
    for (final entry in payload.data.childEntries) {
      if (!itemIds.contains(entry.itemId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '资料子项引用的条目在备份数据中不存在',
        );
      }
    }

    // 所有 childField.childEntryId 必须在 childEntries 中存在
    for (final field in payload.data.childFields) {
      if (!childEntryIds.contains(field.childEntryId)) {
        throw BackupImportException(
          BackupImportErrorType.missingItemReference,
          '资料子属性引用的子项在备份数据中不存在',
        );
      }
    }
  }

  bool _mayRestoreEventValues(
    BackupItemEventChangeV1 change,
    Map<String, BackupItemEventV1> eventsById,
    Map<String, BackupItemV1> itemsById,
  ) {
    if (const {
      'member_id',
      'category_key',
      'type_key',
      'is_favorite',
      'is_pinned',
      'status',
    }.contains(change.subjectKey)) {
      return true;
    }
    final event = eventsById[change.eventId];
    final item = event == null ? null : itemsById[event.itemId];
    if (item?.typeKey == null) return false;
    final template = TemplateRegistry.getTemplate(
      item!.typeKey!,
      item.templateVersion,
    );
    if (template == null) return false;
    for (final field in template.fields) {
      if (field.fieldKey != change.subjectKey) continue;
      final lowSensitivity =
          field.sensitiveLevel == SensitiveLevel.none ||
          field.sensitiveLevel == SensitiveLevel.low;
      final safeDateType = const {
        FieldValueType.date,
        FieldValueType.monthDay,
        FieldValueType.dayOfMonth,
      }.contains(field.valueType);
      return lowSensitivity && safeDateType;
    }
    return false;
  }
}
