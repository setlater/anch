import 'backup_file_read_service.dart';
import 'backup_file_codec.dart';
import 'backup_crypto.dart';
import 'backup_envelope.dart';
import 'backup_package_content_preview.dart';
import 'backup_payload.dart';
import 'backup_file_restore_preview_coordinator.dart';

/// 恢复备份解密预检错误类型。
enum BackupFileRestoreDecryptPreviewErrorType {
  userCancelled,
  fileTooLarge,
  fileReadFailed,
  invalidFileFormat,
  invalidPasswordOrCorruptedData,
  unsupportedPayloadVersion,
  unsupportedSchemaVersion,
  invalidPayload,
  streamingV2Selected,
  unknown,
}

/// 恢复备份解密预检异常。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本异常的 [toString] 与 [message] 必须固定脱敏。
/// 2. 绝对禁止包含底层异常原文、密码、密文、JSON 结构、密匙、以及任何 `TEST-*` 高敏明文。
class BackupFileRestoreDecryptPreviewException implements Exception {
  final BackupFileRestoreDecryptPreviewErrorType type;
  final String message;

  BackupFileRestoreDecryptPreviewException(this.type, this.message);

  @override
  String toString() {
    return 'BackupFileRestoreDecryptPreviewException[${type.name}]: $message';
  }
}

/// 恢复备份解密预检结果模型。
///
/// ⚠️ 【安全边界 - 必须遵守】
/// 1. 本类禁止持有 [BackupPayloadV1]、[BackupEnvelopeV1] 实例。认证成功后可短暂携带受限的
///    [contentPreview] 供当前前台确认页展示。
/// 2. [contentPreview] 只包含成员名称、资料标题、类型、状态和附件数量；绝不包含字段值、附件名称／内容、
///    密码、密钥、密文、原始 JSON 或路径。
/// 3. 重写 [toString] 时只输出数量、版本、大小和泛化来源文案，防日志泄露。
class BackupFileRestoreDecryptPreviewResult {
  final int sizeBytes;
  final String sizeLabel;
  final int readAt;
  final String displaySource;
  final int payloadVersion;
  final int schemaVersion;
  final int membersCount;
  final int itemsCount;
  final int itemFieldsCount;
  final int appSettingsCount;
  final int? generatedAt;
  final String? appVersion;
  final BackupPackageContentPreview contentPreview;
  final bool requiresFullVerificationOnApply;

  BackupFileRestoreDecryptPreviewResult({
    required this.sizeBytes,
    required this.sizeLabel,
    required this.readAt,
    required this.displaySource,
    required this.payloadVersion,
    required this.schemaVersion,
    required this.membersCount,
    required this.itemsCount,
    required this.itemFieldsCount,
    required this.appSettingsCount,
    this.generatedAt,
    this.appVersion,
    this.contentPreview = const BackupPackageContentPreview(),
    this.requiresFullVerificationOnApply = false,
  });

  @override
  String toString() {
    return 'BackupFileRestoreDecryptPreviewResult('
        'sizeBytes: $sizeBytes, '
        'sizeLabel: $sizeLabel, '
        'readAt: $readAt, '
        'displaySource: $displaySource, '
        'payloadVersion: $payloadVersion, '
        'schemaVersion: $schemaVersion, '
        'membersCount: $membersCount, '
        'itemsCount: $itemsCount, '
        'itemFieldsCount: $itemFieldsCount, '
        'appSettingsCount: $appSettingsCount, '
        'generatedAt: $generatedAt, '
        'appVersion: $appVersion, '
        'requiresFullVerificationOnApply: $requiresFullVerificationOnApply'
        ')';
  }
}

/// 恢复解密预检协调器。
///
/// 职责：
/// 1. 串联读取文件、Envelope 预检、密码解密及 Payload 基础结构校验。
/// 2. ⚠️ 【安全红线】本类仅限进行密码解密预检以验证可用性，绝不执行数据库写入与覆盖，不调用任何导入服务。
/// 3. ⚠️ 【安全红线】解密出的 [BackupPayloadV1] 仅在方法局部临时使用，绝不挂载至 Result 或 Exception，绝不外泄。
class BackupFileRestoreDecryptPreviewCoordinator {
  final BackupFileReadService readService;
  final int supportedSchemaVersion;

  // 仅在当前前台恢复确认会话中暂存已选中的加密文件；绝不保存密码、
  // 解密载荷或文件路径。页面进入后台、退出或恢复完成时必须显式清除。
  BackupFileReadResult? _preparedReadResult;
  int _sessionGeneration = 0;

  BackupFileRestoreDecryptPreviewCoordinator({
    required this.readService,
    required this.supportedSchemaVersion,
  });

  BackupFileReadResult? takePreparedReadResult() {
    final result = _preparedReadResult;
    clearPreparedReadResult();
    return result;
  }

  void clearPreparedReadResult() {
    _sessionGeneration++;
    _preparedReadResult = null;
  }

