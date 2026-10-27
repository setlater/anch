@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_file_codec.dart';
import 'package:anch/core/backup/backup_envelope.dart';
import 'package:anch/core/backup/backup_file_policy.dart';

void main() {
  group('安册备份文件字节封装与解析 (BackupFileCodec) 单元测试', () {
    const testNowTime = 1718035200000; // 本地对应 2026-06-11 00:00:00 附近时刻
    
    // 构造测试用 Envelope 实例
    final sampleEnvelope = BackupEnvelopeV1(
      createdAt: 1718035200000,
      kdf: BackupKdfInfo(
        name: 'pbkdf2-hmac-sha256',
        iterations: 1000,
        salt: 'dGVzdC1zYWx0',
        keyLength: 32,
      ),
      cipher: BackupCipherInfo(
        name: 'aes-256-gcm',
        nonce: 'dGVzdC1ub25jZQ==',
        tagLength: 16,
      ),
      ciphertext: 'dGVzdC1jaXBoZXJ0ZXh0',
      mac: 'dGVzdC1tYWM=',
    );

    test('1. 验证正常 encode 转换生成 BackupFilePackage，且各字段及大小表示正常', () {
      final localDateTime = DateTime(2026, 6, 11, 15, 30, 20);
      final testMillis = localDateTime.millisecondsSinceEpoch;

      final package = BackupFileCodec.encodeEnvelope(
        envelope: sampleEnvelope,
        nowMillis: testMillis,
      );

      // 验证文件名符合 YYYYMMDD-HHMMSS.abk 本地时区表示
      expect(package.fileName, 'anch-20260611-153020.abk');
      expect(package.mimeType, BackupFilePolicy.defaultMimeType);
      expect(package.sizeBytes, package.bytes.length);
      expect(package.sizeBytes, greaterThan(0));
      expect(package.sizeLabel, isNotEmpty);
      expect(package.createdAt, testMillis);
    });

    test('2. 验证正常 decode 转换还原为 BackupEnvelopeV1，且与原数据字段完全一致', () {
      final package = BackupFileCodec.encodeEnvelope(
        envelope: sampleEnvelope,
        nowMillis: testNowTime,
      );

      final decodedEnvelope = BackupFileCodec.decodeEnvelopeBytes(package.bytes);

      // 校验结构完全一致
      expect(decodedEnvelope.magic, 'ANCH_BACKUP');
      expect(decodedEnvelope.version, 1);
      expect(decodedEnvelope.createdAt, sampleEnvelope.createdAt);
      expect(decodedEnvelope.kdf.name, sampleEnvelope.kdf.name);
      expect(decodedEnvelope.kdf.iterations, sampleEnvelope.kdf.iterations);
      expect(decodedEnvelope.kdf.salt, sampleEnvelope.kdf.salt);
      expect(decodedEnvelope.cipher.name, sampleEnvelope.cipher.name);
      expect(decodedEnvelope.cipher.nonce, sampleEnvelope.cipher.nonce);
      expect(decodedEnvelope.ciphertext, sampleEnvelope.ciphertext);
      expect(decodedEnvelope.mac, sampleEnvelope.mac);
    });

    test('3. 验证 emptyBytes 与 fileTooLarge 的边界情况硬顶拦截', () {
      // A. 空数据抛出 emptyBytes
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes([]),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.emptyBytes,
        )),
      );

      // B. 超过 50MB (50 * 1024 * 1024 + 1 字节) 抛出 fileTooLarge
      final hugeBytes = List<int>.filled(50 * 1024 * 1024 + 1, 0);
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes(hugeBytes),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.fileTooLarge,
        )),
      );
    });

    test('4. 验证非法 UTF-8、非法 JSON 与非 Map 格式的防御与抛出', () {
      // A. 非法 UTF-8 字节流抛出 invalidUtf8
      final badUtf8 = [0xFF, 0xFF, 0xFF];
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes(badUtf8),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.invalidUtf8,
        )),
      );

      // B. 非法 JSON 文本抛出 invalidJson
      final badJsonBytes = utf8.encode('{invalid-json-text}');
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes(badJsonBytes),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.invalidJson,
        )),
      );

      // C. 合法 JSON 但不是 Map (如 JSON 列表) 抛出 invalidJson
      final listJsonBytes = utf8.encode('[1, 2, 3]');
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes(listJsonBytes),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.invalidJson,
        )),
      );
    });

    test('5. 验证解析 Map 但格式及魔数错误的防范', () {
      // 缺 magic 魔数的 Map 抛出 invalidEnvelope
      final badEnvelopeMapBytes = utf8.encode('{"version": 1}');
      expect(
        () => BackupFileCodec.decodeEnvelopeBytes(badEnvelopeMapBytes),
        throwsA(isA<BackupFileCodecException>().having(
          (e) => e.type,
          'type',
          BackupFileCodecErrorType.invalidEnvelope,
        )),
      );
    });

    test('6. 敏感词安全校验：验证 BackupFilePackage 的 toString() 彻底脱敏', () {
      final package = BackupFileCodec.encodeEnvelope(
        envelope: sampleEnvelope,
        nowMillis: testNowTime,
      );

      final toStringResult = package.toString();

      // 验证 toString 中只打印元数据信息，绝不输出具体的二进制流或敏感密文
      expect(toStringResult, contains('BackupFilePackage'));
      expect(toStringResult, contains('fileName'));
      expect(toStringResult, contains('mimeType'));
      
      // ⚠️ 【安全边界】断言绝对不含以下内容
      expect(toStringResult, isNot(contains(sampleEnvelope.ciphertext)));
      expect(toStringResult, isNot(contains(sampleEnvelope.mac)));
      expect(toStringResult, isNot(contains('bytes')));
      expect(toStringResult, isNot(contains('['))); // 不输出数组
      expect(toStringResult, isNot(contains('{'))); // 不输出明文 JSON
    });

    test('7. 敏感排除词安全断言，确保包对象及异常 toString 不发生泄露', () {
      final package = BackupFileCodec.encodeEnvelope(
        envelope: sampleEnvelope,
        nowMillis: testNowTime,
      );
      final pkgStr = package.toString().toLowerCase();

      // A. 排除词列表校验 (不含长词)
      expect(pkgStr, isNot(contains('backuppassword')));
      expect(pkgStr, isNot(contains('backupkey')));
      expect(pkgStr, isNot(contains('databasekey')));
      expect(pkgStr, isNot(contains('securestorage')));
      expect(pkgStr, isNot(contains('keystore')));
      expect(pkgStr, isNot(contains('keychain')));

      // B. 验证异常脱敏消息中排除泄漏
      try {
        // 传入非法字节流解析
        BackupFileCodec.decodeEnvelopeBytes([1, 2, 3]);
        fail('Should have failed');
      } on BackupFileCodecException catch (e) {
        final exStr = e.toString().toLowerCase();
        expect(exStr, isNot(contains('secret-password')));
        expect(exStr, isNot(contains('test-plain-text')));
        expect(exStr, isNot(contains('{'))); // 确保不泄漏 JSON 碎片
      }
    });
  });
}
