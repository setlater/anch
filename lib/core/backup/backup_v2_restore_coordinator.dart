import 'dart:async';
import 'dart:io';

import 'android_saf_backup_v2_stream_service.dart';
import 'backup_file_policy.dart';
import 'backup_file_read_service.dart';
import 'backup_file_restore_apply_coordinator.dart';
import 'backup_file_restore_decrypt_preview_coordinator.dart';
import 'backup_file_restore_preview_coordinator.dart';
import 'backup_import_service.dart';
import 'backup_package_content_preview.dart';
import 'backup_payload.dart';
import 'backup_restore_progress.dart';
import 'backup_v2_attachment_directory_staging.dart';
import 'backup_v2_format.dart';

/// V2 流式恢复会话。
///
/// 文件选择仍由既有 SAF 入口完成一次；识别到 V2 后，本会话先认证加密 manifest 以展示恢复范围，只有用户确认后才
/// 完整读取、认证并 staging 附件，最后交给 [BackupImportService] 原子切换。V1 不经过本类，继续沿用原有内存兼容通路。
class BackupV2RestoreCoordinator {
  final BackupImportService importService;
  final int supportedSchemaVersion;
  final Future<Directory> Function()? documentsDirectoryProvider;

  AndroidSafBackupV2ReadSession? _readSession;
  Future<AndroidSafBackupV2ReadSession>? _openingSession;
  Future<void> _cleanup = Future<void>.value();
  int _sessionGeneration = 0;
  BackupPayloadV1? _previewedPayload;
  BackupV2DecodedPayload? _prepared;

  BackupV2RestoreCoordinator({
    required this.importService,
    required this.supportedSchemaVersion,
    this.documentsDirectoryProvider,
  });

  bool get hasPreparedRestore => _previewedPayload != null || _prepared != null;

  /// 在既有选择器识别 V2 后连接已选输入流，不再二次弹出文件选择器。
  Future<BackupFileRestorePreviewResult> prepareSelectedFile() async {
    final cleanup = _clearPrepared();
    final generation = _sessionGeneration;
    await cleanup;
    _requireCurrentSession(generation);
    final opening = AndroidSafBackupV2ReadSession.openSelected();
    _openingSession = opening;
    final AndroidSafBackupV2ReadSession session;
    try {
      session = await opening;
      _requireCurrentSession(generation);
      _readSession = session;
    } finally {
      if (identical(_openingSession, opening)) _openingSession = null;
    }
    final sizeBytes = session.sizeBytes ?? 0;
    return BackupFileRestorePreviewResult(
      sizeBytes: sizeBytes,
      sizeLabel: session.sizeBytes == null
          ? '待校验'
          : BackupFilePolicy.formatBytes(sizeBytes),
      readAt: DateTime.now().millisecondsSinceEpoch,
      displaySource: '系统选择的文件',
      envelopeVersion: 2,
      payloadVersion: 1,
      kdfName: 'pbkdf2-hmac-sha256',
      cipherName: 'aes-256-gcm-framed',
    );
  }

