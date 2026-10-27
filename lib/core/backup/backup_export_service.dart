import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../attachment/attachment_payload_reader.dart';
import '../repository/item_repository.dart';
import '../repository/member_repository.dart';
import 'backup_payload.dart';
import 'backup_payload_mapper.dart';
import 'backup_crypto.dart';
import 'backup_unavailable_attachment.dart';
import 'backup_envelope.dart';
import 'backup_v2_format.dart';

/// 备份导出上下文元数据类。
///
/// 用于提供环境信息（如 App 版本、平台等），避免服务内部硬编码。
class BackupExportMetadata {
  final String appVersion;
  final int schemaVersion;
  final String appId;
  final String platform;
  final String? locale;

  BackupExportMetadata({
    required this.appVersion,
    required this.schemaVersion,
    required this.appId,
    required this.platform,
    this.locale,
  });
}

/// 导出备份最小内存级服务。
///
/// 职责：
/// 1. 从 Repository 层读取当前可备份的全部成员及资料数据。
/// 2. 在内存中将业务实体映射转换为规范化排序后的 [BackupPayloadV1]。
/// 3. 使用密码学服务对其进行派生密码加密并返回 [BackupEnvelopeV1]。
///
/// ⚠️ 【安全边界】
/// 1. 本服务只返回内存对象（如 Envelope、JSON 字符串、或二进制字节数组），**绝不执行**任何物理磁盘 file 读取、写入或生成真实 `.abk` 包的操作。
/// 2. 本服务的所有逻辑中，**绝对严禁**使用 `print`、`logger` 或 `debugPrint` 打印备份密码、派生 key、[BackupPayloadV1] 明文及完整的超长密文。
class BackupExportService {
  final ItemRepository itemRepository;
  final MemberRepository memberRepository;
  final BackupExportMetadata metadata;

  BackupExportService({
    required this.itemRepository,
    required this.memberRepository,
    required this.metadata,
  });

  /// 为可移植流式备份准备资料 manifest 与附件来源。
  ///
  /// 与 V1 的内存 Base64 载荷不同，导出器只在写入对应附件帧时读取单个附件；附件在临时 isolate 解密后立即
  /// 交给备份密码保护的分帧容器，绝不将明文写入磁盘。任一附件缺失或长度不一致都必须整体失败，禁止静默省略。
  Future<BackupV2ExportPlan> prepareStreamingV2Export({
    int? nowMillisForTest,
  }) async {
    final members = await memberRepository.getAllMembers();
    final itemsWithFields = await itemRepository
        .getAllItemsWithFieldsForBackup();
    Directory? attachmentsDir;

    final backupMembers = members
        .map(BackupPayloadMapper.toBackupMember)
        .toList();
    final backupItems = <BackupItemV1>[];
    final backupItemFields = <BackupItemFieldV1>[];
    final backupAttachments = <BackupAttachmentV1>[];
    final attachmentSourcesById = <String, BackupV2AttachmentSource>{};
    final unavailableAttachments = <BackupUnavailableAttachment>[];

    for (final item in itemsWithFields) {
      backupItems.add(BackupPayloadMapper.toBackupItemFromFields(item));
      for (final field in item.fields) {
        backupItemFields.add(BackupPayloadMapper.toBackupItemField(field));
      }
      for (final attachment in item.attachments) {
        attachmentsDir ??= Directory(
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'attachments',
          ),
        );
        final file = File(p.join(attachmentsDir.path, attachment.fileName));
        BackupUnavailableAttachmentReason? unavailableReason;
        try {
          if (!await file.exists()) {
            unavailableReason = BackupUnavailableAttachmentReason.fileMissing;
          } else if (await file.length() != attachment.encryptedSize) {
            unavailableReason = BackupUnavailableAttachmentReason.sizeMismatch;
          }
        } catch (_) {
          unavailableReason = BackupUnavailableAttachmentReason.fileUnreadable;
        }
        if (unavailableReason != null) {
          unavailableAttachments.add(
            BackupUnavailableAttachment(
              itemId: item.id,
              itemTitle: item.title,
              originalName: attachment.originalName,
              reason: unavailableReason,
            ),
          );
          continue;
        }

        final backupAttachment = BackupPayloadMapper.toBackupAttachment(
          attachment,
          '',
        );
        if (attachmentSourcesById.containsKey(backupAttachment.id)) {
          unavailableAttachments.add(
            BackupUnavailableAttachment(
              itemId: item.id,
              itemTitle: item.title,
              originalName: attachment.originalName,
              reason: BackupUnavailableAttachmentReason.metadataInconsistent,
            ),
          );
          continue;
        }
        backupAttachments.add(backupAttachment);
        attachmentSourcesById[backupAttachment.id] = BackupV2AttachmentSource(
          attachment: backupAttachment,
          payloadSize: backupAttachment.plainSize,
          openPayloadStream: () => _openPortablePlaintextStream(
            file.path,
            expectedPlainSize: backupAttachment.plainSize,
          ),
        );
      }
    }
    if (unavailableAttachments.isNotEmpty) {
      throw BackupV2FormatException(
        BackupV2FormatErrorType.sourceUnavailable,
        '备份附件读取不完整，未生成可用备份。',
        unavailableAttachments: unavailableAttachments,
      );
    }

