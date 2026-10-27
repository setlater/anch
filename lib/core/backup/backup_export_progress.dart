enum BackupExportProgressStage {
  preparing,
  writing,
  checkingAttachments,
  finalizing,
  completed,
}

class BackupExportProgress {
  final BackupExportProgressStage stage;
  final double fraction;
  final int? completedAttachments;
  final int? totalAttachments;

  const BackupExportProgress({
    required this.stage,
    required this.fraction,
    this.completedAttachments,
    this.totalAttachments,
  }) : assert(fraction >= 0 && fraction <= 1),
       assert((completedAttachments == null) == (totalAttachments == null)),
       assert(totalAttachments == null || totalAttachments >= 0),
       assert(
         completedAttachments == null ||
             (completedAttachments >= 0 &&
                 completedAttachments <= (totalAttachments ?? 0)),
       );
}

typedef BackupExportProgressCallback =
    void Function(BackupExportProgress progress);
