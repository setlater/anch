import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'backup_envelope.dart';
import 'backup_payload.dart';

/// 备份加解密异常类。
///
/// ⚠️ 【安全边界】
/// 1. 任何本类实例的 [toString] 或是抛出的 [message]，**绝对严禁**包含用户的明文密码、派生的加密 key、
///    `TEST-*` 假数据明文、完整密文串或完整 payload，以防敏感信息被控制台或异常收集系统泄露。
class BackupCryptoException implements Exception {
  final BackupCryptoErrorType type;
  final String message;

  BackupCryptoException(this.type, this.message);

  factory BackupCryptoException.invalidPasswordOrCorruptedData([
    String msg =
        'Backup decryption failed: Invalid password or corrupted ciphertext data.',
  ]) {
    return BackupCryptoException(
      BackupCryptoErrorType.invalidPasswordOrCorruptedData,
      msg,
    );
  }

  factory BackupCryptoException.invalidEnvelope([
    String msg = 'Backup envelope is invalid or formatted incorrectly.',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.invalidEnvelope, msg);
  }

  factory BackupCryptoException.unsupportedVersion([
    String msg = 'Unsupported backup envelope schema version.',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.unsupportedVersion, msg);
  }

  factory BackupCryptoException.unsupportedKdf([
    String msg = 'Unsupported Key Derivation Function (KDF).',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.unsupportedKdf, msg);
  }

  factory BackupCryptoException.unsupportedCipher([
    String msg = 'Unsupported symmetric cryptographic cipher.',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.unsupportedCipher, msg);
  }

  factory BackupCryptoException.emptyPassword([
    String msg = 'Backup password cannot be empty or whitespace.',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.emptyPassword, msg);
  }

  factory BackupCryptoException.unknown([
    String msg = 'An unknown cryptographic exception occurred.',
  ]) {
    return BackupCryptoException(BackupCryptoErrorType.unknown, msg);
  }

  @override
  String toString() => 'BackupCryptoException[${type.name}]: $message';
}

/// 异常错误分类枚举。
enum BackupCryptoErrorType {
  invalidPasswordOrCorruptedData,
  invalidEnvelope,
  unsupportedVersion,
  unsupportedKdf,
  unsupportedCipher,
  emptyPassword,
  unknown,
}

/// 内存级备份加解密核心服务。
abstract final class BackupCryptoService {
  BackupCryptoService._();

  /// 密码学强安全随机数生成器。
  static final Random _secureRandom = Random.secure();

  /// 生产环境默认 iterations 参数建议值。
  /// ⚠️ 此参数为抗 GPU 爆破的生产建议参数，但在实际投入生产前仍需在真机设备上执行充分的性能评估确认。
  static const int defaultIterations = 210000;

