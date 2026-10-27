/// V2 恢复确认后的真实执行进度。
///
/// 仅在完整读取、认证并写入附件 staging 时提供字节比例；数据库原子切换阶段没有可靠比例，界面必须显示加载圈。
enum BackupRestoreProgressStage { staging, applying }

class BackupRestoreProgress {
  final BackupRestoreProgressStage stage;
  final int readBytes;
  final int? totalBytes;

  const BackupRestoreProgress({
    required this.stage,
    required this.readBytes,
    this.totalBytes,
  });

  double? get fraction {
    final total = totalBytes;
    if (stage != BackupRestoreProgressStage.staging ||
        total == null ||
        total <= 0) {
      return null;
    }
    return (readBytes / total).clamp(0.0, 1.0).toDouble();
  }
}

typedef BackupRestoreProgressCallback =
    void Function(BackupRestoreProgress progress);
