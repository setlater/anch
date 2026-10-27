/// 导出前或导出中发现不可读取附件时的脱敏定位信息。
///
/// 该对象仅用于当前导出流程的用户反馈，绝不持久化、写入日志或拼入异常字符串。
enum BackupUnavailableAttachmentReason {
  fileMissing,
  sizeMismatch,
  fileUnreadable,
  sourceChanged,
  metadataInconsistent,
}

class BackupUnavailableAttachment {
  /// 仅用于本次失败反馈的资料分组；不得显示、持久化或写入日志。
  final String? itemId;
  final String? itemTitle;
  final String? originalName;
  final BackupUnavailableAttachmentReason reason;

  const BackupUnavailableAttachment({
    required this.reason,
    this.itemId,
    this.itemTitle,
    this.originalName,
  });

  String get itemDisplayName {
    final normalized = itemTitle?.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized == null || normalized.isEmpty ? '未命名资料' : normalized;
  }

  /// 仅显示原始名称的末段，防止异常元数据意外暴露路径。
  String get displayName {
    final normalized = originalName?.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized == null || normalized.isEmpty) return '未命名附件';
    final segments = normalized.split(RegExp(r'[\\/]'));
    return segments.last.trim().isEmpty ? '未命名附件' : segments.last.trim();
  }

  String get reasonTitle => switch (reason) {
    BackupUnavailableAttachmentReason.fileMissing => '本机附件文件已不存在',
    BackupUnavailableAttachmentReason.sizeMismatch => '文件大小与记录不一致',
    BackupUnavailableAttachmentReason.fileUnreadable => '本机附件文件无法读取',
    BackupUnavailableAttachmentReason.sourceChanged => '导出期间附件文件发生变化',
    BackupUnavailableAttachmentReason.metadataInconsistent => '附件记录不一致',
  };

  String get reasonLabel => '$reasonTitle。';
}
