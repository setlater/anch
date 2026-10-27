import 'android_saf_backup_v2_stream_service.dart';
import 'backup_export_service.dart';
import 'backup_export_progress.dart';
import 'backup_file_policy.dart';
import 'backup_file_save_service.dart';
import 'backup_unavailable_attachment.dart';
import 'backup_v2_format.dart';

/// V2 流式导出协调器。
///
/// 导出前先校验每个附件来源和估算完整输出体积；SAF 目标空间对第三方文档提供方不可可靠预知，因此写入阶段仍
/// 必须逐帧处理失败。任一失败只关闭输出流，不写入最终提交帧，也不自动删除用户选择位置上的文件。
class BackupV2FileExportCoordinator {
  final BackupExportService exportService;

  const BackupV2FileExportCoordinator({required this.exportService});

  /// 仅校验来源并估算完整输出大小，用于在打开系统保存位置前提示容量风险。
  Future<BackupV2ExportPreflight> estimateOutput({
    int? nowMillisForTest,
  }) async {
    final plan = await _preparePlan(nowMillisForTest: nowMillisForTest);
    return _preflight(plan);
  }

  Future<BackupFileSaveResult> exportAndSave({
    required String backupPassword,
    int? iterations,
    int? nowMillisForTest,
    BackupExportProgressCallback? onProgress,
  }) async {
    if (backupPassword.trim().isEmpty) {
      throw BackupFileSaveException(
        BackupFileSaveErrorType.invalidPackage,
        '备份密码不能为空。',
      );
    }

    final plan = await _preparePlan(nowMillisForTest: nowMillisForTest);
    await _preflight(plan);

    final nowMillis = nowMillisForTest ?? DateTime.now().millisecondsSinceEpoch;
    final session = await AndroidSafBackupV2WriteSession.begin(
      fileName: BackupFilePolicy.buildDefaultFileName(nowMillis: nowMillis),
      mimeType: BackupFilePolicy.defaultMimeType,
    );
    var finished = false;
    var hasStartedWriting = false;
    try {
      onProgress?.call(
        const BackupExportProgress(
          stage: BackupExportProgressStage.preparing,
          fraction: 0,
        ),
      );
      final sizeBytes = await BackupV2Format.encodeToSink(
        plan: plan,
        backupPassword: backupPassword,
        sink: session,
        iterations: iterations,
        createdAtForTest: nowMillisForTest,
        onProgress: (writtenBytes, totalBytes) {
          if (writtenBytes > 0) {
            hasStartedWriting = true;
          }
          final fraction = totalBytes == 0 ? 0.0 : writtenBytes / totalBytes;
          onProgress?.call(
            BackupExportProgress(
              stage: BackupExportProgressStage.writing,
              fraction: fraction.clamp(0.0, 0.99).toDouble(),
            ),
          );
        },
      );
      onProgress?.call(
        const BackupExportProgress(
          stage: BackupExportProgressStage.finalizing,
          fraction: 0.99,
        ),
      );
      final result = await session.finish(expectedSizeBytes: sizeBytes);
      finished = true;
      onProgress?.call(
        const BackupExportProgress(
          stage: BackupExportProgressStage.completed,
          fraction: 1,
        ),
      );
      return result;
    } on BackupFileSaveException {
      rethrow;
    } on BackupV2FormatException catch (error) {
      var unavailableAttachments = error.unavailableAttachments;
      if (error.type == BackupV2FormatErrorType.sourceUnavailable) {
        await session.abort();
        final totalAttachments = plan.attachmentSourcesById.length;
        final completedAttachments = error.checkedAttachmentIds
            .where(plan.attachmentSourcesById.containsKey)
            .length;
        onProgress?.call(
          BackupExportProgress(
            stage: BackupExportProgressStage.checkingAttachments,
            fraction: 0,
            completedAttachments: completedAttachments,
            totalAttachments: totalAttachments,
          ),
        );
        final auditedAttachments =
            await BackupV2Format.auditRemainingAttachments(
              plan: plan,
              alreadyCheckedAttachmentIds: error.checkedAttachmentIds,
              onAttachmentChecked: (completedAttachments, totalAttachments) {
                onProgress?.call(
                  BackupExportProgress(
                    stage: BackupExportProgressStage.checkingAttachments,
                    fraction: 0,
                    completedAttachments: completedAttachments,
                    totalAttachments: totalAttachments,
                  ),
                );
              },
            );
        unavailableAttachments = _mergeUnavailableAttachments(
          unavailableAttachments,
          auditedAttachments,
        );
      }
      throw BackupFileSaveException(
        error.type == BackupV2FormatErrorType.sourceUnavailable
            ? BackupFileSaveErrorType.sourceUnavailable
            : hasStartedWriting
            ? BackupFileSaveErrorType.writeFailed
            : BackupFileSaveErrorType.preparationFailed,
        error.message,
        unavailableAttachments: unavailableAttachments,
      );
    } catch (_) {
      throw BackupFileSaveException(
        hasStartedWriting
            ? BackupFileSaveErrorType.writeFailed
            : BackupFileSaveErrorType.preparationFailed,
        '备份文件写入失败，未确认生成可用文件。',
      );
    } finally {
      if (!finished) {
        await session.abort();
      }
    }
  }

  Future<BackupV2ExportPlan> _preparePlan({int? nowMillisForTest}) async {
    try {
      return await exportService.prepareStreamingV2Export(
        nowMillisForTest: nowMillisForTest,
      );
    } on BackupV2FormatException catch (error) {
      throw _preflightFailure(error);
    }
  }

  Future<BackupV2ExportPreflight> _preflight(BackupV2ExportPlan plan) async {
    try {
      return await BackupV2Format.preflight(plan);
    } on BackupV2FormatException catch (error) {
      throw _preflightFailure(error);
    }
  }

  BackupFileSaveException _preflightFailure(BackupV2FormatException error) {
    return BackupFileSaveException(
      error.type == BackupV2FormatErrorType.sourceUnavailable
          ? BackupFileSaveErrorType.sourceUnavailable
          : BackupFileSaveErrorType.invalidPackage,
      error.message,
      unavailableAttachments: error.unavailableAttachments,
    );
  }

  List<BackupUnavailableAttachment> _mergeUnavailableAttachments(
    List<BackupUnavailableAttachment> initial,
    List<BackupUnavailableAttachment> audited,
  ) {
    final merged = <BackupUnavailableAttachment>[];
    final keys = <String>{};
    for (final attachment in [...initial, ...audited]) {
      final key = [
        attachment.itemDisplayName,
        attachment.displayName,
        attachment.reason.name,
      ].join('\u0000');
      if (keys.add(key)) {
        merged.add(attachment);
      }
    }
    return List.unmodifiable(merged);
  }
}
