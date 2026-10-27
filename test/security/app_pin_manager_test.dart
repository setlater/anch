@Tags(['security'])
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';

void main() {
  group('SecureStorageAppPinManager 单元测试', () {
    late MemorySecureKeyValueStore store;

    setUp(() {
      store = MemorySecureKeyValueStore();
    });

    SecureStorageAppPinManager createManager({int iterations = 10}) {
      return SecureStorageAppPinManager(store: store, iterations: iterations);
    }

    test('验证 1. setPin 之后 hasPin 为 true，校验正确密码成功，校验错误密码返回 false', () async {
      final manager = createManager();
      expect(await manager.hasPin(), isFalse);

      await manager.setPin('123456');
      expect(await manager.hasPin(), isTrue);

      final correct = await manager.verifyPin('123456');
      expect(correct, isTrue);

      final incorrect = await manager.verifyPin('wrong-pin');
      expect(incorrect, isFalse);
    });

    test('验证 2. clearPin 之后 hasPin 为 false 且无法验证', () async {
      final manager = createManager();
      await manager.setPin('123456');
      expect(await manager.hasPin(), isTrue);

      await manager.clearPin();
      expect(await manager.hasPin(), isFalse);

      expect(await manager.verifyPin('123456'), isFalse);
    });

    test('验证 3. 新 PIN 必须为 6 位数字', () async {
      final manager = createManager();

      // 空
      expect(
        () => manager.setPin(''),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.invalidPin,
          ),
        ),
      );

      // 全空白
      expect(
        () => manager.setPin('      '),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.invalidPin,
          ),
        ),
      );

      // 长度不够
      expect(
        () => manager.setPin('123'),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.invalidPin,
          ),
        ),
      );

      expect(() => manager.setPin('123  '), throwsA(isA<AppPinException>()));
    });

    test('验证 4. 同一个 PIN 连续 setPin 会生成不同的 salt 和 verifier', () async {
      final manager = createManager();

      await manager.setPin('123456');
      final salt1 = await store.read('anch.app_pin.salt.v1');
      final verifier1 = await store.read('anch.app_pin.verifier.v1');

      await manager.setPin('123456');
      final salt2 = await store.read('anch.app_pin.salt.v1');
      final verifier2 = await store.read('anch.app_pin.verifier.v1');

      expect(salt1, isNotNull);
      expect(salt2, isNotNull);
      expect(salt1, isNot(salt2));
      expect(verifier1, isNot(verifier2));
    });

    test('验证 5. 重启重建 manager 后能继续用相同的 store 校验通过', () async {
      await createManager().setPin('123456');

      // 新建 manager，共享同一个 store
      final newManager = createManager();
      expect(await newManager.hasPin(), isTrue);
      expect(await newManager.verifyPin('123456'), isTrue);
    });

    test('验证 6. clearPin 后 store 中不残留任何相关 key', () async {
      final manager = createManager();
      await manager.setPin('123456');

      await manager.clearPin();
      expect(await store.read('anch.app_pin.kdf.v1'), isNull);
      expect(await store.read('anch.app_pin.salt.v1'), isNull);
      expect(await store.read('anch.app_pin.verifier.v1'), isNull);
    });

    test('验证 7. salt 异常损坏时 verifyPin 抛出 corruptedStoredPin', () async {
      final manager = createManager();
      await manager.setPin('123456');

      // 破坏 salt 为非法 base64
      await store.write('anch.app_pin.salt.v1', '!!!invalid-base64!!!');

      expect(
        () => manager.verifyPin('123456'),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.corruptedStoredPin,
          ),
        ),
      );
    });

    test('验证 8. verifier 异常损坏时 verifyPin 抛出 corruptedStoredPin', () async {
      final manager = createManager();
      await manager.setPin('123456');

      // 破坏 verifier 为非法 base64
      await store.write('anch.app_pin.verifier.v1', '!!!invalid-base64!!!');

      expect(
        () => manager.verifyPin('123456'),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.corruptedStoredPin,
          ),
        ),
      );
    });

    test('验证 9. KDF 算法不支持时 verifyPin 抛出 corruptedStoredPin', () async {
      final manager = createManager();
      await manager.setPin('123456');

      // 改写 kdf algorithm 为不支持算法
      final badKdf = json.encode({
        'version': 1,
        'algorithm': 'MD5',
        'iterations': 10,
        'saltLength': 16,
        'keyLength': 32,
      });
      await store.write('anch.app_pin.kdf.v1', badKdf);

      expect(
        () => manager.verifyPin('123456'),
        throwsA(
          isA<AppPinException>().having(
            (e) => e.type,
            'type',
            AppPinErrorType.corruptedStoredPin,
          ),
        ),
      );
    });

    test('验证 10. AppPinException 脱敏表现', () {
      final exc = AppPinException(
        AppPinErrorType.invalidPin,
        'PIN 不符合要求：密码长度至少为 6 位。',
        'sensitive-debug-details-123456-salt-verifier',
      );
      final str = exc.toString();
      expect(str, contains('AppPinException'));
      expect(str, contains('invalidPin'));
      expect(str, isNot(contains('123456')));
      expect(str, isNot(contains('salt')));
      expect(str, isNot(contains('verifier')));
      expect(str, isNot(contains('sensitive-debug-details')));
    });

    test('验证 11. 校验 PIN 时并发读取全部校验材料', () async {
      final delayedStore = _GateReadStore();
      final manager = SecureStorageAppPinManager(
        store: delayedStore,
        iterations: 10,
      );
      await manager.setPin('123456');

      delayedStore.blockReads();
      final verification = manager.verifyPin('123456');
      await Future<void>.delayed(Duration.zero);

      expect(
        delayedStore.readKeys,
        containsAll([
          'anch.app_pin.kdf.v1',
          'anch.app_pin.salt.v1',
          'anch.app_pin.verifier.v1',
        ]),
      );

      delayedStore.releaseReads();
      expect(await verification, isTrue);
    });

    test('hasPin 的任一元数据读取失败均上抛 storageUnavailable', () async {
      for (final key in [
        'anch.app_pin.kdf.v1',
        'anch.app_pin.salt.v1',
        'anch.app_pin.verifier.v1',
      ]) {
        final manager = SecureStorageAppPinManager(
          store: _ReadFailureStore(key),
        );
        await expectLater(
          manager.hasPin(),
          throwsA(
            isA<AppPinException>().having(
              (error) => error.type,
              'type',
              AppPinErrorType.storageUnavailable,
            ),
          ),
        );
      }
    });
  });
}

class _ReadFailureStore extends MemorySecureKeyValueStore {
  _ReadFailureStore(this.failingKey);

  final String failingKey;

  @override
  Future<String?> read(String key) {
    if (key == failingKey) throw StateError('SYNTHETIC_READ_FAILURE');
    return super.read(key);
  }
}

class _GateReadStore implements SecureKeyValueStore {
  final Map<String, String> _values = {};
  final List<String> readKeys = [];
  Completer<void>? _readGate;

  void blockReads() {
    _readGate = Completer<void>();
  }

  void releaseReads() {
    _readGate?.complete();
    _readGate = null;
  }

  @override
  Future<String?> read(String key) async {
    readKeys.add(key);
    await _readGate?.future;
    return _values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}
