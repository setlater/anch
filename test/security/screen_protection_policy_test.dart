@Tags(['security'])
library;

import 'dart:async';

import 'package:anch/core/security/android_secure_window_service.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/screen_protection_controller.dart';
import 'package:anch/core/security/screen_protection_settings_manager.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingSecureWindowService implements SecureWindowService {
  final List<bool> values = <bool>[];

  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {
    values.add(enabled);
  }
}

class _UnreadableStore implements SecureKeyValueStore {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => throw Exception('unreadable');

  @override
  Future<void> write(String key, String value) async {}
}

class _ControlledWindowService implements SecureWindowService {
  bool failEnable = false;
  bool protected = false;
  Completer<void>? disableStarted;
  Completer<void>? disablePending;

  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {
    if (enabled && failEnable) throw StateError('simulated platform failure');
    if (!enabled && disablePending != null) {
      disableStarted?.complete();
      await disablePending!.future;
    }
    protected = enabled;
  }
}

void main() {
  group('屏幕内容保护偏好', () {
    test('缺失、损坏或读取失败时均安全回退到仅保护敏感页面', () async {
      final emptyStore = MemorySecureKeyValueStore();
      final emptyManager = SecureStorageScreenProtectionSettingsManager(
        store: emptyStore,
      );
      expect(await emptyManager.loadMode(), ScreenProtectionMode.sensitiveOnly);

      await emptyStore.write(
        SecureStorageScreenProtectionSettingsManager.settingsKey,
        'invalid',
      );
      expect(await emptyManager.loadMode(), ScreenProtectionMode.sensitiveOnly);

      final unreadableManager = SecureStorageScreenProtectionSettingsManager(
        store: _UnreadableStore(),
      );
      expect(
        await unreadableManager.loadMode(),
        ScreenProtectionMode.sensitiveOnly,
      );
    });

    test('三档模式可持久化但不依赖业务数据库', () async {
      final store = MemorySecureKeyValueStore();
      final manager = SecureStorageScreenProtectionSettingsManager(
        store: store,
      );

      for (final mode in ScreenProtectionMode.values) {
        await manager.saveMode(mode);
        expect(await manager.loadMode(), mode);
      }
    });
  });

  group('屏幕内容保护决策', () {
    test('保护失败可见且不可通过切换偏好绕过，显式重试恢复', () async {
      final service = _ControlledWindowService();
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: service,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      service.failEnable = true;
      await controller.setContentSensitivity(Object(), true);
      expect(controller.shouldProtect, isTrue);
      expect(controller.hasProtectionFailure, isTrue);
      expect(controller.isForegroundProtected, isFalse);
      expect(service.protected, isFalse);

      await controller.setMode(ScreenProtectionMode.unrestricted);
      expect(controller.mode, ScreenProtectionMode.sensitiveOnly);
      await controller.retryProtection();
      expect(controller.hasProtectionFailure, isTrue);

      service.failEnable = false;
      await controller.retryProtection();
      expect(controller.hasProtectionFailure, isFalse);
      expect(controller.isForegroundProtected, isTrue);
      expect(service.protected, isTrue);
    });

    test('旧关闭请求尚未结束时，不将新敏感页面视为已保护', () async {
      final service = _ControlledWindowService();
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: service,
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.setContentSensitivity(Object(), true);
      service.disableStarted = Completer<void>();
      service.disablePending = Completer<void>();
      final disable = controller.setMode(ScreenProtectionMode.unrestricted);
      await service.disableStarted!.future;
      final enable = controller.setMode(ScreenProtectionMode.always);
      expect(controller.isForegroundProtected, isFalse);
      service.disablePending!.complete();
      await Future.wait([disable, enable]);
      expect(controller.isForegroundProtected, isTrue);
      expect(service.protected, isTrue);
    });

    test('默认只在敏感页面开启安全窗口', () async {
      final service = _RecordingSecureWindowService();
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: service,
      );
      final source = Object();

      await controller.initialize();
      expect(controller.mode, ScreenProtectionMode.sensitiveOnly);
      expect(controller.shouldProtect, isFalse);

      await controller.setContentSensitivity(source, true);
      expect(controller.shouldProtect, isTrue);

      await controller.setContentSensitivity(source, null);
      expect(controller.shouldProtect, isFalse);
      expect(service.values, <bool>[false, true, false]);
    });

    test('不限制模式忽略短暂 inactive，但真正后台仍始终保护', () async {
      final service = _RecordingSecureWindowService();
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: service,
      );
      final source = Object();
      await controller.initialize();

      await controller.setMode(ScreenProtectionMode.always);
      expect(controller.shouldProtect, isTrue);
      await controller.setContentSensitivity(source, true);
      expect(controller.shouldProtect, isTrue);

      await controller.setMode(ScreenProtectionMode.unrestricted);
      expect(controller.shouldProtect, isFalse);
      await controller.handleLifecycleState(AppLifecycleState.inactive);
      expect(controller.shouldProtect, isFalse);
      await controller.handleLifecycleState(AppLifecycleState.hidden);
      expect(controller.shouldProtect, isTrue);
      await controller.handleLifecycleState(AppLifecycleState.inactive);
      expect(controller.shouldProtect, isTrue);
      await controller.handleLifecycleState(AppLifecycleState.resumed);
      expect(controller.shouldProtect, isFalse);
    });

    test('真正后台由原生任务快照保护，不能改变前台截图策略', () async {
      final service = _RecordingSecureWindowService();
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: service,
      );
      await controller.initialize();
      await controller.setMode(ScreenProtectionMode.unrestricted);

      await controller.handleLifecycleState(AppLifecycleState.hidden);

      expect(controller.shouldProtect, isTrue);
      expect(service.values, <bool>[false]);
    });

    test('后台优先级高于全部前台模式，恢复后回到原模式决策', () async {
      for (final mode in ScreenProtectionMode.values) {
        final service = _RecordingSecureWindowService();
        final controller = ScreenProtectionController(
          settingsManager: SecureStorageScreenProtectionSettingsManager(
            store: MemorySecureKeyValueStore(),
          ),
          secureWindowService: service,
        );
        await controller.initialize();
        await controller.setMode(mode);
        final beforeBackground = controller.shouldProtect;

        await controller.handleLifecycleState(AppLifecycleState.paused);
        expect(controller.shouldProtect, isTrue);
        await controller.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.shouldProtect, beforeBackground);
      }
    });

    test('最上层页面声明覆盖仍挂载的下层页面，退出后恢复下层决策', () async {
      final controller = ScreenProtectionController(
        settingsManager: SecureStorageScreenProtectionSettingsManager(
          store: MemorySecureKeyValueStore(),
        ),
        secureWindowService: _RecordingSecureWindowService(),
      );
      await controller.initialize();
      final summaryList = Object();
      final settings = Object();
      final pinSetup = Object();

      await controller.setContentSensitivity(summaryList, false);
      expect(controller.shouldProtect, isFalse);
      await controller.setContentSensitivity(settings, false);
      expect(controller.shouldProtect, isFalse);
      await controller.setContentSensitivity(pinSetup, true);
      expect(controller.shouldProtect, isTrue);
      await controller.setContentSensitivity(pinSetup, null);
      expect(controller.shouldProtect, isFalse);
      await controller.setContentSensitivity(settings, null);
      expect(controller.shouldProtect, isFalse);
    });
  });
}
