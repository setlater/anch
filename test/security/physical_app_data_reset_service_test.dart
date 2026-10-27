@Tags(['security', 'platform'])
library;

import 'dart:io';

import 'package:anch/core/security/app_data_reset_plan.dart';
import 'package:anch/core/security/app_data_reset_service.dart';
import 'package:anch/core/backup/backup_history_manager.dart';
import 'package:anch/core/app_guidance_manager.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/physical_app_data_reset_service.dart';
import 'package:anch/core/security/screen_protection_settings_manager.dart';
import 'package:anch/core/template/migration_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

class _PinManager implements AppPinManager {
  bool cleared = false;
  @override
  Future<void> clearPin() async => cleared = true;
  @override
  Future<bool> hasPin() async => true;
  @override
  Future<void> setPin(String pin) async {}
  @override
  Future<bool> verifyPin(String pin) async => false;
}

class _LockSettings implements AppLockSettingsManager {
  bool cleared = false;
  @override
  Future<void> clear() async => cleared = true;
  @override
  Future<bool> isAppLockEnabled() async => true;
  @override
  Future<void> setAppLockEnabled(bool enabled) async {}
}

void main() {
  test('不完整计划和删除外部备份的计划在任何 I/O 前被拒绝', () async {
    final pinManager = _PinManager();
    final settings = _LockSettings();
    var touchedStorage = false;
    final service = PhysicalAppDataResetService(
      appPinManager: pinManager,
      appLockSettingsManager: settings,
      keyStore: MemorySecureKeyValueStore(),
      closeDatabase: () async => touchedStorage = true,
      documentsDirectoryProvider: () async {
        touchedStorage = true;
        throw StateError('TEST unexpected I/O');
      },
    );
    for (final omitted in ['database', 'key', 'pin', 'lock', 'backup']) {
      final plan = AppDataResetPlan(
        mode: AppDataResetMode.physicalDelete,
        clearBusinessData: true,
        clearPin: omitted != 'pin',
        disableAppLock: omitted != 'lock',
        deleteDatabaseFile: omitted != 'database',
        clearDatabaseKey: omitted != 'key',
        deleteBackupFiles: omitted == 'backup',
      );
      await expectLater(
        service.resetAppData(plan),
        throwsA(
          isA<AppDataResetException>().having(
            (error) => error.type,
            'type',
            AppDataResetErrorType.unsafePlanRejected,
          ),
        ),
      );
    }
    expect(touchedStorage, isFalse);
    expect(pinManager.cleared, isFalse);
    expect(settings.cleared, isFalse);
  });

  test('忘记 PIN 物理重置只清应用私有数据，不删除外部备份', () async {
    final directory = await Directory.systemTemp.createTemp('anch-reset-');
    addTearDown(() => directory.delete(recursive: true));
    final pinManager = _PinManager();
    final lockSettings = _LockSettings();
    final keyStore = MemorySecureKeyValueStore();
    await keyStore.write(
      SecureStorageAppKeyManager.databaseKeyStorageKey,
      'key',
    );
    await keyStore.write(
      SecureStorageScreenProtectionSettingsManager.settingsKey,
      'setting',
    );
    await keyStore.write(BackupHistoryManager.storageKey, 'history');
    await keyStore.write(AppGuidanceManager.storageKey, 'guidance');
    for (final suffix in ['', '-wal', '-shm']) {
      await File(
        '${directory.path}/anch_encrypted_dev.db$suffix',
      ).writeAsString('x');
    }
    final attachments = Directory('${directory.path}/attachments');
    await attachments.create();
    await File('${attachments.path}/file.enc').writeAsString('x');
    final previews = Directory('${directory.path}/attachment_previews');
    await previews.create();
    await File('${previews.path}/file.enc.preview.enc').writeAsString('x');
    final thumbnails = Directory('${directory.path}/attachment_thumbnails');
    await thumbnails.create();
    await File('${thumbnails.path}/file.enc.thumbnail.enc').writeAsString('x');
    final migrationStateFiles = [
      MigrationStateStore.checkpointFileName,
      '${MigrationStateStore.checkpointFileName}.tmp',
      MigrationStateStore.failureLogFileName,
      '${MigrationStateStore.failureLogFileName}.tmp',
    ];
    for (final fileName in migrationStateFiles) {
      await File('${directory.path}/$fileName').writeAsString('x');
    }
    final backup = File('${directory.path}/manual.abk');
    await backup.writeAsString('backup');
    var closed = false;
    final service = PhysicalAppDataResetService(
      appPinManager: pinManager,
      appLockSettingsManager: lockSettings,
      keyStore: keyStore,
      closeDatabase: () async => closed = true,
      documentsDirectoryProvider: () async => directory,
    );

    final result = await service.resetAppData(
      AppDataResetPlans.forgotPinPhysical,
    );

    expect(closed, isTrue);
    expect(pinManager.cleared, isTrue);
    expect(lockSettings.cleared, isTrue);
    expect(await attachments.exists(), isFalse);
    expect(await previews.exists(), isFalse);
    expect(await thumbnails.exists(), isFalse);
    for (final fileName in migrationStateFiles) {
      expect(await File('${directory.path}/$fileName').exists(), isFalse);
    }
    expect(
      await File('${directory.path}/anch_encrypted_dev.db').exists(),
      isFalse,
    );
    expect(
      await keyStore.read(SecureStorageAppKeyManager.databaseKeyStorageKey),
      isNull,
    );
    expect(
      await keyStore.read(
        SecureStorageScreenProtectionSettingsManager.settingsKey,
      ),
      isNull,
    );
    expect(await keyStore.read(BackupHistoryManager.storageKey), isNull);
    expect(await keyStore.read(AppGuidanceManager.storageKey), isNull);
    expect(await backup.exists(), isTrue);
    expect(result.deletedDatabaseFile, isTrue);
    expect(result.clearedDatabaseKey, isTrue);
  });
}