  /// 认证 V2 加密 manifest 并读取恢复范围；不读取附件、不创建 staging、不写入数据库。
  Future<BackupFileRestoreDecryptPreviewResult> decryptAndPreviewManifest({
    required String backupPassword,
  }) async {
    final session = _readSession;
    final generation = _sessionGeneration;
    if (session == null) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }
    var keepReadSession = false;
    try {
      final payload = await BackupV2Format.decodeManifestPreview(
        source: session,
        backupPassword: backupPassword,
      );
      _requireCurrentSession(generation);
      if (payload.schemaVersion > supportedSchemaVersion) {
        throw BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType.unsupportedSchemaVersion,
          '当前版本暂不支持此备份文件。',
        );
      }
      await session.restart();
      _requireCurrentSession(generation);
      keepReadSession = true;
      _previewedPayload = payload;
      final data = payload.data;
      return BackupFileRestoreDecryptPreviewResult(
        sizeBytes: session.sizeBytes ?? 0,
        sizeLabel: session.sizeBytes == null
            ? '待校验'
            : BackupFilePolicy.formatBytes(session.sizeBytes!),
        readAt: DateTime.now().millisecondsSinceEpoch,
        displaySource: '系统选择的文件',
        payloadVersion: payload.version,
        schemaVersion: payload.schemaVersion,
        membersCount: data.members.length,
        itemsCount: data.items.length,
        itemFieldsCount: data.itemFields.length,
        appSettingsCount: data.appSettings.length,
        generatedAt: payload.exportedAt,
        appVersion: payload.appVersion,
        contentPreview: BackupPackageContentPreview.fromPayload(payload),
        requiresFullVerificationOnApply: true,
      );
    } on BackupFileRestoreDecryptPreviewException {
      rethrow;
    } on BackupV2FormatException catch (error) {
      if (error.type ==
          BackupV2FormatErrorType.invalidPasswordOrCorruptedData) {
        try {
          _requireCurrentSession(generation);
          await session.restart();
          _requireCurrentSession(generation);
          keepReadSession = true;
        } on BackupFileReadException {
          throw BackupFileRestoreDecryptPreviewException(
            BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
            '备份文件读取失败。',
          );
        }
      }
      throw _mapDecodeError(error);
    } on BackupFileReadException {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    } finally {
      if (!keepReadSession && identical(_readSession, session)) {
        _readSession = null;
        _previewedPayload = null;
        await session.close();
      }
    }
  }

  /// 用户确认覆盖后，重新完整读取并认证包体、写入新的附件 staging，随后执行原子恢复。
  Future<BackupFileRestoreApplyResult> stageAndApply({
    required String backupPassword,
    required BackupRestoreProgressCallback onProgress,
  }) async {
    final session = _readSession;
    final generation = _sessionGeneration;
    if (session == null || _previewedPayload == null) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }
    try {
      final decoded = await BackupV2Format.decodeAndStage(
        source: session,
        backupPassword: backupPassword,
        stagingFactory: (payload, attachmentEncoding) =>
            BackupV2AttachmentDirectoryStaging.create(
              payload,
              attachmentEncoding: attachmentEncoding,
              documentsDirectoryProvider: documentsDirectoryProvider,
            ),
        onProgress: (bytesRead) {
          onProgress(
            BackupRestoreProgress(
              stage: BackupRestoreProgressStage.staging,
              readBytes: bytesRead,
              totalBytes: session.sizeBytes,
            ),
          );
        },
      );
      if (generation != _sessionGeneration) {
        await decoded.staging.abort();
        throw BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.fileReadFailed,
          '备份文件读取失败。',
        );
      }
      if (decoded.payload.schemaVersion > supportedSchemaVersion) {
        await decoded.staging.abort();
        throw BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.unsupportedSchemaVersion,
          '当前版本暂不支持此备份文件。',
        );
      }
      _prepared = decoded;
      _previewedPayload = null;
      onProgress(
        const BackupRestoreProgress(
          stage: BackupRestoreProgressStage.applying,
          readBytes: 0,
        ),
      );
      return await applyPreparedRestore();
    } on BackupFileRestoreApplyException {
      rethrow;
    } on BackupV2FormatException catch (error) {
      throw _mapStageError(error);
    } on BackupFileReadException {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    } finally {
      if (identical(_readSession, session)) {
        _readSession = null;
        await session.close();
      }
    }
  }

  /// 仅接受已经完成 V2 认证与 staging 的会话；不重新读取外部文件，也不使用页面传入的密码。
  Future<BackupFileRestoreApplyResult> applyPreparedRestore() async {
    final decoded = _prepared;
    if (decoded == null ||
        decoded.staging is! BackupV2AttachmentDirectoryStaging) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }
    _prepared = null;
    try {
      final result = await importService.restoreFromV2PreparedPayload(
        payload: decoded.payload,
        attachmentStaging:
            decoded.staging as BackupV2AttachmentDirectoryStaging,
      );
      return BackupFileRestoreApplyResult(
        restoredMembersCount: result.restoredMembersCount,
        restoredItemsCount: result.restoredItemsCount,
        restoredItemFieldsCount: result.restoredItemFieldsCount,
        restoredAppSettingsCount: result.restoredAppSettingsCount,
        restoredAt: result.restoredAt,
        sourceSizeLabel: BackupFilePolicy.formatBytes(decoded.sizeBytes),
      );
    } on BackupImportException catch (error) {
      throw _mapImportError(error);
    } catch (_) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.unknown,
        '恢复失败，请稍后重试。',
      );
    }
  }

  /// 页面退出、切换文件或生命周期清理时调用；不保留密码、外部 URI、载荷或 staging。
  void clearPreparedRestore() {
    unawaited(_clearPrepared());
  }

  Future<void> clearPreparedRestoreAndWait() => _clearPrepared();

  Future<void> _clearPrepared() {
    _sessionGeneration++;
    final session = _readSession;
    final opening = _openingSession;
    final prepared = _prepared;
    _readSession = null;
    _openingSession = null;
    _previewedPayload = null;
    _prepared = null;
    final previousCleanup = _cleanup;
    return _cleanup = () async {
      await previousCleanup;
      await session?.close();
      if (opening != null) {
        try {
          await (await opening).close();
        } catch (_) {
          // 打开失败由原调用报告，清理不重复传播同一次失败。
        }
      }
      await prepared?.staging.abort();
    }();
  }

  void _requireCurrentSession(int generation) {
    if (generation != _sessionGeneration) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }
  }

  BackupFileRestoreDecryptPreviewException _mapDecodeError(
    BackupV2FormatException error,
  ) {
    switch (error.type) {
      case BackupV2FormatErrorType.invalidPasswordOrCorruptedData:
        return BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
          '备份密码不正确，或备份文件已损坏。',
        );
      case BackupV2FormatErrorType.incompleteCommit:
      case BackupV2FormatErrorType.invalidFormat:
        return BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
          '备份文件格式不正确或已损坏。',
        );
      case BackupV2FormatErrorType.invalidPayload:
        return BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType.invalidPayload,
          '备份内容校验失败，未执行恢复。',
        );
      default:
        return BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
          '备份文件读取失败。',
        );
    }
  }

  BackupFileRestoreApplyException _mapImportError(BackupImportException error) {
    switch (error.type) {
      case BackupImportErrorType.unsupportedSchemaVersion:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.unsupportedSchemaVersion,
          '当前版本暂不支持此备份文件。',
        );
      case BackupImportErrorType.invalidPayload:
      case BackupImportErrorType.missingSystemMember:
      case BackupImportErrorType.missingMemberReference:
      case BackupImportErrorType.missingItemReference:
      case BackupImportErrorType.duplicatedId:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.importValidationFailed,
          '备份内容校验失败，未执行恢复。',
        );
      case BackupImportErrorType.databaseWriteFailed:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.importTransactionFailed,
          '恢复过程中发生错误，当前数据不应被破坏。',
        );
      default:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.unknown,
          '恢复失败，请稍后重试。',
        );
    }
  }

  BackupFileRestoreApplyException _mapStageError(
    BackupV2FormatException error,
  ) {
    switch (error.type) {
      case BackupV2FormatErrorType.invalidPasswordOrCorruptedData:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.invalidPasswordOrCorruptedData,
          '备份密码不正确，或备份文件已损坏。',
        );
      case BackupV2FormatErrorType.incompleteCommit:
      case BackupV2FormatErrorType.invalidFormat:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.invalidFileFormat,
          '备份文件格式不正确或已损坏。',
        );
      case BackupV2FormatErrorType.invalidPayload:
      case BackupV2FormatErrorType.attachmentNotRecoverable:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.invalidPayload,
          error.type == BackupV2FormatErrorType.attachmentNotRecoverable
              ? '此历史备份中的附件无法在当前设备恢复，原数据未改动。'
              : '备份内容校验失败，未执行恢复。',
        );
      default:
        return BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.fileReadFailed,
          '备份文件读取失败。',
        );
    }
  }
}
