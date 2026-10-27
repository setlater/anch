/// 数据重置模式。
enum AppDataResetMode {
  /// 清理当前设备的应用私有数据，不删除外部备份。
  physicalDelete,
}

/// 应用程序数据重置计划，限制重置包含的子步骤与破坏性操作范围。
class AppDataResetPlan {
  const AppDataResetPlan({
    required this.mode,
    required this.clearBusinessData,
    required this.clearPin,
    required this.disableAppLock,
    required this.deleteDatabaseFile,
    required this.clearDatabaseKey,
    required this.deleteBackupFiles,
  });

  /// 重置执行模式
  final AppDataResetMode mode;

  /// 是否清空本机业务数据（members/items/fields等）
  final bool clearBusinessData;

  /// 是否清除 PIN 校验材料
  final bool clearPin;

  /// 是否关闭应用锁
  final bool disableAppLock;

  /// 是否物理删除本地 SQLite 数据库文件
  final bool deleteDatabaseFile;

  /// 是否清除 KeyStore 里的 databaseKey
  final bool clearDatabaseKey;

  /// 是否删除已导出的外部备份文件；当前物理重置必须为 false
  final bool deleteBackupFiles;

  /// 是否具有破坏性重置子操作
  bool get isDestructive =>
      clearBusinessData ||
      clearPin ||
      disableAppLock ||
      deleteDatabaseFile ||
      clearDatabaseKey ||
      deleteBackupFiles;

  @override
  String toString() {
    // ⚠️ 【安全边界】确保 toString() 严格脱敏，不输出任何真实路径、PIN 或密钥
    return 'AppDataResetPlan('
        'mode: ${mode.name}, '
        'clearBusinessData: $clearBusinessData, '
        'clearPin: $clearPin, '
        'disableAppLock: $disableAppLock, '
        'deleteDatabaseFile: $deleteDatabaseFile, '
        'clearDatabaseKey: $clearDatabaseKey, '
        'deleteBackupFiles: $deleteBackupFiles)';
  }
}

/// 预置的重置计划集。
class AppDataResetPlans {
  static const AppDataResetPlan forgotPinPhysical = AppDataResetPlan(
    mode: AppDataResetMode.physicalDelete,
    clearBusinessData: true,
    clearPin: true,
    disableAppLock: true,
    deleteDatabaseFile: true,
    clearDatabaseKey: true,
    deleteBackupFiles: false,
  );
}
