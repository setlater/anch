import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// 离线附件数据加密与解密核心服务类
abstract final class AttachmentCryptoService {
  AttachmentCryptoService._();

  static final Map<String, SecretKey> _keyCache = {};
  static String? _cachedDbKey;

  /// 初始化并缓存数据库主密钥，用于派生附件密钥
  static void init(String dbKey) {
    _validatedKeyBytes(dbKey);
    _cachedDbKey = dbKey;
  }

  /// 获取当前缓存的数据库主密钥
  static String get cachedDbKey => _cachedDbKey ?? '';

  /// 派生并缓存对称密钥，输入为 base64Url 编码的数据库密钥
  static Future<SecretKey> _deriveKey(String databaseKey) async {
    if (_keyCache.containsKey(databaseKey)) {
      return _keyCache[databaseKey]!;
    }

    final decoded = _validatedKeyBytes(databaseKey);
    final hash = await Sha256().hash(decoded);
    final key = SecretKey(hash.bytes);
    _keyCache[databaseKey] = key;
    return key;
  }

  static List<int> _validatedKeyBytes(String databaseKey) {
    if (databaseKey.trim().isEmpty) {
      throw StateError('附件密钥未初始化');
    }
    final decoded = base64Url.decode(databaseKey);
    if (decoded.length != 32) {
      throw StateError('附件密钥格式无效');
    }
    return decoded;
  }

  /// 加密附件原始字节
  ///
  /// 结构：nonce (12B) + mac (16B) + ciphertext
  static Future<Uint8List> encryptData(
    Uint8List plaintext, [
    String? databaseKey,
  ]) async {
    final key = databaseKey ?? _cachedDbKey ?? '';
    final secretKey = await _deriveKey(key);

    // 生成随机 12 字节 Nonce
    final random = Random.secure();
    final nonceBytes = Uint8List(12);
    for (int i = 0; i < 12; i++) {
      nonceBytes[i] = random.nextInt(256);
    }

    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonceBytes,
    );

    final ciphertext = secretBox.cipherText;
    final macBytes = secretBox.mac.bytes;

    final combined = Uint8List(12 + 16 + ciphertext.length);
    combined.setRange(0, 12, nonceBytes);
    combined.setRange(12, 28, macBytes);
    combined.setRange(28, combined.length, ciphertext);

    return combined;
  }

  /// 解密附件密文数据
  static Future<Uint8List> decryptData(
    Uint8List encryptedData, [
    String? databaseKey,
  ]) async {
    if (encryptedData.length < 28) {
      throw Exception("密文数据损坏：长度小于安全头部边界(28字节)。");
    }

    try {
      final key = databaseKey ?? _cachedDbKey ?? '';
      final secretKey = await _deriveKey(key);
      final nonceBytes = encryptedData.sublist(0, 12);
      final macBytes = encryptedData.sublist(12, 28);
      final ciphertext = encryptedData.sublist(28);
      final aesGcm = AesGcm.with256bits();
      final secretBox = SecretBox(
        ciphertext,
        nonce: nonceBytes,
        mac: Mac(macBytes),
      );
      final decrypted = await aesGcm.decrypt(secretBox, secretKey: secretKey);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      throw Exception("解密附件失败：密码不匹配或数据已被篡改。");
    }
  }
}
