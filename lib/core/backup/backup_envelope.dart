import 'dart:convert';
import 'backup_crypto.dart';

/// 备份文件加密外壳模型 V1。
///
/// ⚠️ 【安全红线】
/// 1. 本类 [BackupEnvelopeV1] 严禁在任何序列化或导出结果中包含或保存用户的备份密码 `backupPassword`、
///    派生加密 key、物理数据库密钥 `databaseKey`、`secureStorage` 及任何 keystore/keychain 信息。
/// 2. ciphertext 和 mac 均使用 base64Url 编码存储，不直接以明文字符串保存任何敏感载荷。
class BackupEnvelopeV1 {
  /// 固定魔法值，用于前置校验格式。固定为 "ANCH_BACKUP"
  final String magic;

  /// 加密外壳版本，固定为 1
  final int version;

  /// 加密外壳生成时间戳（毫秒）
  final int createdAt;

  /// 被加密的逻辑 Payload 格式，如 "anch.backup.payload"
  final String payloadFormat;

  /// 被加密的逻辑 Payload 版本，当前为 1
  final int payloadVersion;

  /// KDF (密钥派生函数) 描述参数
  final BackupKdfInfo kdf;

  /// 对称加密器描述参数
  final BackupCipherInfo cipher;

  /// 加密后的密文，采用 base64Url 编码
  final String ciphertext;

  /// 认证 MAC 标签，采用 base64Url 编码 (统一使用 mac，不与 tag 混用)
  final String mac;

  BackupEnvelopeV1({
    this.magic = 'ANCH_BACKUP',
    this.version = 1,
    required this.createdAt,
    this.payloadFormat = 'anch.backup.payload',
    this.payloadVersion = 1,
    required this.kdf,
    required this.cipher,
    required this.ciphertext,
    required this.mac,
  });

  /// 从 Map 反序列化并进行严格的魔数、版本及 base64 格式校验。
  ///
  /// 如果校验失败，或者 Base64 解码失败，统一抛出 [BackupCryptoException.invalidEnvelope] 或 [BackupCryptoException.unsupportedVersion]。
  factory BackupEnvelopeV1.fromJson(Map<String, dynamic> json) {
    // 1. 基础字段解析与非空校验
    final magicVal = json['magic'];
    if (magicVal == null || magicVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'magic'",
      );
    }
    if (magicVal != 'ANCH_BACKUP') {
      throw BackupCryptoException.invalidEnvelope(
        "Invalid magic identifier: '$magicVal'",
      );
    }

    final versionVal = json['version'];
    if (versionVal == null || versionVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'version'",
      );
    }
    if (versionVal != 1) {
      throw BackupCryptoException.unsupportedVersion(
        "Unsupported envelope version: $versionVal",
      );
    }

    final createdAtVal = json['createdAt'];
    if (createdAtVal == null || createdAtVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'createdAt'",
      );
    }

    final payloadFormatVal = json['payloadFormat'];
    if (payloadFormatVal == null || payloadFormatVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'payloadFormat'",
      );
    }

    final payloadVersionVal = json['payloadVersion'];
    if (payloadVersionVal == null || payloadVersionVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'payloadVersion'",
      );
    }

    // 2. KDF/Cipher 结构解析
    final kdfMap = json['kdf'];
    if (kdfMap == null || kdfMap is! Map<String, dynamic>) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'kdf'",
      );
    }
    final kdfObj = BackupKdfInfo.fromJson(kdfMap);

    final cipherMap = json['cipher'];
    if (cipherMap == null || cipherMap is! Map<String, dynamic>) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'cipher'",
      );
    }
    final cipherObj = BackupCipherInfo.fromJson(cipherMap);

    // 3. 密文与MAC解析
    final ciphertextVal = json['ciphertext'];
    if (ciphertextVal == null || ciphertextVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'ciphertext'",
      );
    }

    final macVal = json['mac'];
    if (macVal == null || macVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid field: 'mac'",
      );
    }

    // 4. Base64Url 解码合法性校验 (解码失败直接转换为脱敏后的 invalidEnvelope，不暴露底层格式错误异常)
    try {
      base64Url.decode(kdfObj.salt);
      base64Url.decode(cipherObj.nonce);
      base64Url.decode(ciphertextVal);
      base64Url.decode(macVal);
    } catch (e) {
      throw BackupCryptoException.invalidEnvelope(
        "Envelope data contains invalid base64Url encoding",
      );
    }

    return BackupEnvelopeV1(
      magic: magicVal,
      version: versionVal,
      createdAt: createdAtVal,
      payloadFormat: payloadFormatVal,
      payloadVersion: payloadVersionVal,
      kdf: kdfObj,
      cipher: cipherObj,
      ciphertext: ciphertextVal,
      mac: macVal,
    );
  }

  /// 序列化为 Map。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'magic': magic,
      'version': version,
      'createdAt': createdAt,
      'payloadFormat': payloadFormat,
      'payloadVersion': payloadVersion,
      'kdf': kdf.toJson(),
      'cipher': cipher.toJson(),
      'ciphertext': ciphertext,
      'mac': mac,
    };
  }
}

/// 密钥派生函数描述信息模型。
class BackupKdfInfo {
  /// 派生算法名称，例如: "pbkdf2-hmac-sha256"
  final String name;

  /// KDF 迭代次数
  final int iterations;

  /// base64Url 编码的 Salt 字节
  final String salt;

  /// 派生的 key 目标字节长度，如 32
  final int keyLength;

  BackupKdfInfo({
    required this.name,
    required this.iterations,
    required this.salt,
    required this.keyLength,
  });

  factory BackupKdfInfo.fromJson(Map<String, dynamic> json) {
    final nameVal = json['name'];
    if (nameVal == null || nameVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid KDF field: 'name'",
      );
    }

    final iterationsVal = json['iterations'];
    if (iterationsVal == null || iterationsVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid KDF field: 'iterations'",
      );
    }

    final saltVal = json['salt'];
    if (saltVal == null || saltVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid KDF field: 'salt'",
      );
    }

    final keyLengthVal = json['keyLength'];
    if (keyLengthVal == null || keyLengthVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid KDF field: 'keyLength'",
      );
    }

    return BackupKdfInfo(
      name: nameVal,
      iterations: iterationsVal,
      salt: saltVal,
      keyLength: keyLengthVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'iterations': iterations,
      'salt': salt,
      'keyLength': keyLength,
    };
  }
}

/// 加密算法描述信息模型。
class BackupCipherInfo {
  /// 对称加密算法名称，例如: "aes-256-gcm"
  final String name;

  /// base64Url 编码的 nonce/IV 字节
  final String nonce;

  /// 认证标签 MAC 长度（字节数），如 16 (128位)
  final int tagLength;

  BackupCipherInfo({
    required this.name,
    required this.nonce,
    required this.tagLength,
  });

  factory BackupCipherInfo.fromJson(Map<String, dynamic> json) {
    final nameVal = json['name'];
    if (nameVal == null || nameVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid Cipher field: 'name'",
      );
    }

    final nonceVal = json['nonce'];
    if (nonceVal == null || nonceVal is! String) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid Cipher field: 'nonce'",
      );
    }

    final tagLengthVal = json['tagLength'];
    if (tagLengthVal == null || tagLengthVal is! int) {
      throw BackupCryptoException.invalidEnvelope(
        "Missing or invalid Cipher field: 'tagLength'",
      );
    }

    return BackupCipherInfo(
      name: nameVal,
      nonce: nonceVal,
      tagLength: tagLengthVal,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'nonce': nonce,
      'tagLength': tagLength,
    };
  }
}
