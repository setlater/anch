class MigrationFailureLog {
  final String errorType;
  final int timestamp;

  MigrationFailureLog({required this.errorType, required this.timestamp});

  Map<String, dynamic> toJson() => {
    'errorType': errorType,
    'timestamp': timestamp,
  };

  factory MigrationFailureLog.fromJson(Map<String, dynamic> json) {
    return MigrationFailureLog(
      errorType: json['errorType'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  @override
  String toString() {
    return 'MigrationFailureLog(errorType: $errorType, timestamp: $timestamp)';
  }
}
