@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_lock_settings_manager.dart';

void main() {
  group('SecureStorageAppLockSettingsManager 单元测试', () {
    late MemorySecureKeyValueStore store;
    late SecureStorageAppLockSettingsManager manager;

    setUp(() {
      store = MemorySecureKeyValueStore();
      manager = SecureStorageAppLockSettingsManager(store: store);
    });

    test('验证 1. 默认未设置时，isAppLockEnabled 返回 false', () async {
      expect(await manager.isAppLockEnabled(), isFalse);
    });

    test('验证 2. setAppLockEnabled(true) 能够正确持久化并返回 true', () async {
      await manager.setAppLockEnabled(true);
      expect(await manager.isAppLockEnabled(), isTrue);

      // 直接从 store 中读取底层 JSON
      final dataStr = await store.read('anch.app_lock.enabled.v1');
      expect(dataStr, isNotNull);
      expect(dataStr, contains('"enabled":true'));
      expect(dataStr, contains('"version":1'));
    });

    test('验证 3. setAppLockEnabled(false) 返回 false，且不影响 PIN 数据', () async {
      await manager.setAppLockEnabled(false);
      expect(await manager.isAppLockEnabled(), isFalse);

      final dataStr = await store.read('anch.app_lock.enabled.v1');
      expect(dataStr, contains('"enabled":false'));
    });

    test(
      '验证 4. clear 仅清除应用锁状态，不影响其他 key，且 isAppLockEnabled 返回 false',
      () async {
        // 在 store 中模拟写入 PIN 相关的 key
        await store.write('anch.app_pin.verifier.v1', 'PIN-verifier');
        await store.write('anch.app_pin.salt.v1', 'PIN-salt');

        await manager.setAppLockEnabled(true);
        expect(await manager.isAppLockEnabled(), isTrue);

        await manager.clear();
        expect(await manager.isAppLockEnabled(), isFalse);

        // 验证应用锁状态键已被清除
        expect(await store.read('anch.app_lock.enabled.v1'), isNull);

        // 验证 PIN 相关的 key 依然完好无损地保留着
        expect(await store.read('anch.app_pin.verifier.v1'), 'PIN-verifier');
        expect(await store.read('anch.app_pin.salt.v1'), 'PIN-salt');
      },
    );

    test('验证 5. 非缺失记录格式损坏时抛出脱敏异常，不作为关闭状态', () async {
      for (final raw in [
        '',
        '   ',
        '{invalid-json}',
        'null',
        '[]',
        '{}',
        '{"version":2,"enabled":true}',
        '{"version":1}',
        '{"version":1,"enabled":"true"}',
      ]) {
        await store.write('anch.app_lock.enabled.v1', raw);
        await expectLater(
          manager.isAppLockEnabled(),
          throwsA(isA<AppLockSettingsException>()),
        );
      }
    });

    test('底层读取失败上抛脱敏异常，已有设置不被改写', () async {
      final failedStore = _ReadFailureStore();
      final failedManager = SecureStorageAppLockSettingsManager(
        store: failedStore,
      );
      await failedManager.setAppLockEnabled(true);
      failedStore.fail = true;
      await expectLater(
        failedManager.isAppLockEnabled(),
        throwsA(isA<AppLockSettingsException>()),
      );
      failedStore.fail = false;
      expect(await failedManager.isAppLockEnabled(), isTrue);
    });

    test('验证 6. AppLockSettingsException 脱敏 toString 表现', () {
      final exception = AppLockSettingsException(
        '存储损坏的 JSON 原始值：{"version":1,"enabled":"secret-value"}',
        'databaseKey-123456-secret-leak',
      );
      final str = exception.toString();

      expect(str, contains('AppLockSettingsException'));

      // 必须确保不泄露任何 databaseKey、原始 JSON 泄露字段
      expect(str, isNot(contains('secret-value')));
      expect(str, isNot(contains('databaseKey')));
      expect(str, isNot(contains('123456')));
    });
  });
}

class _ReadFailureStore extends MemorySecureKeyValueStore {
  bool fail = false;

  @override
  Future<String?> read(String key) {
    if (fail) throw StateError('SYNTHETIC_READ_FAILURE');
    return super.read(key);
  }
}
