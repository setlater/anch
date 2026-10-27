import 'app_data_reset_plan.dart';

/// 应用程序数据重置异常错误类型。
enum AppDataResetErrorType {
  /// 不支持或非法的重置操作组合
  unsupportedOperation,

  /// 重置子操作执行失败
  resetFailed,

  /// 拒绝执行不安全重置计划（例如试图在 dry-run 中物理删除数据库）
  unsafePlanRejected,

  /// 未知错误
  unknown,
}

/// 重置异常，重写 [toString] 保证严格脱敏，不输出敏感详情或堆栈信息。
class AppDataResetException implements Exception {
  final AppDataResetErrorType type;
  final String message;
  final dynamic details;

  const AppDataResetException(this.type, this.message, [this.details]);

  @override
  String toString() {
    // ⚠️ 【安全边界】脱敏处理：只输出公共异常属性，绝不包含 PIN 码、密钥以及未过滤堆栈信息
    return 'AppDataResetException(type: $type, message: $message)';
  }
}

/// 应用程序重置执行结果。
class AppDataResetResult {
  const AppDataResetResult({
    required this.clearedBusinessData,
    required this.clearedPin,
    required this.disabledAppLock,
    required this.deletedDatabaseFile,
    required this.clearedDatabaseKey,
    required this.deletedBackupFiles,
    this.seededDefaults = false,
  });

  /// 是否清空了业务数据
  final bool clearedBusinessData;

  /// 是否清空了 PIN
  final bool clearedPin;

  /// 是否关闭了应用锁
  final bool disabledAppLock;

  /// 是否物理删除了 SQLite 数据库文件
  final bool deletedDatabaseFile;

  /// 是否清除了 KeyStore 数据库密钥
  final bool clearedDatabaseKey;

  /// 是否删除了备份文件
  final bool deletedBackupFiles;

  /// 是否重新填充了默认系统成员/种子数据
  final bool seededDefaults;

  @override
  String toString() {
    // ⚠️ 【安全边界】确保 toString() 脱敏，无密钥和路径
    return 'AppDataResetResult('
        'clearedBusinessData: $clearedBusinessData, '
        'clearedPin: $clearedPin, '
        'disabledAppLock: $disabledAppLock, '
        'deletedDatabaseFile: $deletedDatabaseFile, '
        'clearedDatabaseKey: $clearedDatabaseKey, '
        'deletedBackupFiles: $deletedBackupFiles, '
        'seededDefaults: $seededDefaults)';
  }
}

/// 应用程序数据重置服务抽象类。
abstract class AppDataResetService {
  /// 根据计划重置 App 数据，返回执行结果。
  Future<AppDataResetResult> resetAppData(AppDataResetPlan plan);
}