  /// 在内存中加密备份 payload [BackupPayloadV1] 并包装生成密文外壳 [BackupEnvelopeV1]。
  ///
  /// 可在测试时传入较低的 [iterations] (如 1000) 以免单元测试运行过慢。
  static Future<BackupEnvelopeV1> encryptPayload({
    required BackupPayloadV1 payload,
    required String backupPassword,
    int iterations = defaultIterations,
    int? nowMillisForTest,
  }) async {
    // 1. 密码非空校验
    if (backupPassword.trim().isEmpty) {
      throw BackupCryptoException.emptyPassword();
    }

    // 2. 准备规范化明文 payload 字节
    final normalizedPayload = payload.normalized();
    final jsonStr = jsonEncode(normalizedPayload.toJson());
    final plaintextBytes = utf8.encode(jsonStr);

    // 3. 随机生成 16 字节 Salt 与 12 字节 Nonce
    final saltBytes = _generateRandomBytes(16);
    final nonceBytes = _generateRandomBytes(12);

    // 4. 用 PBKDF2-HMAC-SHA256 派生 256 位 Key (32 字节)
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(backupPassword)),
      nonce: saltBytes,
    );

    // 5. 对数据进行 AES-256-GCM 对称加密
    final aesGcm = AesGcm.with256bits();
    final secretBox = await aesGcm.encrypt(
      plaintextBytes,
      secretKey: secretKey,
      nonce: nonceBytes,
    );

    // 6. 构造外壳 Envelope V1 并使用 base64Url 对二进制字段进行小写兼容的编码
    return BackupEnvelopeV1(
      createdAt: nowMillisForTest ?? DateTime.now().millisecondsSinceEpoch,
      kdf: BackupKdfInfo(
        name: 'pbkdf2-hmac-sha256',
        iterations: iterations,
        salt: base64Url.encode(saltBytes),
        keyLength: 32,
      ),
      cipher: BackupCipherInfo(
        name: 'aes-256-gcm',
        nonce: base64Url.encode(nonceBytes),
        tagLength: 16,
      ),
      ciphertext: base64Url.encode(secretBox.cipherText),
      mac: base64Url.encode(secretBox.mac.bytes),
    );
  }

  /// 在内存中使用备份密码解密外壳 [BackupEnvelopeV1]，成功则返回重组还原的逻辑明文 [BackupPayloadV1]。
  ///
  /// 若密码不正确，密文被损坏或 MAC 篡改验证失败，必须抛出脱敏异常。
  static Future<BackupPayloadV1> decryptPayload({
    required BackupEnvelopeV1 envelope,
    required String backupPassword,
  }) async {
    // 1. 基本安全魔数与算法验证
    if (envelope.magic != 'ANCH_BACKUP') {
      throw BackupCryptoException.invalidEnvelope(
        "Invalid magic file identifier",
      );
    }
    if (envelope.version != 1) {
      throw BackupCryptoException.unsupportedVersion(
        "Unsupported envelope version",
      );
    }
    if (envelope.kdf.name != 'pbkdf2-hmac-sha256') {
      throw BackupCryptoException.unsupportedKdf(
        "Unsupported Key Derivation function: ${envelope.kdf.name}",
      );
    }
    if (envelope.cipher.name != 'aes-256-gcm') {
      throw BackupCryptoException.unsupportedCipher(
        "Unsupported symmetric cipher: ${envelope.cipher.name}",
      );
    }

    // 2. 密码非空验证
    if (backupPassword.trim().isEmpty) {
      throw BackupCryptoException.emptyPassword();
    }

    // 3. 提取 base64Url 二进制流并捕获解码失败异常以防暴露底层类
    late final Uint8List saltBytes;
    late final Uint8List nonceBytes;
    late final Uint8List ciphertextBytes;
    late final Uint8List macBytes;

    try {
      saltBytes = base64Url.decode(envelope.kdf.salt);
      nonceBytes = base64Url.decode(envelope.cipher.nonce);
      ciphertextBytes = base64Url.decode(envelope.ciphertext);
      macBytes = base64Url.decode(envelope.mac);
    } catch (e) {
      throw BackupCryptoException.invalidEnvelope(
        "Invalid base64Url text content inside envelope",
      );
    }

    // 4. 重建 PBKDF2 派生 Key
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: envelope.kdf.iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(backupPassword)),
      nonce: saltBytes,
    );

    // 5. 组装 SecretBox 并执行解密与认证 MAC 校验
    final aesGcm = AesGcm.with256bits();
    final secretBox = SecretBox(
      ciphertextBytes,
      nonce: nonceBytes,
      mac: Mac(macBytes),
    );

    late final List<int> decryptedBytes;
    try {
      decryptedBytes = await aesGcm.decrypt(secretBox, secretKey: secretKey);
    } catch (e) {
      // ⚠️ 【安全边界】解密失败(通常是MAC校验错，对应密码错或密文被篡改)统一映射为脱敏异常，不得抛出底层异常或日志打印
      throw BackupCryptoException.invalidPasswordOrCorruptedData();
    }

    // 6. JSON反序列化还原 Payload
    try {
      final jsonStr = utf8.decode(decryptedBytes);
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) {
        throw BackupCryptoException.invalidPasswordOrCorruptedData(
          "Decrypted content structure is corrupted",
        );
      }
      return BackupPayloadV1.fromJson(decoded);
    } catch (e) {
      // 解析 JSON 或格式模型转换失败同样需被映射为解密失败/文件损坏异常
      throw BackupCryptoException.invalidPasswordOrCorruptedData();
    }
  }

  /// 生成密码学安全强随机数。
  static Uint8List _generateRandomBytes(int length) {
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = _secureRandom.nextInt(256);
    }
    return bytes;
  }
}