  void _requireCurrentSession(int generation) {
    if (generation != _sessionGeneration) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.userCancelled,
        '已取消恢复备份。',
      );
    }
  }

  /// 选择并校验备份文件外壳，保留加密字节供当前前台恢复会话使用。
  Future<BackupFileRestorePreviewResult> selectAndPrepareFile() async {
    clearPreparedReadResult();
    final generation = _sessionGeneration;
    final BackupFileReadResult readResult;
    try {
      readResult = await readService.readBackupFile();
    } on BackupFileReadException catch (e) {
      _requireCurrentSession(generation);
      switch (e.type) {
        case BackupFileReadErrorType.userCancelled:
          throw BackupFileRestoreDecryptPreviewException(
            BackupFileRestoreDecryptPreviewErrorType.userCancelled,
            '已取消选择备份文件。',
          );
        case BackupFileReadErrorType.fileTooLarge:
          throw BackupFileRestoreDecryptPreviewException(
            BackupFileRestoreDecryptPreviewErrorType.fileTooLarge,
            '备份文件过大，暂不支持读取。',
          );
        case BackupFileReadErrorType.streamingV2Selected:
          throw BackupFileRestoreDecryptPreviewException(
            BackupFileRestoreDecryptPreviewErrorType.streamingV2Selected,
            '已选择流式备份文件。',
          );
        default:
          throw BackupFileRestoreDecryptPreviewException(
            BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
            '备份文件读取失败。',
          );
      }
    } catch (_) {
      _requireCurrentSession(generation);
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }

    _requireCurrentSession(generation);
    final BackupEnvelopeV1 envelope;
    try {
      envelope = BackupFileCodec.decodeEnvelopeBytes(readResult.bytes);
    } on BackupFileCodecException catch (_) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    } catch (_) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    }

    _preparedReadResult = readResult;
    return BackupFileRestorePreviewResult(
      sizeBytes: readResult.sizeBytes,
      sizeLabel: readResult.sizeLabel,
      readAt: readResult.readAt,
      displaySource: readResult.displaySource,
      envelopeVersion: envelope.version,
      payloadVersion: envelope.payloadVersion,
      kdfName: envelope.kdf.name,
      cipherName: envelope.cipher.name,
    );
  }

  /// 读取外部文件字节流，解析 Envelope，使用输入的密码解密并验证 Payload 结构。
  ///
  /// 如果在任意环节出错，将错误包装为安全的脱敏异常 [BackupFileRestoreDecryptPreviewException] 并抛出。
  Future<BackupFileRestoreDecryptPreviewResult> readAndDecryptPreview({
    required String backupPassword,
  }) async {
    await selectAndPrepareFile();
    return decryptPreparedPreview(backupPassword: backupPassword);
  }

  /// 使用当前恢复会话已选择的加密文件完成解密预检，不再次打开文件选择器。
  Future<BackupFileRestoreDecryptPreviewResult> decryptPreparedPreview({
    required String backupPassword,
  }) async {
    final generation = _sessionGeneration;
    final readResult = _preparedReadResult;
    if (readResult == null) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.fileReadFailed,
        '备份文件读取失败。',
      );
    }

    final BackupEnvelopeV1 envelope;
    try {
      envelope = BackupFileCodec.decodeEnvelopeBytes(readResult.bytes);
    } on BackupFileCodecException catch (_) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    } catch (_) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    }

    // 3. 调用 Crypto 解密 Envelope
    final BackupPayloadV1 payload;
    try {
      payload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: backupPassword,
      );
    } on BackupCryptoException catch (e) {
      _requireCurrentSession(generation);
      if (e.type == BackupCryptoErrorType.invalidPasswordOrCorruptedData) {
        throw BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
          '备份密码不正确，或备份文件已损坏。',
        );
      } else if (e.type == BackupCryptoErrorType.invalidEnvelope) {
        throw BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
          '备份文件格式不正确或已损坏。',
        );
      } else {
        throw BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
          '备份密码不正确，或备份文件已损坏。',
        );
      }
    } catch (_) {
      _requireCurrentSession(generation);
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.invalidPasswordOrCorruptedData,
        '备份密码不正确，或备份文件已损坏。',
      );
    }

    _requireCurrentSession(generation);
    // 4. 对 BackupPayloadV1 做基础结构与版本校验
    if (payload.version != 1) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.unsupportedPayloadVersion,
        '当前版本暂不支持此备份文件。',
      );
    }

    if (payload.schemaVersion > supportedSchemaVersion) {
      throw BackupFileRestoreDecryptPreviewException(
        BackupFileRestoreDecryptPreviewErrorType.unsupportedSchemaVersion,
        '当前版本暂不支持此备份文件。',
      );
    }

    final data = payload.data;
    // 经过 fromJson 解析，data.members 等在 Dart 强类型下一定不为 null 且是合法的 List

    // 5. 构造脱敏摘要
    return BackupFileRestoreDecryptPreviewResult(
      sizeBytes: readResult.sizeBytes,
      sizeLabel: readResult.sizeLabel,
      readAt: readResult.readAt,
      displaySource: readResult.displaySource,
      payloadVersion: payload.version,
      schemaVersion: payload.schemaVersion,
      membersCount: data.members.length,
      itemsCount: data.items.length,
      itemFieldsCount: data.itemFields.length,
      appSettingsCount: data.appSettings.length,
      generatedAt: payload.exportedAt,
      appVersion: payload.appVersion,
      contentPreview: BackupPackageContentPreview.fromPayload(payload),
    );
  }
}