    final dbChildEntries = await itemRepository.db
        .select(itemRepository.db.itemChildEntries)
        .get();
    final dbChildFields = await itemRepository.db
        .select(itemRepository.db.itemChildFields)
        .get();
    final dbItemEvents = await itemRepository.db
        .select(itemRepository.db.itemEvents)
        .get();
    final dbItemEventChanges = await itemRepository.db
        .select(itemRepository.db.itemEventChanges)
        .get();

    final backupChildEntries = dbChildEntries
        .map(
          (entry) => BackupItemChildEntryV1(
            id: entry.id,
            itemId: entry.itemId,
            childType: entry.childType,
            sortOrder: entry.sortOrder,
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
          ),
        )
        .toList();
    final backupChildFields = dbChildFields
        .map(
          (field) => BackupItemChildFieldV1(
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
        )
        .toList();
    final backupItemEvents = dbItemEvents
        .map(
          (event) => BackupItemEventV1(
            id: event.id,
            itemId: event.itemId,
            eventType: event.eventType,
            occurredAt: event.occurredAt,
          ),
        )
        .toList();
    final backupItemEventChanges = dbItemEventChanges
        .map(
          (change) => BackupItemEventChangeV1(
            id: change.id,
            eventId: change.eventId,
            changeKind: change.changeKind,
            subjectKey: change.subjectKey,
            subjectLabel: change.subjectLabel,
            oldValue: change.oldValue,
            newValue: change.newValue,
            sortOrder: change.sortOrder,
          ),
        )
        .toList();

    final payload = BackupPayloadV1(
      exportedAt: nowMillisForTest ?? DateTime.now().millisecondsSinceEpoch,
      appVersion: metadata.appVersion,
      schemaVersion: metadata.schemaVersion,
      source: BackupSourceInfo(
        appId: metadata.appId,
        platform: metadata.platform,
        locale: metadata.locale,
        exportMode: 'manual',
      ),
      data: BackupDataV1(
        members: backupMembers,
        items: backupItems,
        itemFields: backupItemFields,
        appSettings: const [],
        attachments: backupAttachments,
        childEntries: backupChildEntries,
        childFields: backupChildFields,
        itemEvents: backupItemEvents,
        itemEventChanges: backupItemEventChanges,
      ),
    ).normalized();
    return BackupV2ExportPlan(
      manifestPayload: payload,
      attachmentSourcesById: attachmentSourcesById,
      attachmentEncoding: BackupV2AttachmentEncoding.portablePlaintext,
    );
  }

  static Stream<List<int>> _openPortablePlaintextStream(
    String filePath, {
    required int expectedPlainSize,
  }) async* {
    final plaintext = await AttachmentPayloadReader.readPathInBackground(
      filePath,
    );
    try {
      if (plaintext.length != expectedPlainSize) {
        throw const BackupV2FormatException(
          BackupV2FormatErrorType.sourceUnavailable,
          '备份附件读取不完整，未生成可用备份。',
        );
      }
      for (
        var offset = 0;
        offset < plaintext.length;
        offset += BackupV2Format.framePlaintextLimit
      ) {
        final end = (offset + BackupV2Format.framePlaintextLimit)
            .clamp(0, plaintext.length)
            .toInt();
        yield Uint8List.sublistView(plaintext, offset, end);
      }
    } finally {
      plaintext.fillRange(0, plaintext.length, 0);
    }
  }

  /// 在内存中导出并加密当前的数据库记录，返回 [BackupEnvelopeV1] 实例。
  ///
  /// 可在单元测试时显式传入 [iterations] (如 1000) 避免运行时间过长。
  Future<BackupEnvelopeV1> exportEncryptedBackup({
    required String backupPassword,
    int? iterations,
    int? nowMillisForTest,
  }) async {
    // 1. 从 Repository 读入所有记录 (getAllMembers 包含已归档，getAllItemsWithFieldsForBackup 联表读取所有字段)
    final members = await memberRepository.getAllMembers();
    final itemsWithFields = await itemRepository
        .getAllItemsWithFieldsForBackup();

    // 2. 利用映射器将业务模型转换为备份模型
    final backupMembers = members
        .map(BackupPayloadMapper.toBackupMember)
        .toList();
    final backupItems = <BackupItemV1>[];
    final backupItemFields = <BackupItemFieldV1>[];
    final backupAttachments = <BackupAttachmentV1>[];

    final hasAttachments = itemsWithFields.any(
      (item) => item.attachments.isNotEmpty,
    );
    if (hasAttachments) {
      final docDir = await getApplicationDocumentsDirectory();
      final attachmentsDir = Directory(p.join(docDir.path, 'attachments'));

      for (final item in itemsWithFields) {
        backupItems.add(BackupPayloadMapper.toBackupItemFromFields(item));
        for (final f in item.fields) {
          backupItemFields.add(BackupPayloadMapper.toBackupItemField(f));
        }
        for (final att in item.attachments) {
          final file = File(p.join(attachmentsDir.path, att.fileName));
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final base64Str = base64Url.encode(bytes);
            backupAttachments.add(
              BackupPayloadMapper.toBackupAttachment(att, base64Str),
            );
          }
        }
      }
    } else {
      for (final item in itemsWithFields) {
        backupItems.add(BackupPayloadMapper.toBackupItemFromFields(item));
        for (final f in item.fields) {
          backupItemFields.add(BackupPayloadMapper.toBackupItemField(f));
        }
      }
    }

