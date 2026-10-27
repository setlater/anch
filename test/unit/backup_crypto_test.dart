@Tags(['security'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_envelope.dart';
import 'package:anch/core/backup/backup_crypto.dart';

void main() {
  group('安册备份密码学技术验证 (BackupCryptoService) 测试', () {
    // 构造测试用的基础假数据
    BackupPayloadV1 createTestPayload() {
      return BackupPayloadV1(
        exportedAt: 1718035200000,
        appVersion: '1.0.0-test',
        schemaVersion: 1,
        source: BackupSourceInfo(
          appId: 'com.example.anch.test',
          platform: 'android',
          locale: 'zh_CN',
          exportMode: 'manual',
          note: 'TEST-EXPORT-NOTE',
        ),
        data: BackupDataV1(
          members: [
            BackupMemberV1(
              id: 'member-uuid-1',
              name: 'TEST-MEMBER-A',
              relationKey: 'relation-key-a',
              isSystem: true,
              sortOrder: 1,
              createdAt: 1000,
              updatedAt: 2000,
              isArchived: false,
            ),
          ],
          items: [
            BackupItemV1(
              id: 'item-uuid-1',
              memberId: 'member-uuid-1',
              categoryKey: 'cat-a',
              typeKey: 'type-a',
              templateVersion: 1,
              title: 'TEST-ITEM-A',
              primaryText: 'TEST-PRIMARY-A',
              secondaryText: 'TEST-SECONDARY-A',
              summaryText: 'TEST-SUMMARY-A',
              searchText: 'TEST-SEARCH-A',
              note: 'TEST-ITEM-NOTE-A',
              createdAt: 2000,
              updatedAt: 5000,
              isFavorite: true,
              isPinned: true,
              sortOrder: 1,
              status: 'active',
            ),
          ],
          itemFields: [
            BackupItemFieldV1(
              id: 'field-uuid-1',
              itemId: 'item-uuid-1',
              fieldKey: 'key-a',
              valueType: 'sensitive_text',
              valueText: 'TEST-ID-CARD', // ⚠️ 高敏测试数据强制以 TEST-* 为前缀规范，严禁真实数据
              normalizedValue: 'TEST-NORMALIZED-A',
              fieldNote: 'TEST-FIELD-NOTE-A',
              sortOrder: 1,
              createdAt: 500,
              updatedAt: 600,
            ),
          ],
          appSettings: [
            BackupAppSettingV1(
              key: 'setting-a',
              value: 'value-a',
              valueType: 'string',
              updatedAt: 100,
            ),
          ],
        ),
      );
    }

    final testPassword = 'my-test-password-123';
    // 测试时传入较小的 iterations 1000 以避免单元测试执行过慢
    const testIterations = 1000;

    test('1. 验证正确密码下 encrypt -> decrypt 内存加解密链路闭环且数据结构完全一致', () async {
      final payload = createTestPayload();

      // 执行加密
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
        nowMillisForTest: 1718035200000,
      );

      expect(envelope.magic, 'ANCH_BACKUP');
      expect(envelope.version, 1);
      expect(envelope.kdf.iterations, testIterations);

      // 执行解密
      final decryptedPayload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: testPassword,
      );

      // 验证解密后的数据内容一致性
      expect(decryptedPayload.format, payload.format);
      expect(decryptedPayload.version, payload.version);
      expect(decryptedPayload.data.members[0].name, 'TEST-MEMBER-A');
      expect(decryptedPayload.data.items[0].title, 'TEST-ITEM-A');
      expect(decryptedPayload.data.itemFields[0].valueText, 'TEST-ID-CARD');
    });

    test('2. 验证输入错误密码解密失败并抛出脱敏异常 invalidPasswordOrCorruptedData', () async {
      final payload = createTestPayload();

      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // 传入错误密码
      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: 'wrong-password-abc',
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidPasswordOrCorruptedData,
        )),
      );
    });

    test('3. 验证密文、MAC、Nonce、Salt 被外部篡改时解密均被拦截并抛出脱敏异常', () async {
      final payload = createTestPayload();
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // A. 篡改 ciphertext 密文内容的一个字符
      final tamperedCiphertext = envelope.ciphertext.replaceRange(0, 1, 'x' == envelope.ciphertext[0] ? 'y' : 'x');
      final envelopeWithTamperedCipher = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: envelope.kdf,
        cipher: envelope.cipher,
        ciphertext: tamperedCiphertext,
        mac: envelope.mac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelopeWithTamperedCipher,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidPasswordOrCorruptedData,
        )),
      );

      // B. 篡改 mac (AEAD tag)
      final tamperedMac = envelope.mac.replaceRange(0, 1, 'a' == envelope.mac[0] ? 'b' : 'a');
      final envelopeWithTamperedMac = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: envelope.kdf,
        cipher: envelope.cipher,
        ciphertext: envelope.ciphertext,
        mac: tamperedMac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelopeWithTamperedMac,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidPasswordOrCorruptedData,
        )),
      );

      // C. 篡改 nonce (IV)
      final tamperedNonce = envelope.cipher.nonce.replaceRange(0, 1, 'm' == envelope.cipher.nonce[0] ? 'n' : 'm');
      final envelopeWithTamperedNonce = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: envelope.kdf,
        cipher: BackupCipherInfo(
          name: envelope.cipher.name,
          nonce: tamperedNonce,
          tagLength: envelope.cipher.tagLength,
        ),
        ciphertext: envelope.ciphertext,
        mac: envelope.mac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelopeWithTamperedNonce,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidPasswordOrCorruptedData,
        )),
      );

      // D. 篡改 salt
      final tamperedSalt = envelope.kdf.salt.replaceRange(0, 1, 'x' == envelope.kdf.salt[0] ? 'y' : 'x');
      final envelopeWithTamperedSalt = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: BackupKdfInfo(
          name: envelope.kdf.name,
          iterations: envelope.kdf.iterations,
          salt: tamperedSalt,
          keyLength: envelope.kdf.keyLength,
        ),
        cipher: envelope.cipher,
        ciphertext: envelope.ciphertext,
        mac: envelope.mac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelopeWithTamperedSalt,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidPasswordOrCorruptedData,
        )),
      );
    });

    test('4. 验证 Envelope 格式错误 (magic/version/kdf/cipher不匹配) 解密及反序列化被严格拦截', () async {
      final payload = createTestPayload();
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // A. magic 错误
      final wrongMagicJson = envelope.toJson()..['magic'] = 'WRONG_MAGIC';
      expect(
        () => BackupEnvelopeV1.fromJson(wrongMagicJson),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.invalidEnvelope,
        )),
      );

      // B. version 错误
      final wrongVersionJson = envelope.toJson()..['version'] = 2;
      expect(
        () => BackupEnvelopeV1.fromJson(wrongVersionJson),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.unsupportedVersion,
        )),
      );

      // C. kdf 算法名称不支持
      final wrongKdfEnvelope = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: BackupKdfInfo(
          name: 'scrypt', // 不支持的算法
          iterations: envelope.kdf.iterations,
          salt: envelope.kdf.salt,
          keyLength: envelope.kdf.keyLength,
        ),
        cipher: envelope.cipher,
        ciphertext: envelope.ciphertext,
        mac: envelope.mac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: wrongKdfEnvelope,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.unsupportedKdf,
        )),
      );

      // D. cipher 算法名称不支持
      final wrongCipherEnvelope = BackupEnvelopeV1(
        createdAt: envelope.createdAt,
        kdf: envelope.kdf,
        cipher: BackupCipherInfo(
          name: 'chacha20-poly1305', // 不支持
          nonce: envelope.cipher.nonce,
          tagLength: envelope.cipher.tagLength,
        ),
        ciphertext: envelope.ciphertext,
        mac: envelope.mac,
      );

      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: wrongCipherEnvelope,
          backupPassword: testPassword,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.unsupportedCipher,
        )),
      );
    });

    test('5. 验证输入密码为空或全空格在加解密时抛出 emptyPassword 错误', () async {
      final payload = createTestPayload();
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // A. 加密密码为空
      expect(
        () => BackupCryptoService.encryptPayload(
          payload: payload,
          backupPassword: '  ',
          iterations: testIterations,
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.emptyPassword,
        )),
      );

      // B. 解密密码为空
      expect(
        () => BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: '',
        ),
        throwsA(isA<BackupCryptoException>().having(
          (e) => e.type,
          'type',
          BackupCryptoErrorType.emptyPassword,
        )),
      );
    });

    test('6. 敏感防泄露与异常文案脱敏审查断言 (全量扫描 JSON 串与异常字符串)', () async {
      final payload = createTestPayload();
      final envelope = await BackupCryptoService.encryptPayload(
        payload: payload,
        backupPassword: testPassword,
        iterations: testIterations,
      );

      // A. 序列化 JSON 全量字符串扫描断言
      final jsonString = jsonEncode(envelope.toJson()).toLowerCase();

      // 安全要求：绝对不能包含明文密码、派生key、本地数据库密钥及安全存储区关键字
      expect(jsonString, isNot(contains('backuppassword')));
      expect(jsonString, isNot(contains('backupkey')));
      expect(jsonString, isNot(contains('databasekey')));
      expect(jsonString, isNot(contains('securestorage')));
      expect(jsonString, isNot(contains('keystore')));
      expect(jsonString, isNot(contains('keychain')));
      // 泛词 key 允许存在（例如 keyLength, fieldKey），但排除了特定的敏感全称

      // B. 异常 message 脱敏匹配断言
      try {
        await BackupCryptoService.decryptPayload(
          envelope: envelope,
          backupPassword: 'wrong-password-abc-XYZ',
        );
        fail('Should throw BackupCryptoException');
      } catch (e) {
        expect(e, isA<BackupCryptoException>());
        final errString = e.toString();

        // 断言：异常信息里绝不能包含我们的测试明文密码、派生的key、TEST-* 明文高敏测试数据、完整密文或完整payload
        expect(errString, isNot(contains('my-test-password-123')));
        expect(errString, isNot(contains('wrong-password-abc-XYZ')));
        expect(errString, isNot(contains('TEST-ID-CARD')));
        expect(errString, isNot(contains(envelope.ciphertext)));
        // 确保没有泄漏底层堆栈与敏感信息
      }
    });

    test('7. 假数据规则约束，绝不出现任何真实格式的银行卡/手机号/身份证数据，高敏必须使用 TEST-* 前缀', () {
      final payload = createTestPayload();
      for (final field in payload.data.itemFields) {
        if (field.valueText != null) {
          expect(field.valueText, startsWith('TEST-'));
          expect(field.valueText!.length, isNot(18));
          expect(field.valueText!.length, isNot(19));
          expect(field.valueText!.length, isNot(11));
        }
      }
    });
  });
}
