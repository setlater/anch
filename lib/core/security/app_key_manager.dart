import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'app_startup_failure.dart';

/// 安全键值对存储的抽象接口，方便进行单元测试
abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// 生产环境的实现，使用 flutter_secure_storage
class FlutterSecureKeyValueStore implements SecureKeyValueStore {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );

  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

/// 单元测试使用的内存实现，不依赖宿主机/平台 Channel
class MemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async {
    return _data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}

/// 密钥管理器接口
abstract interface class AppKeyManager {
  Future<String> getOrCreateDatabaseKey();
}

/// 基于 SecureKeyValueStore 的密钥管理器实现
class SecureStorageAppKeyManager implements AppKeyManager {
  final SecureKeyValueStore _store;
  static const String databaseKeyStorageKey = 'anch.database.key.v1';

  SecureStorageAppKeyManager({SecureKeyValueStore? store})
    : _store = store ?? FlutterSecureKeyValueStore();

  @override
  Future<String> getOrCreateDatabaseKey() async {
    final String? existingKey;
    try {
      existingKey = await _store.read(databaseKeyStorageKey);
    } catch (e) {
      throw AppStartupException(
        AppStartupFailureType.secureStorageUnavailable,
        '安全存储数据库密钥读取异常。',
        e,
      );
    }

    if (existingKey != null) {
      // 校验已存在的密钥格式是否合法
      try {
        final decodedBytes = base64Url.decode(existingKey);
        if (decodedBytes.length != 32) {
          throw AppStartupException(
            AppStartupFailureType.invalidStoredKey,
            '已存储数据库密钥长度非法，当前为 ${decodedBytes.length} 字节（应为 32 字节）。',
          );
        }
      } catch (e) {
        if (e is AppStartupException) rethrow;
        throw AppStartupException(
          AppStartupFailureType.invalidStoredKey,
          '已存储数据库密钥 Base64URL 解码失败。',
          e,
        );
      }
      return existingKey;
    }

    // 首次启动，生成 256-bit (32 bytes) 随机主密钥并编码。
    // 主密钥由平台安全存储保护，绝不进入日志、UI、备份或异常文本。
    final String keyString;
    try {
      final random = Random.secure();
      final randomBytes = List<int>.generate(32, (_) => random.nextInt(256));
      keyString = base64UrlEncode(randomBytes);
    } catch (e) {
      throw AppStartupException(
        AppStartupFailureType.unknown,
        '安全随机数据库密钥生成异常。',
        e,
      );
    }

    try {
      await _store.write(databaseKeyStorageKey, keyString);
    } catch (e) {
      throw AppStartupException(
        AppStartupFailureType.secureStorageUnavailable,
        '安全存储数据库密钥写入异常。',
        e,
      );
    }

    return keyString;
  }
}
