import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/backup/backup_payload.dart';

void main() {
  group('安册逻辑备份数据结构 V1 (BackupPayloadV1) 测试', () {
    // 构造测试用的基础假数据（安全提示：全量使用 TEST-* 假数据，防敏感泄露）
    BackupPayloadV1 createTestPayload() {
      return BackupPayloadV1(
        exportedAt: 1718035200000, // 2024-06-11 00:00:00 UTC
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
              id: 'member-uuid-2',
              name: 'TEST-MEMBER-B',
              relationKey: 'relation-key-b',
              isSystem: false,
              sortOrder: 2,
              createdAt: 1000,
              updatedAt: 2000,
              note: 'TEST-MEMBER-NOTE',
              isArchived: false,
            ),
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
              id: 'item-uuid-2',
              memberId: 'member-uuid-1',
              categoryKey: 'cat-a',
              typeKey: 'type-a',
              templateVersion: 1,
              title: 'TEST-ITEM-B',
              primaryText: 'TEST-PRIMARY-B',
              secondaryText: 'TEST-SECONDARY-B',
              summaryText: 'TEST-SUMMARY-B',
              searchText: 'TEST-SEARCH-B',
              note: 'TEST-ITEM-NOTE-B',
              createdAt: 3000,
              updatedAt: 4000,
              isFavorite: false,
              isPinned: false,
              sortOrder: 2,
              status: 'active',
            ),
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
              id: 'field-uuid-2',
              itemId: 'item-uuid-1',
              fieldKey: 'key-b',
              valueType: 'sensitive_text',
              valueText: 'TEST-ID-CARD', // ⚠️ 高敏测试数据，必须以 TEST-* 表示
              normalizedValue: 'TEST-NORMALIZED-B',
              fieldNote: 'TEST-FIELD-NOTE-B',
              sortOrder: 2,
              createdAt: 500,
              updatedAt: 600,
            ),
            BackupItemFieldV1(
              id: 'field-uuid-1',
              itemId: 'item-uuid-1',
              fieldKey: 'key-a',
              valueType: 'text',
              valueText: 'TEST-TEXT-VALUE',
              normalizedValue: 'TEST-NORMALIZED-A',
              fieldNote: 'TEST-FIELD-NOTE-A',
              sortOrder: 1,
              createdAt: 500,
              updatedAt: 600,
            ),
          ],
          appSettings: [
            BackupAppSettingV1(
              key: 'setting-b',
              value: 'value-b',
              valueType: 'string',
              updatedAt: 100,
            ),
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

    test('1. 验证 BackupPayloadV1 正常序列化与反序列化，且互转后结构及数据保持完全一致', () {
      final payload = createTestPayload();

      // 序列化
      final json = payload.toJson();
      expect(json['format'], 'anch.backup.payload');
      expect(json['version'], 1);
      expect(json['exportedAt'], 1718035200000);

      // 反序列化
      final parsed = BackupPayloadV1.fromJson(json);
      expect(parsed.format, payload.format);
      expect(parsed.version, payload.version);
      expect(parsed.exportedAt, payload.exportedAt);
      expect(parsed.appVersion, payload.appVersion);
      expect(parsed.schemaVersion, payload.schemaVersion);

      // 验证 source 字段
      expect(parsed.source.appId, payload.source.appId);
      expect(parsed.source.platform, payload.source.platform);
      expect(parsed.source.locale, payload.source.locale);
      expect(parsed.source.exportMode, payload.source.exportMode);
      expect(parsed.source.note, payload.source.note);

      // 验证 members
      expect(parsed.data.members.length, payload.data.members.length);
      expect(parsed.data.members[0].id, payload.data.members[0].id);
      expect(parsed.data.members[0].name, payload.data.members[0].name);
      expect(
        parsed.data.members[0].relationKey,
        payload.data.members[0].relationKey,
      );
      expect(parsed.data.members[0].isSystem, payload.data.members[0].isSystem);
      expect(
        parsed.data.members[0].isArchived,
        payload.data.members[0].isArchived,
      );

      // 验证 items
      expect(parsed.data.items.length, payload.data.items.length);
      expect(parsed.data.items[0].id, payload.data.items[0].id);
      expect(parsed.data.items[0].title, payload.data.items[0].title);
      expect(parsed.data.items[0].isFavorite, payload.data.items[0].isFavorite);
      expect(parsed.data.items[0].isPinned, payload.data.items[0].isPinned);

      // 验证 itemFields 与敏感数据明文保留
      expect(parsed.data.itemFields.length, payload.data.itemFields.length);
      expect(parsed.data.itemFields[0].valueText, 'TEST-ID-CARD');

      // 再次进行 toJson 对比一致性
      final json2 = parsed.toJson();
      expect(jsonEncode(json), jsonEncode(json2));
    });

    test('2. 验证不支持的备份版本号或格式在反序列化时抛出校验异常', () {
      final jsonWithWrongVersion = {
        'format': 'anch.backup.payload',
        'version': 2, // 不支持版本 2
        'exportedAt': 1718035200000,
        'appVersion': '1.0.0',
        'schemaVersion': 1,
        'source': {
          'appId': 'com.test',
          'platform': 'android',
          'exportMode': 'manual',
        },
        'data': {
          'members': [],
          'items': [],
          'itemFields': [],
          'appSettings': [],
        },
      };

      expect(
        () => BackupPayloadV1.fromJson(jsonWithWrongVersion),
        throwsA(
          isA<BackupSerializationException>().having(
            (e) => e.message,
            'message',
            contains('Unsupported backup version: 2'),
          ),
        ),
      );

      final jsonWithWrongFormat = {
        'format': 'unknown.payload.format', // 错误格式
        'version': 1,
        'exportedAt': 1718035200000,
        'appVersion': '1.0.0',
        'schemaVersion': 1,
        'source': {
          'appId': 'com.test',
          'platform': 'android',
          'exportMode': 'manual',
        },
        'data': {
          'members': [],
          'items': [],
          'itemFields': [],
          'appSettings': [],
        },
      };

      expect(
        () => BackupPayloadV1.fromJson(jsonWithWrongFormat),
        throwsA(
          isA<BackupSerializationException>().having(
            (e) => e.message,
            'message',
            contains("Unsupported format: 'unknown.payload.format'"),
          ),
        ),
      );
    });

    test('3. 验证必需字段缺失或类型异常时在反序列化中抛出异常', () {
      final jsonMissingData = {
        'format': 'anch.backup.payload',
        'version': 1,
        'exportedAt': 1718035200000,
        'appVersion': '1.0.0',
        'schemaVersion': 1,
        'source': {
          'appId': 'com.test',
          'platform': 'android',
          'exportMode': 'manual',
        },
        // 缺失 'data'
      };

      expect(
        () => BackupPayloadV1.fromJson(jsonMissingData),
        throwsA(
          isA<BackupSerializationException>().having(
            (e) => e.message,
            'message',
            contains("Missing required field: 'data'"),
          ),
        ),
      );

      final jsonWrongMembersType = {
        'format': 'anch.backup.payload',
        'version': 1,
        'exportedAt': 1718035200000,
        'appVersion': '1.0.0',
        'schemaVersion': 1,
        'source': {
          'appId': 'com.test',
          'platform': 'android',
          'exportMode': 'manual',
        },
        'data': {
          'members': 'not-a-list', // 类型异常，应该是 List
          'items': [],
          'itemFields': [],
          'appSettings': [],
        },
      };

      expect(
        () => BackupPayloadV1.fromJson(jsonWrongMembersType),
        throwsA(
          isA<BackupSerializationException>().having(
            (e) => e.message,
            'message',
            contains("data.members is missing or not a List"),
          ),
        ),
      );
    });

    test(
      '4. 验证 normalized() 规范化稳定排序规则正确性 (尤其是 items 需为 createdAt 升序 -> id 字母序)',
      () {
        // 构造未排序的 Payload 实例
        final unSortedPayload = BackupPayloadV1(
          exportedAt: 1718035200000,
          appVersion: '1.0.0',
          schemaVersion: 1,
          source: BackupSourceInfo(
            appId: 'com.test',
            platform: 'ios',
            exportMode: 'manual',
          ),
          data: BackupDataV1(
            members: [
              // 排序规则：sortOrder 升序 -> createdAt 升序 -> id 字母序
              BackupMemberV1(
                id: 'member-c',
                name: 'C',
                relationKey: 'relation',
                isSystem: false,
                sortOrder: 2,
                createdAt: 100,
                updatedAt: 100,
                isArchived: false,
              ),
              BackupMemberV1(
                id: 'member-a',
                name: 'A',
                relationKey: 'relation',
                isSystem: false,
                sortOrder: 1,
                createdAt: 100,
                updatedAt: 100,
                isArchived: false,
              ),
              BackupMemberV1(
                id: 'member-b',
                name: 'B',
                relationKey: 'relation',
                isSystem: false,
                sortOrder: 1,
                createdAt: 50, // 较早创建，故升序排列第一
                updatedAt: 100,
                isArchived: false,
              ),
            ],
            items: [
              // 排序规则：createdAt 升序 -> id 字母序
              BackupItemV1(
                id: 'item-c',
                memberId: 'm',
                categoryKey: 'c',
                typeKey: 't',
                templateVersion: 1,
                title: 'C',
                createdAt: 300,
                updatedAt: 500,
                isFavorite: false,
                isPinned: false,
                sortOrder: 1,
                status: 'active',
              ),
              BackupItemV1(
                id: 'item-a',
                memberId: 'm',
                categoryKey: 'c',
                typeKey: 't',
                templateVersion: 1,
                title: 'A',
                createdAt: 100, // 排序第一
                updatedAt: 500,
                isFavorite: false,
                isPinned: false,
                sortOrder: 1,
                status: 'active',
              ),
              BackupItemV1(
                id: 'item-b',
                memberId: 'm',
                categoryKey: 'c',
                typeKey: 't',
                templateVersion: 1,
                title: 'B',
                createdAt: 200, // 排序第二
                updatedAt: 500,
                isFavorite: false,
                isPinned: false,
                sortOrder: 1,
                status: 'active',
              ),
              BackupItemV1(
                id: 'item-d',
                memberId: 'm',
                categoryKey: 'c',
                typeKey: 't',
                templateVersion: 1,
                title: 'D',
                createdAt: 200, // 与 item-b 的 createdAt 一样，但 id 字母序靠后
                updatedAt: 500,
                isFavorite: false,
                isPinned: false,
                sortOrder: 1,
                status: 'active',
              ),
            ],
            itemFields: [
              // 排序规则：itemId 字母序 -> sortOrder 升序 -> fieldKey 字母序 -> id 字母序
              BackupItemFieldV1(
                id: 'field-z',
                itemId: 'item-a',
                fieldKey: 'key-y',
                valueType: 'text',
                sortOrder: 2,
                createdAt: 10,
                updatedAt: 10,
              ),
              BackupItemFieldV1(
                id: 'field-y',
                itemId: 'item-a',
                fieldKey: 'key-y',
                valueType: 'text',
                sortOrder: 1, // 权重高，排在第一
                createdAt: 10,
                updatedAt: 10,
              ),
              BackupItemFieldV1(
                id: 'field-x',
                itemId: 'item-b', // itemId 靠后
                fieldKey: 'key-y',
                valueType: 'text',
                sortOrder: 1,
                createdAt: 10,
                updatedAt: 10,
              ),
            ],
            appSettings: [
              // 排序规则：key 字母序
              BackupAppSettingV1(key: 'z', valueType: 's', updatedAt: 10),
              BackupAppSettingV1(key: 'a', valueType: 's', updatedAt: 10),
            ],
          ),
        );

        final normalized = unSortedPayload.normalized();

        // 校验 members 排序结果
        expect(
          normalized.data.members[0].id,
          'member-b',
        ); // sortOrder 1, createdAt 50
        expect(
          normalized.data.members[1].id,
          'member-a',
        ); // sortOrder 1, createdAt 100
        expect(normalized.data.members[2].id, 'member-c'); // sortOrder 2

        // 校验 items 排序结果 (升序: item-a(100) -> item-b(200) -> item-d(200, id字母序排在b后面) -> item-c(300))
        expect(normalized.data.items[0].id, 'item-a');
        expect(normalized.data.items[1].id, 'item-b');
        expect(normalized.data.items[2].id, 'item-d');
        expect(normalized.data.items[3].id, 'item-c');

        // 校验 itemFields 排序结果
        expect(
          normalized.data.itemFields[0].id,
          'field-y',
        ); // item-a, sortOrder 1
        expect(
          normalized.data.itemFields[1].id,
          'field-z',
        ); // item-a, sortOrder 2
        expect(normalized.data.itemFields[2].id, 'field-x'); // item-b

        // 校验 appSettings 排序结果
        expect(normalized.data.appSettings[0].key, 'a');
        expect(normalized.data.appSettings[1].key, 'z');
      },
    );

    test('5. 安全排除拦截测试，断言导出的 JSON 字符串中绝对不包含敏感密钥和安全存储库字眼', () {
      final payload = createTestPayload();
      final jsonString = jsonEncode(payload.toJson()).toLowerCase();

      // 严密断言：绝对不能含有物理数据库密钥、备份密码、本地 Keystore 等相关的敏感字眼
      expect(jsonString, isNot(contains('databasekey')));
      expect(jsonString, isNot(contains('backuppassword')));
      expect(jsonString, isNot(contains('securestorage')));
      expect(jsonString, isNot(contains('keystore')));
      expect(jsonString, isNot(contains('keychain')));
    });

    test('6. 假数据防泄露断言，确保测试数据均以 TEST-* 为规范，无任何真实个人高敏格式数据', () {
      final payload = createTestPayload();
      for (final field in payload.data.itemFields) {
        if (field.valueText != null) {
          // 必须以 TEST- 前缀开头
          expect(field.valueText, startsWith('TEST-'));
          // 绝对不能有符合国内身份证或银行卡卡号等格式特征的字段（以长度特征作简要断言以规避误报）
          expect(field.valueText!.length, isNot(18));
          expect(field.valueText!.length, isNot(19));
        }
      }
    });

    test('7. 旧备份缺少 itemEvents 时按空事件序列读取', () {
      final json = createTestPayload().toJson();
      final data = Map<String, dynamic>.from(json['data'] as Map);
      data.remove('itemEvents');
      json['data'] = data;

      final parsed = BackupPayloadV1.fromJson(json);
      expect(parsed.data.itemEvents, isEmpty);
    });
  });
}
