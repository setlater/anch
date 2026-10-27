import 'backup_file_read_service.dart';
import 'backup_file_codec.dart';
import 'backup_import_service.dart';
import 'backup_envelope.dart';

/// 恢复覆盖执行错误类型。
enum BackupFileRestoreApplyErrorType {
  userCancelled,
  fileTooLarge,
  fileReadFailed,
  invalidFileFormat,
  invalidPasswordOrCorruptedData,
  unsupportedPayloadVersion,
  unsupportedSchemaVersion,
  invalidPayload,
  importValidationFailed,
  importTransactionFailed,
  unknown,
}

/// 恢复覆盖执行安全异常类。
///
/// ⚠️ 【安全红线 - 必须遵守】
/// 1. 本异常的 [toString] 与 [message] 必须固定脱敏。
/// 2. 绝对禁止包含底层异常原文、密码、密文、JSON 结构、密匙、以及任何 `TEST-*` 高敏明文。
class BackupFileRestoreApplyException implements Exception {
  final BackupFileRestoreApplyErrorType type;
  final String message;

  BackupFileRestoreApplyException(this.type, this.message);

  @override
  String toString() {
    return 'BackupFileRestoreApplyException[${type.name}]: $message';
  }
}

/// 恢复覆盖执行脱敏结果。
///
/// ⚠️ 【安全边界 - 必须遵守】
/// 1. 本类仅包含脱敏后的恢复统计摘要，禁止持有 [BackupPayloadV1]、[BackupEnvelopeV1] 实例或任何明文数据。
/// 2. 绝对严禁包含密码、密钥、密文、原始 JSON 文本、资料标题、成员姓名或字段值。
/// 3. 重写 [toString] 时只输出数量、时间戳和大小，防日志泄露。
class BackupFileRestoreApplyResult {
  final int restoredMembersCount;
  final int restoredItemsCount;
  final int restoredItemFieldsCount;
  final int restoredAppSettingsCount;
  final int restoredAt;
  final String? sourceSizeLabel;

  BackupFileRestoreApplyResult({
    required this.restoredMembersCount,
    required this.restoredItemsCount,
    required this.restoredItemFieldsCount,
    required this.restoredAppSettingsCount,
    required this.restoredAt,
    this.sourceSizeLabel,
  });

  @override
  String toString() {
    return 'BackupFileRestoreApplyResult('
        'restoredMembersCount: $restoredMembersCount, '
        'restoredItemsCount: $restoredItemsCount, '
        'restoredItemFieldsCount: $restoredItemFieldsCount, '
        'restoredAppSettingsCount: $restoredAppSettingsCount, '
        'restoredAt: $restoredAt, '
        'sourceSizeLabel: $sourceSizeLabel'
        ')';
  }
}

/// 恢复执行协调器。
///
/// 职责：
/// 1. 编排并串联文件再次读取、格式解包、以及调用写库事务完成覆盖恢复。
/// 2. ⚠️ 【安全红线】本类自身不手写任何清表/插表/外键/版本/事务回滚逻辑，所有核心写库操作统一编排并委托给已有的 [BackupImportService] 处理，避免两套恢复写入逻辑。
class BackupFileRestoreApplyCoordinator {
  final BackupFileReadService readService;
  final BackupImportService importService;

  BackupFileRestoreApplyCoordinator({
    required this.readService,
    required this.importService,
  });

  /// 读取文件包并安全执行备份覆盖恢复写入。
  ///
  /// 如果在任意环节出错，将错误包装为安全的脱敏异常 [BackupFileRestoreApplyException] 并抛出。
  Future<BackupFileRestoreApplyResult> readAndApplyRestore({
    required String backupPassword,
    BackupFileReadResult? preparedReadResult,
  }) async {
    // 1. 二次读取文件
    final BackupFileReadResult readResult;
    if (preparedReadResult != null) {
      readResult = preparedReadResult;
    } else {
      try {
        readResult = await readService.readBackupFile();
      } on BackupFileReadException catch (e) {
        switch (e.type) {
          case BackupFileReadErrorType.userCancelled:
            throw BackupFileRestoreApplyException(
              BackupFileRestoreApplyErrorType.userCancelled,
              '已取消选择备份文件。',
            );
          case BackupFileReadErrorType.fileTooLarge:
            throw BackupFileRestoreApplyException(
              BackupFileRestoreApplyErrorType.fileTooLarge,
              '备份文件过大，暂不支持恢复。',
            );
          default:
            throw BackupFileRestoreApplyException(
              BackupFileRestoreApplyErrorType.fileReadFailed,
              '备份文件读取失败。',
            );
        }
      } catch (_) {
        throw BackupFileRestoreApplyException(
          BackupFileRestoreApplyErrorType.fileReadFailed,
          '备份文件读取失败。',
        );
      }
    }

    // 2. decode envelope
    final BackupEnvelopeV1 envelope;
    try {
      envelope = BackupFileCodec.decodeEnvelopeBytes(readResult.bytes);
    } on BackupFileCodecException catch (_) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    } catch (_) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.invalidFileFormat,
        '备份文件格式不正确或已损坏。',
      );
    }

    // 3. 调用已有的 BackupImportService 触发事务恢复
    try {
      final importResult = await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: backupPassword,
      );

      return BackupFileRestoreApplyResult(
        restoredMembersCount: importResult.restoredMembersCount,
        restoredItemsCount: importResult.restoredItemsCount,
        restoredItemFieldsCount: importResult.restoredItemFieldsCount,
        restoredAppSettingsCount: importResult.restoredAppSettingsCount,
        restoredAt: importResult.restoredAt,
        sourceSizeLabel: readResult.sizeLabel,
      );
    } on BackupImportException catch (e) {
      switch (e.type) {
        case BackupImportErrorType.invalidPasswordOrCorruptedData:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.invalidPasswordOrCorruptedData,
            '备份密码不正确，或备份文件已损坏。',
          );
        case BackupImportErrorType.invalidPayload:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.invalidPayload,
            '当前版本暂不支持此备份文件。',
          );
        case BackupImportErrorType.unsupportedSchemaVersion:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.unsupportedSchemaVersion,
            '当前版本暂不支持此备份文件。',
          );
        case BackupImportErrorType.missingSystemMember:
        case BackupImportErrorType.missingMemberReference:
        case BackupImportErrorType.missingItemReference:
        case BackupImportErrorType.duplicatedId:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.importValidationFailed,
            '备份内容校验失败，未执行恢复。',
          );
        case BackupImportErrorType.databaseWriteFailed:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.importTransactionFailed,
            '恢复未完成，请返回首页核对资料后再试。',
          );
        default:
          throw BackupFileRestoreApplyException(
            BackupFileRestoreApplyErrorType.unknown,
            '恢复失败，请稍后重试。',
          );
      }
    } catch (_) {
      throw BackupFileRestoreApplyException(
        BackupFileRestoreApplyErrorType.unknown,
        '恢复失败，请稍后重试。',
      );
    }
  }
}
