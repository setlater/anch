class MigrationCheckpoint {
  final int lastProcessedOffset;
  final int totalItems;
  final int migratedCount;
  final int failedCount;
  final int batchSize;
  final String status; // 'running' | 'completed' | 'failed'

  MigrationCheckpoint({
    required this.lastProcessedOffset,
    required this.totalItems,
    required this.migratedCount,
    required this.failedCount,
    this.batchSize = 500,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'lastProcessedOffset': lastProcessedOffset,
    'totalItems': totalItems,
    'migratedCount': migratedCount,
    'failedCount': failedCount,
    'batchSize': batchSize,
    'status': status,
  };

  factory MigrationCheckpoint.fromJson(Map<String, dynamic> json) {
    return MigrationCheckpoint(
      lastProcessedOffset: json['lastProcessedOffset'] as int,
      totalItems: json['totalItems'] as int,
      migratedCount: json['migratedCount'] as int,
      failedCount: json['failedCount'] as int,
      batchSize: (json['batchSize'] ?? 500) as int,
      status: json['status'] as String,
    );
  }

  @override
  String toString() {
    return 'MigrationCheckpoint(lastProcessedOffset: $lastProcessedOffset, totalItems: $totalItems, migratedCount: $migratedCount, failedCount: $failedCount, batchSize: $batchSize, status: $status)';
  }
}
