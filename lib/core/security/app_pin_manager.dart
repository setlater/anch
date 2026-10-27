import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'app_key_manager.dart';

enum AppPinErrorType {
  invalidPin,
  storageUnavailable,
  corruptedStoredPin,
  unknown,
}

class AppPinException implements Exception {
  final AppPinErrorType type;
  final String message;
  final dynamic details;

  AppPinException(this.type, this.message, [this.details]);

  @override
  String toString() {
    // 必须脱敏，绝对不包含任何敏感信息，只输出错误类型与说明
    return 'AppPinException(type: $type, message: $message)';
  }
}

abstract class AppPinManager {
  Future<bool> hasPin();
  Future<void> setPin(String pin);
  Future<bool> verifyPin(String pin);
  Future<void> clearPin();
}

class SecureStorageAppPinManager implements AppPinManager {
  final SecureKeyValueStore store;
  final int iterations;
  final List<int> Function(int length)? randomBytesForTest;

  static const String _kdfKey = 'anch.app_pin.kdf.v1';
  static const String _saltKey = 'anch.app_pin.salt.v1';
  static const String _verifierKey = 'anch.app_pin.verifier.v1';

  SecureStorageAppPinManager({
    required this.store,
    this.iterations = 60000,
    this.randomBytesForTest,
  });

  @override
  Future<bool> hasPin() async {
    try {
      final kdf = await store.read(_kdfKey);
      final salt = await store.read(_saltKey);
      final verifier = await store.read(_verifierKey);

      if (kdf != null && salt != null && verifier != null) {
        return kdf.isNotEmpty && salt.isNotEmpty && verifier.isNotEmpty;
      }
      return false;
    } catch (_) {
      throw AppPinException(AppPinErrorType.storageUnavailable, 'PIN 配置读取失败。');
    }
  }

  @override
  Future<void> setPin(String pin) async {
    if (pin.isEmpty || pin.trim().isEmpty) {
      throw AppPinException(
        AppPinErrorType.invalidPin,
        'PIN 不符合要求：密码不能为空或全空白。',
      );
    }
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
      throw AppPinException(AppPinErrorType.invalidPin, 'PIN 不符合要求：必须为 6 位数字。');
    }

    try {
      final List<int> saltBytes;
      final localRandomBytes = randomBytesForTest;
      if (localRandomBytes != null) {
        saltBytes = localRandomBytes(16);
      } else {
        final random = Random.secure();
        saltBytes = List<int>.generate(16, (_) => random.nextInt(256));
      }

      final pinKeyBytes = await _derivePinKey(pin, saltBytes, iterations);
      final verifierBytes = await _calculateHmac(pinKeyBytes);

      final saltBase64 = base64Url.encode(saltBytes);
      final verifierBase64 = base64Url.encode(verifierBytes);

      final kdfJson = json.encode({
        'version': 1,
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': iterations,
        'saltLength': 16,
        'keyLength': 32,
        'verifier': 'HMAC-SHA256(challenge)',
      });

      await store.write(_kdfKey, kdfJson);
      await store.write(_saltKey, saltBase64);
      await store.write(_verifierKey, verifierBase64);
    } catch (e) {
      if (e is AppPinException) rethrow;
      throw AppPinException(
        AppPinErrorType.storageUnavailable,
        'PIN 安全存储写入异常。',
        e,
      );
    }
  }

  @override
  Future<bool> verifyPin(String pin) async {
    if (pin.isEmpty || pin.trim().isEmpty || pin.length < 4) {
      return false;
    }

    try {
      final values = await Future.wait([
        store.read(_kdfKey),
        store.read(_saltKey),
        store.read(_verifierKey),
      ]);
      final kdfStr = values[0];
      final saltStr = values[1];
      final verifierStr = values[2];

      if (kdfStr == null && saltStr == null && verifierStr == null) {
        return false;
      }

      if (kdfStr == null || saltStr == null || verifierStr == null) {
        throw AppPinException(
          AppPinErrorType.corruptedStoredPin,
          'PIN 校验材料缺失。',
        );
      }

      Map<String, dynamic> kdfMap;
      try {
        kdfMap = json.decode(kdfStr) as Map<String, dynamic>;
      } catch (e) {
        throw AppPinException(
          AppPinErrorType.corruptedStoredPin,
          'PIN KDF 配置格式损坏。',
          e,
        );
      }

      final version = kdfMap['version'];
      final algorithm = kdfMap['algorithm'];
      final iterations = kdfMap['iterations'];

      if (version != 1 ||
          algorithm != 'PBKDF2-HMAC-SHA256' ||
          iterations is! int) {
        throw AppPinException(
          AppPinErrorType.corruptedStoredPin,
          '不支持的 PIN 校验算法或版本。',
        );
      }

      List<int> saltBytes;
      List<int> storedVerifierBytes;
      try {
        saltBytes = base64Url.decode(saltStr);
        storedVerifierBytes = base64Url.decode(verifierStr);
      } catch (e) {
        throw AppPinException(
          AppPinErrorType.corruptedStoredPin,
          'PIN 校验材料 Base64 解码失败。',
          e,
        );
      }

      final pinKeyBytes = await _derivePinKey(pin, saltBytes, iterations);
      final calculatedVerifier = await _calculateHmac(pinKeyBytes);

      if (calculatedVerifier.length != storedVerifierBytes.length) {
        return false;
      }

      var equal = true;
      for (var i = 0; i < calculatedVerifier.length; i++) {
        if (calculatedVerifier[i] != storedVerifierBytes[i]) {
          equal = false;
        }
      }
      return equal;
    } catch (e) {
      if (e is AppPinException) rethrow;
      throw AppPinException(AppPinErrorType.corruptedStoredPin, 'PIN 校验失败。', e);
    }
  }

  @override
  Future<void> clearPin() async {
    try {
      await store.delete(_kdfKey);
      await store.delete(_saltKey);
      await store.delete(_verifierKey);
    } catch (e) {
      throw AppPinException(
        AppPinErrorType.storageUnavailable,
        'PIN 安全存储清空异常。',
        e,
      );
    }
  }

  Future<List<int>> _derivePinKey(
    String pin,
    List<int> salt,
    int iterations,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = SecretKey(utf8.encode(pin));
    final derived = await pbkdf2.deriveKey(secretKey: secretKey, nonce: salt);
    return await derived.extractBytes();
  }

  Future<List<int>> _calculateHmac(List<int> pinKeyBytes) async {
    final hmac = Hmac.sha256();
    final secretKey = SecretKey(pinKeyBytes);
    final challenge = utf8.encode('anch.app_pin.verify.v1');
    final mac = await hmac.calculateMac(challenge, secretKey: secretKey);
    return mac.bytes;
  }
}
