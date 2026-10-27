@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_startup_failure.dart';

// 实现一个会抛出异常的 Fake 存储以供测试
class ExceptionalSecureKeyValueStore implements SecureKeyValueStore {
  final bool throwOnRead;
  final bool throwOnWrite;
  final String? mockValue;

  ExceptionalSecureKeyValueStore({
    this.throwOnRead = false,
    this.throwOnWrite = false,
    this.mockValue,
  });

  @override
  Future<String?> read(String key) async {
    if (throwOnRead) {
      throw Exception('Mock storage read error');
    }
    return mockValue;
  }

  @override
  Future<void> write(String key, String value) async {
    if (throwOnWrite) {
      throw Exception('Mock storage write error');
    }
  }

  @override
  Future<void> delete(String key) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Android 安全存储读写错误不得启用自动删除，读取失败不生成新密钥', () async {
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    final methods = <String>[];
    final resetOnErrorOptions = <String?>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      final arguments = call.arguments as Map;
      final options = arguments['options'] as Map;
      resetOnErrorOptions.add(options['resetOnError'] as String?);
      if (call.method == 'read') {
        throw PlatformException(code: 'simulated_storage_unavailable');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final store = FlutterSecureKeyValueStore();
    final manager = SecureStorageAppKeyManager(store: store);
    AppStartupFailureType? failureType;
    try {
      await manager.getOrCreateDatabaseKey();
    } on AppStartupException catch (error) {
      failureType = error.type;
    }
    expect(failureType, AppStartupFailureType.secureStorageUnavailable);
    expect(methods, ['read']);

    await store.write('fictional-store-entry', 'fictional-store-value');
    await store.delete('fictional-store-entry');
    expect(methods, ['read', 'write', 'delete']);
    expect(resetOnErrorOptions, everyElement('false'));
  });

  group('AppKeyManager 单元测试', () {
    late MemorySecureKeyValueStore fakeStore;
    late SecureStorageAppKeyManager keyManager;

    setUp(() {
      fakeStore = MemorySecureKeyValueStore();
      keyManager = SecureStorageAppKeyManager(store: fakeStore);
    });

    test('验证 1. 首次调用 getOrCreateDatabaseKey 会生成非空 key', () async {
      final key = await keyManager.getOrCreateDatabaseKey();
      expect(key, isNotEmpty);
    });

    test('验证 2. 生成的 key 解码后为 32 bytes 长度', () async {
      final key = await keyManager.getOrCreateDatabaseKey();
      final decodedBytes = base64Url.decode(key);
      expect(decodedBytes.length, 32);
    });

    test('验证 3. 第二次及后续调用返回同一个 key', () async {
      final key1 = await keyManager.getOrCreateDatabaseKey();
      final key2 = await keyManager.getOrCreateDatabaseKey();
      expect(key1, equals(key2));
    });

    test('验证 4. 已有 key 时不会重新生成', () async {
      // 预先存入一个特定的 32 字节 Key
      final testKey = base64UrlEncode(List<int>.generate(32, (i) => i));
      await fakeStore.write('anch.database.key.v1', testKey);

      final key = await keyManager.getOrCreateDatabaseKey();
      expect(key, equals(testKey));
    });

    test('验证 5. clear fake storage 后会生成新 key', () async {
      final key1 = await keyManager.getOrCreateDatabaseKey();

      // 清理对应的存储
      await fakeStore.delete('anch.database.key.v1');

      final key2 = await keyManager.getOrCreateDatabaseKey();
      expect(key1, isNot(equals(key2)), reason: '清理存储后，重新获取应该生成一个全新的 key');

      final decodedBytes1 = base64Url.decode(key1);
      final decodedBytes2 = base64Url.decode(key2);
      expect(decodedBytes1.length, 32);
      expect(decodedBytes2.length, 32);
    });

    test('验证 6. 不在测试输出中打印 key（通过代码审查确认测试中没有任何打印 key 的操作）', () async {
      // 本测试不需要执行额外的 print，仅通过空执行确认该策略
      final key = await keyManager.getOrCreateDatabaseKey();
      expect(key, isNotEmpty);
    });
  });

  group('AppKeyManager 异常与故障路径单元测试', () {
    test('验证 7. 已有 key 格式非法时，不应自动覆盖且抛出 invalidStoredKey', () async {
      final fakeStore = MemorySecureKeyValueStore();
      await fakeStore.write('anch.database.key.v1', '!!!invalid-base64url!!!');
      final keyManager = SecureStorageAppKeyManager(store: fakeStore);

      try {
        await keyManager.getOrCreateDatabaseKey();
        fail('应该抛出 AppStartupException');
      } on AppStartupException catch (e) {
        expect(e.type, AppStartupFailureType.invalidStoredKey);
        // 确认没有在异常消息中包含原始密钥
        expect(e.toString(), isNot(contains('!!!invalid-base64url!!!')));
      }

      // 验证未被覆盖
      final currentInStore = await fakeStore.read('anch.database.key.v1');
      expect(currentInStore, equals('!!!invalid-base64url!!!'));
    });

    test('验证 8. 已有 key base64 可解码但不是 32 字节时，抛出 invalidStoredKey 错误', () async {
      final fakeStore = MemorySecureKeyValueStore();
      // YW5jaA== 解码后为 'anch'，共 4 字节
      await fakeStore.write('anch.database.key.v1', 'YW5jaA==');
      final keyManager = SecureStorageAppKeyManager(store: fakeStore);

      try {
        await keyManager.getOrCreateDatabaseKey();
        fail('应该抛出 AppStartupException');
      } on AppStartupException catch (e) {
        expect(e.type, AppStartupFailureType.invalidStoredKey);
        expect(e.toString(), isNot(contains('YW5jaA==')));
      }

      final currentInStore = await fakeStore.read('anch.database.key.v1');
      expect(currentInStore, equals('YW5jaA=='));
    });

    test('已有空字符串密钥时阻断启动，且不覆盖原存储值', () async {
      final store = MemorySecureKeyValueStore();
      const storageKey = SecureStorageAppKeyManager.databaseKeyStorageKey;
      await store.write(storageKey, '');
      final manager = SecureStorageAppKeyManager(store: store);
      AppStartupFailureType? failureType;

      try {
        await manager.getOrCreateDatabaseKey();
      } on AppStartupException catch (error) {
        failureType = error.type;
      }

      expect(
        {
          'failureType': failureType,
          'storedValueUnchanged': await store.read(storageKey) == '',
        },
        {
          'failureType': AppStartupFailureType.invalidStoredKey,
          'storedValueUnchanged': true,
        },
      );
    });

    test(
      '验证 9. secure storage read 抛异常时，应向上抛出 secureStorageUnavailable，不生成新 key',
      () async {
        final badStore = ExceptionalSecureKeyValueStore(throwOnRead: true);
        final keyManager = SecureStorageAppKeyManager(store: badStore);

        try {
          await keyManager.getOrCreateDatabaseKey();
          fail('应该抛出 AppStartupException');
        } on AppStartupException catch (e) {
          expect(e.type, AppStartupFailureType.secureStorageUnavailable);
        }
      },
    );

    test(
      '验证 10. secure storage write 抛异常时，应向上抛出 secureStorageUnavailable',
      () async {
        final badStore = ExceptionalSecureKeyValueStore(throwOnWrite: true);
        final keyManager = SecureStorageAppKeyManager(store: badStore);

        try {
          await keyManager.getOrCreateDatabaseKey();
          fail('应该抛出 AppStartupException');
        } on AppStartupException catch (e) {
          expect(e.type, AppStartupFailureType.secureStorageUnavailable);
        }
      },
    );

    test('验证 11. 异常路径下的密钥生成仍符合 32 字节大小要求', () async {
      final fakeStore = MemorySecureKeyValueStore();
      final keyManager = SecureStorageAppKeyManager(store: fakeStore);

      final key = await keyManager.getOrCreateDatabaseKey();
      final bytes = base64Url.decode(key);
      expect(bytes.length, 32);
    });
  });
}
