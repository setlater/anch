import 'dart:io';

import 'app_data_reset_plan.dart';
import 'app_data_reset_service.dart';
import 'app_key_manager.dart';
import 'app_lock_settings_manager.dart';
import 'app_pin_manager.dart';
import 'screen_protection_settings_manager.dart';
import 'app_lock_attempt_manager.dart';
import 'app_lock_preferences_manager.dart';
import '../backup/backup_history_manager.dart';
import '../app_guidance_manager.dart';
import '../template/migration_state_store.dart';

/// 忘记 PIN 的正式本机数据销毁服务。
/// 只处理应用私有目录内明确列出的数据库与附件，不删除用户导出的备份文件。
class PhysicalAppDataResetService implements AppDataResetService {
  final AppPinManager appPinManager;
  final AppLockSettingsManager appLockSettingsManager;
  final SecureKeyValueStore keyStore;
  final Future<void> Function() closeDatabase;
  final Future<Directory> Function() documentsDirectoryProvider;
  final String databaseName;

  PhysicalAppDataResetService({
    required this.appPinManager,
    required this.appLockSettingsManager,
    required this.keyStore,
    required this.closeDatabase,
    required this.documentsDirectoryProvider,
    this.databaseName = 'anch_encrypted_dev.db',
  });

  @override
  Future<AppDataResetResult> resetAppData(AppDataResetPlan plan) async {
    if (plan.mode != AppDataResetMode.physicalDelete ||
        !plan.deleteDatabaseFile ||
        !plan.clearDatabaseKey ||
        !plan.clearPin ||
        !plan.disableAppLock ||
        plan.deleteBackupFiles) {
      throw const AppDataResetException(
        AppDataResetErrorType.unsafePlanRejected,
        '重置计划不符合本机数据销毁要求。',
      );
    }

    try {
      await closeDatabase();
      final documentsDirectory = await documentsDirectoryProvider();
      await _deleteIfExists(File('${documentsDirectory.path}/$databaseName'));
      await _deleteIfExists(
        File('${documentsDirectory.path}/$databaseName-wal'),
      );
      await _deleteIfExists(
        File('${documentsDirectory.path}/$databaseName-shm'),
      );
      await _deleteIfExists(
        Directory('${documentsDirectory.path}/attachments'),
      );
      await _deleteIfExists(
        Directory('${documentsDirectory.path}/attachment_previews'),
      );
      await _deleteIfExists(
        Directory('${documentsDirectory.path}/attachment_thumbnails'),
      );
      for (final fileName in [
        MigrationStateStore.checkpointFileName,
        '${MigrationStateStore.checkpointFileName}.tmp',
        MigrationStateStore.failureLogFileName,
        '${MigrationStateStore.failureLogFileName}.tmp',
      ]) {
        await _deleteIfExists(File('${documentsDirectory.path}/$fileName'));
      }
      await appPinManager.clearPin();
      await appLockSettingsManager.clear();
      await keyStore.delete(AppLockPreferencesManager.settingsKey);
      await keyStore.delete(AppLockAttemptManager.settingsKey);
      await keyStore.delete(BackupHistoryManager.storageKey);
      await keyStore.delete(AppGuidanceManager.storageKey);
      await keyStore.delete(SecureStorageAppKeyManager.databaseKeyStorageKey);
      await keyStore.delete(
        SecureStorageScreenProtectionSettingsManager.settingsKey,
      );
      return const AppDataResetResult(
        clearedBusinessData: true,
        clearedPin: true,
        disabledAppLock: true,
        deletedDatabaseFile: true,
        clearedDatabaseKey: true,
        deletedBackupFiles: false,
      );
    } catch (_) {
      throw const AppDataResetException(
        AppDataResetErrorType.resetFailed,
        '本机数据重置未完成，请重试。',
      );
    }
  }

  Future<void> _deleteIfExists(FileSystemEntity entity) async {
    if (await entity.exists()) {
      await entity.delete(recursive: entity is Directory);
    }
  }
}