    // 3. 查询子项和子字段数据并映射为备份实体
    final dbChildEntries = await itemRepository.db
        .select(itemRepository.db.itemChildEntries)
        .get();
    final dbChildFields = await itemRepository.db
        .select(itemRepository.db.itemChildFields)
        .get();
    final dbItemEvents = await itemRepository.db
        .select(itemRepository.db.itemEvents)
        .get();
    final dbItemEventChanges = await itemRepository.db
        .select(itemRepository.db.itemEventChanges)
        .get();

    final backupChildEntries = dbChildEntries
        .map(
          (e) => BackupItemChildEntryV1(
            id: e.id,
            itemId: e.itemId,
            childType: e.childType,
            sortOrder: e.sortOrder,
            createdAt: e.createdAt,
            updatedAt: e.updatedAt,
          ),
        )
        .toList();

    final backupChildFields = dbChildFields
        .map(
          (f) => BackupItemChildFieldV1(
            id: f.id,
            childEntryId: f.childEntryId,
            fieldKey: f.fieldKey,
            label: f.label,
            valueText: f.valueText,
            valueType: f.valueType,
            sensitiveLevel: f.sensitiveLevel,
            copyable: f.copyable,
            searchable: f.searchable,
            summary: f.summary,
            sortOrder: f.sortOrder,
            createdAt: f.createdAt,
            updatedAt: f.updatedAt,
          ),
        )
        .toList();

    final backupItemEvents = dbItemEvents
        .map(
          (event) => BackupItemEventV1(
            id: event.id,
            itemId: event.itemId,
            eventType: event.eventType,
            occurredAt: event.occurredAt,
          ),
        )
        .toList();
    final backupItemEventChanges = dbItemEventChanges
        .map(
          (change) => BackupItemEventChangeV1(
            id: change.id,
            eventId: change.eventId,
            changeKind: change.changeKind,
            subjectKey: change.subjectKey,
            subjectLabel: change.subjectLabel,
            oldValue: change.oldValue,
            newValue: change.newValue,
            sortOrder: change.sortOrder,
          ),
        )
        .toList();

    // 4. 构建备份 Payload 模型 (appSettings 本批次先留空，保持在 payload 树结构中占位)
    final payload = BackupPayloadV1(
      exportedAt: nowMillisForTest ?? DateTime.now().millisecondsSinceEpoch,
      appVersion: metadata.appVersion,
      schemaVersion: metadata.schemaVersion,
      source: BackupSourceInfo(
        appId: metadata.appId,
        platform: metadata.platform,
        locale: metadata.locale,
        exportMode: 'manual',
      ),
      data: BackupDataV1(
        members: backupMembers,
        items: backupItems,
        itemFields: backupItemFields,
        appSettings:
            const [], // ⚠️ 注释说明：现有数据库 app_settings 读取尚未被业务调用，暂时导出空列表占位，后续专项再完善
        attachments: backupAttachments,
        childEntries: backupChildEntries,
        childFields: backupChildFields,
        itemEvents: backupItemEvents,
        itemEventChanges: backupItemEventChanges,
      ),
    );

    // 4. 执行规范化排序
    final sortedPayload = payload.normalized();

    // 5. 传递给密码学服务进行 AES-256-GCM 加密，并返回加密外壳 Envelope (已对密码空校验做内部抛出)
    return await BackupCryptoService.encryptPayload(
      payload: sortedPayload,
      backupPassword: backupPassword,
      iterations: iterations ?? BackupCryptoService.defaultIterations,
      nowMillisForTest: nowMillisForTest,
    );
  }

  /// 纯内存工具方法：返回序列化后的加密外壳明文 JSON 字符串 (不执行落盘)
  Future<String> exportEncryptedBackupJson({
    required String backupPassword,
    int? iterations,
    int? nowMillisForTest,
  }) async {
    final envelope = await exportEncryptedBackup(
      backupPassword: backupPassword,
      iterations: iterations,
      nowMillisForTest: nowMillisForTest,
    );
    return jsonEncode(envelope.toJson());
  }

  /// 纯内存工具方法：返回序列化后的加密外壳 UTF-8 JSON 二进制字节数组 (不执行落盘)
  Future<List<int>> exportEncryptedBackupJsonBytes({
    required String backupPassword,
    int? iterations,
    int? nowMillisForTest,
  }) async {
    final jsonStr = await exportEncryptedBackupJson(
      backupPassword: backupPassword,
      iterations: iterations,
      nowMillisForTest: nowMillisForTest,
    );
    return utf8.encode(jsonStr);
  }
}
