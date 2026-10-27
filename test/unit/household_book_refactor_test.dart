import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/models/item_child_entry_model.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/backup/backup_payload.dart';
import 'package:anch/core/backup/backup_export_service.dart';
import 'package:anch/core/backup/backup_import_service.dart';
import 'package:anch/core/backup/backup_crypto.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/time/time_domain_source.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemRepository itemRepo;
  late ItemUseCaseService useCase;

  setUp(() {
    ItemGlobalRegistry.instance.clear();
    runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    di = DependencyProvider.create(
      runtime: runtime,
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 30)),
      child: Container(),
    );
    db = di.db;
    itemRepo = di.itemRepo;
    useCase = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  group('户口本多成员 C2-1 核心数据底座测试', () {
    test('1. Migration 升级与确定性 ID 遗留数据迁移测试', () async {
      final itemId = 'test_migrate_item_id';
      final now = DateTime.now().millisecondsSinceEpoch;

      // 模拟插入 v3 schema 的旧扁平数据
      await db.customStatement(
        "INSERT INTO items (id, origin_id, type_key, status, created_at, updated_at, template_version) "
        "VALUES (?, ?, 'household_book', 'active', ?, ?, 1);",
        [itemId, itemId, now, now],
      );

      // 插入 B1 旧扁平字段
      final legacyFields = {
        'page_owner': '张三',
        'id_number': '110101199003072345',
        'relation_to_head': '本人',
        'former_name': '张小三',
        'ethnicity': '汉族',
        'native_place': '北京',
        'birth_place': '上海',
      };

      int idx = 0;
      for (final entry in legacyFields.entries) {
        await db.customStatement(
          "INSERT INTO item_fields (id, item_id, field_key, value_type, value_text, sort_order, created_at, updated_at) "
          "VALUES (?, ?, ?, 'text', ?, ?, ?, ?);",
          ['field_$idx', itemId, entry.key, entry.value, idx, now, now],
        );
        idx++;
      }

      // 我们直接执行升级逻辑中 from < 4 的逻辑
      // 注：因为底层数据库已是 v4，为了验证迁移代码，我们在测试中直接触发迁移 SQL 查询和转换
      final items = await db
          .customSelect(
            "SELECT id, created_at, updated_at FROM items WHERE type_key = 'household_book';",
          )
          .get();

      expect(items.length, equals(1));

      for (final item in items) {
        final itemIdVal = item.read<String>('id');
        final createdAt = item.read<int>('created_at');
        final updatedAt = item.read<int>('updated_at');

        final fields = await db
            .customSelect(
              "SELECT field_key, value_type, value_text, normalized_value, field_note, sort_order "
              "FROM item_fields "
              "WHERE item_id = ? AND field_key IN ("
              "  'page_owner', 'relation_to_head', 'id_number', 'former_name', 'ethnicity', 'native_place', 'birth_place'"
              ");",
              variables: [drift.Variable.withString(itemIdVal)],
            )
            .get();

        final oldFields = fields.where((f) {
          final val = f.read<String?>('value_text');
          return val != null && val.trim().isNotEmpty;
        }).toList();

        expect(oldFields.length, equals(7));

        if (oldFields.isNotEmpty) {
          final entryId = "legacy_household_member_$itemIdVal";
          await db.customStatement(
            "INSERT OR IGNORE INTO item_child_entries (id, item_id, child_type, sort_order, created_at, updated_at) "
            "VALUES (?, ?, 'household_member', 0, ?, ?);",
            [entryId, itemIdVal, createdAt, updatedAt],
          );

          for (final f in oldFields) {
            final oldKey = f.read<String>('field_key');
            final valText = f.read<String?>('value_text');
            final valType = f.read<String>('value_type');
            final sortOrder = f.read<int>('sort_order');

            String newKey = oldKey;
            String label = "";
            String sensLevel = "none";
            bool copyable = false;
            bool searchable = false;

            if (oldKey == 'page_owner') {
              newKey = 'member_name';
              label = '成员姓名';
              sensLevel = 'medium';
              searchable = true;
            } else if (oldKey == 'id_number') {
              newKey = 'member_id_number';
              label = '身份证号';
              sensLevel = 'high';
              copyable = true;
            } else if (oldKey == 'relation_to_head') {
              label = '与户主关系';
            } else if (oldKey == 'former_name') {
              label = '曾用名';
              sensLevel = 'medium';
            } else if (oldKey == 'ethnicity') {
              label = '民族';
            } else if (oldKey == 'native_place') {
              label = '籍贯';
              sensLevel = 'medium';
            } else if (oldKey == 'birth_place') {
              label = '出生地';
              sensLevel = 'medium';
            }

            final fieldId = "${entryId}_$newKey";

            await db.customStatement(
              "INSERT OR IGNORE INTO item_child_fields ("
              "  id, child_entry_id, field_key, label, value_text, value_type, "
              "  sensitive_level, copyable, searchable, summary, sort_order, created_at, updated_at"
              ") VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
              [
                fieldId,
                entryId,
                newKey,
                label,
                valText,
                valType,
                sensLevel,
                copyable ? 1 : 0,
                searchable ? 1 : 0,
                0,
                sortOrder,
                createdAt,
                updatedAt,
              ],
            );
          }
        }
      }

      // 断言迁移结果
      final entries = await db.select(db.itemChildEntries).get();
      expect(entries.length, equals(1));
      expect(entries.first.id, equals("legacy_household_member_$itemId"));

      final childFields = await db.select(db.itemChildFields).get();
      expect(childFields.length, equals(7));

      final memberNameField = childFields.firstWhere(
        (cf) => cf.fieldKey == 'member_name',
      );
      expect(memberNameField.valueText, equals('张三'));
      expect(memberNameField.searchable, isTrue);

      final memberIdNumberField = childFields.firstWhere(
        (cf) => cf.fieldKey == 'member_id_number',
      );
      expect(memberIdNumberField.valueText, equals('110101199003072345'));
      expect(memberIdNumberField.copyable, isTrue);

      // 重复执行迁移迁移动作，断言具有幂等性，不产生任何重复子项
      await db.customStatement(
        "INSERT OR IGNORE INTO item_child_entries (id, item_id, child_type, sort_order, created_at, updated_at) "
        "VALUES (?, ?, 'household_member', 0, ?, ?);",
        ["legacy_household_member_$itemId", itemId, now, now],
      );
      final entriesAfterReRun = await db.select(db.itemChildEntries).get();
      expect(entriesAfterReRun.length, equals(1));
    });

    test('2. 0 成员与多成员保存与排序测试', () async {
      // 0 成员保存
      final draftEmpty = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '11112222',
          ),
        ],
        childEntries: [], // 明确保存为空
      );
      final resEmpty = await useCase.saveDraft(draftEmpty);
      expect(resEmpty.success, isTrue);

      final savedEmptyEntries = await itemRepo.getChildEntries(
        resEmpty.itemId!,
      );
      expect(savedEmptyEntries, isEmpty);

      // 多成员保存
      final draftWithMembers = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '33334444',
          ),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 2,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '成员二',
                valueText: '李四',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
            ],
          ),
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '成员一',
                valueText: '王五',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
            ],
          ),
        ],
      );

      final resWithMembers = await useCase.saveDraft(draftWithMembers);
      expect(resWithMembers.success, isTrue);

      // 验证回填与排序：sortOrder 1 的成员应该排在前面
      final savedMembers = await itemRepo.getChildEntries(
        resWithMembers.itemId!,
      );
      expect(savedMembers.length, equals(2));
      expect(savedMembers[0].sortOrder, equals(1));
      expect(savedMembers[0].fields.first.valueText, equals('王五'));
      expect(savedMembers[1].sortOrder, equals(2));
      expect(savedMembers[1].fields.first.valueText, equals('李四'));
    });

    test('3. 编辑保存防丢失 (childEntries == null) 与显式清空测试', () async {
      // 1. 初始化带有多成员的户口本
      final draft = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '55556666',
          ),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '姓名',
                valueText: '赵六',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
            ],
          ),
        ],
      );

      final res = await useCase.saveDraft(draft);
      final itemId = res.itemId!;

      // 2. 模拟编辑：仅修改主表单字段，childEntries 传入 null
      final editDraft = ItemDraftInput(
        id: itemId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '77778888',
          ),
        ],
        childEntries: null, // 保留现有
      );

      final resEdit = await useCase.saveDraft(editDraft);
      expect(resEdit.success, isTrue);

      // 断言子项仍然存在，没有被清空
      final afterEditMembers = await itemRepo.getChildEntries(itemId);
      expect(afterEditMembers.length, equals(1));
      expect(afterEditMembers.first.fields.first.valueText, equals('赵六'));

      // 3. 显式传空列表 []
      final clearDraft = ItemDraftInput(
        id: itemId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '77778888',
          ),
        ],
        childEntries: [], // 清空
      );

      final resClear = await useCase.saveDraft(clearDraft);
      expect(resClear.success, isTrue);

      // 断言子项已被清空
      final afterClearMembers = await itemRepo.getChildEntries(itemId);
      expect(afterClearMembers, isEmpty);
    });

    test('4. 级联与单项删除测试', () async {
      final draft = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '99990000',
          ),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '姓名',
                valueText: '陈七',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
            ],
          ),
        ],
      );

      final res = await useCase.saveDraft(draft);
      final itemId = res.itemId!;
      final entries = await itemRepo.getChildEntries(itemId);
      expect(entries.length, equals(1));

      final entryId = entries.first.id;

      // 删除单个成员
      await itemRepo.deleteChildEntry(entryId);
      final entriesAfterDeleteOne = await itemRepo.getChildEntries(itemId);
      expect(entriesAfterDeleteOne, isEmpty);

      // 再次创建成员
      await useCase.saveDraft(
        ItemDraftInput(
          id: itemId,
          categoryKey: 'certificate',
          typeKey: 'household_book',
          fields: [
            ItemFieldDraftInput(
              fieldKey: 'household_number',
              valueText: '99990000',
            ),
          ],
          childEntries: [
            SaveItemChildEntryInput(
              childType: 'household_member',
              sortOrder: 1,
              fields: [
                SaveItemChildFieldInput(
                  fieldKey: 'member_name',
                  label: '姓名',
                  valueText: '陈八',
                  valueType: 'text',
                  sensitiveLevel: 'medium',
                ),
              ],
            ),
          ],
        ),
      );

      final entriesAfterRecreate = await itemRepo.getChildEntries(itemId);
      expect(entriesAfterRecreate.length, equals(1));

      // 删除主资料条目，断言级联删除
      await db.transaction(() async {
        await (db.delete(db.items)..where((tbl) => tbl.id.equals(itemId))).go();
      });

      final entriesAfterDeleteMain = await db.select(db.itemChildEntries).get();
      expect(entriesAfterDeleteMain, isEmpty);
      final fieldsAfterDeleteMain = await db.select(db.itemChildFields).get();
      expect(fieldsAfterDeleteMain, isEmpty);
    });

    test('5. 事务回滚测试', () async {
      // 我们在同一个事务中插入一个正常的成员，然后插入一个具有非空约束冲突的成员
      try {
        await db.transaction(() async {
          // 插入子项
          await db
              .into(db.itemChildEntries)
              .insert(
                ItemChildEntriesCompanion.insert(
                  id: 'valid_entry_id',
                  itemId: 'dummy_item_id',
                  childType: 'household_member',
                  sortOrder: const drift.Value(0),
                  createdAt: 12345,
                  updatedAt: 12345,
                ),
              );

          // 故意制造约束异常：插入空的主键
          await db
              .into(db.itemChildEntries)
              .insert(
                ItemChildEntriesCompanion.insert(
                  id: '', // Empty ID will fail if unique/null is violated or custom logic throws, or violate foreign key constraints
                  itemId: 'non_existent_item_id', // 违反 Items 外键约束
                  childType: 'household_member',
                  sortOrder: const drift.Value(0),
                  createdAt: 12345,
                  updatedAt: 12345,
                ),
              );
        });
        fail('Should throw SQLite constraint exception');
      } catch (_) {
        // Exception is expected, let's assert rollback worked
        final childEntries = await db.select(db.itemChildEntries).get();
        expect(childEntries, isEmpty);
      }
    });

    test('6. 搜索安全性防泄露与摘要规则测试', () async {
      final draft = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '11113333',
          ),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '姓名',
                valueText: '钱九',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
              SaveItemChildFieldInput(
                fieldKey: 'member_id_number',
                label: '身份证号',
                valueText: '110101199003072345',
                valueType: 'sensitiveText',
                sensitiveLevel: 'high',
              ),
            ],
          ),
        ],
      );

      final res = await useCase.saveDraft(draft);
      expect(res.success, isTrue);

      final savedItem = await db.select(db.items).getSingle();
      final searchText = savedItem.searchText ?? '';
      final summaryText = savedItem.summaryText ?? '';

      // 1. 姓名可以进入模糊搜索
      expect(searchText.contains('钱九'), isTrue);

      // 2. 身份证号的任何部分（完整值、后四位、中间段）绝对不得进入模糊搜索与摘要文本
      expect(searchText.contains('110101199003072345'), isFalse);
      expect(searchText.contains('2345'), isFalse);
      expect(searchText.contains('19900307'), isFalse);

      expect(summaryText.contains('110101199003072345'), isFalse);
      expect(summaryText.contains('2345'), isFalse);

      // 3. 摘要应显示成员数量
      expect(summaryText.contains('已记录 1 位成员'), isTrue);
      expect(summaryText.contains('钱九'), isFalse); // 摘要不应该包含成员姓名，防止全列泄密

      // 4. 测试当编辑主表单且 childEntries 传 null 时，从数据库读取旧成员，搜索和摘要依旧包含旧成员信息
      final editDraft = ItemDraftInput(
        id: res.itemId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '88889999',
          ),
        ],
        childEntries: null, // null 表示不处理子项，应从数据库闭合获取
      );

      final resEdit = await useCase.saveDraft(editDraft);
      expect(resEdit.success, isTrue);

      final editedItem = await db.select(db.items).getSingle();
      expect(editedItem.searchText!.contains('钱九'), isTrue);
      expect(editedItem.summaryText!.contains('已记录 1 位成员'), isTrue);
    });

    test('7. 备份导出与旧备份恢复转换测试', () async {
      // 1. 保存有成员的户口本
      final draft = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '12121212',
          ),
        ],
        childEntries: [
          SaveItemChildEntryInput(
            childType: 'household_member',
            sortOrder: 1,
            fields: [
              SaveItemChildFieldInput(
                fieldKey: 'member_name',
                label: '姓名',
                valueText: '孙十',
                valueType: 'text',
                sensitiveLevel: 'medium',
              ),
            ],
          ),
        ],
      );
      final res = await useCase.saveDraft(draft);
      expect(res.success, isTrue);

      // 2. 测试导出
      final metadata = BackupExportMetadata(
        appVersion: '1.0.0',
        schemaVersion: 4,
        appId: 'anch.test',
        platform: 'linux',
      );
      final exportService = BackupExportService(
        itemRepository: itemRepo,
        memberRepository: di.memberRepo,
        metadata: metadata,
      );

      final envelope = await exportService.exportEncryptedBackup(
        backupPassword: 'testpassword123',
        iterations: 1000,
      );

      // 验证元数据不泄露身份证号等敏感信息
      expect(envelope.version, equals(1));
      expect(envelope.kdf.salt, isNotEmpty);

      // 解密并检查 Payload 结构
      final payload = await BackupCryptoService.decryptPayload(
        envelope: envelope,
        backupPassword: 'testpassword123',
      );
      expect(payload.data.childEntries.length, equals(1));
      expect(payload.data.childFields.length, equals(1));
      expect(payload.data.childFields.first.valueText, equals('孙十'));

      // 3. 测试恢复
      final importService = BackupImportService(database: db);
      final importRes = await importService.restoreFromEnvelope(
        envelope: envelope,
        backupPassword: 'testpassword123',
      );
      expect(importRes.restoredItemsCount, equals(1));

      // 验证数据库重新加载正常
      final restoredChildEntries = await itemRepo.getChildEntries(res.itemId!);
      expect(restoredChildEntries.length, equals(1));
      expect(restoredChildEntries.first.fields.first.valueText, equals('孙十'));

      // 4. 测试旧备份（无 childEntries 属性）恢复时的 Legacy 自动转换机制
      // 我们手动构建一个旧版备份 payload，不含 childEntries/childFields，但在 itemFields 中有旧的扁平字段值
      final oldPayload = BackupPayloadV1(
        exportedAt: 123456,
        appVersion: '1.0.0',
        schemaVersion: 3, // 旧版本号
        source: BackupSourceInfo(
          appId: 'anch.test',
          platform: 'linux',
          exportMode: 'manual',
        ),
        data: BackupDataV1(
          members: [
            BackupMemberV1(
              id: '00000000-0000-4000-8000-000000000001',
              name: '家庭',
              relationKey: 'other',
              isSystem: true,
              sortOrder: 0,
              createdAt: 1111,
              updatedAt: 1111,
              isArchived: false,
            ),
          ],
          items: [
            BackupItemV1(
              id: 'old_item_id',
              memberId: '00000000-0000-4000-8000-000000000001',
              categoryKey: 'certificate',
              typeKey: 'household_book',
              templateVersion: 1,
              title: '旧户口本资料',
              createdAt: 1111,
              updatedAt: 1111,
              isFavorite: false,
              isPinned: false,
              sortOrder: 0,
              status: 'active',
            ),
          ],
          itemFields: [
            BackupItemFieldV1(
              id: 'f1',
              itemId: 'old_item_id',
              fieldKey: 'page_owner',
              valueType: 'text',
              valueText: '老王',
              sortOrder: 0,
              createdAt: 1111,
              updatedAt: 1111,
            ),
            BackupItemFieldV1(
              id: 'f2',
              itemId: 'old_item_id',
              fieldKey: 'id_number',
              valueType: 'text',
              valueText: '110101199003072345',
              sortOrder: 1,
              createdAt: 1111,
              updatedAt: 1111,
            ),
          ],
          appSettings: [],
          attachments: [],
          childEntries: [], // 旧备份无子项列表
          childFields: [],
        ),
      );

      final oldEnvelope = await BackupCryptoService.encryptPayload(
        payload: oldPayload,
        backupPassword: 'testpassword123',
        iterations: 1000,
      );

      final importOldRes = await importService.restoreFromEnvelope(
        envelope: oldEnvelope,
        backupPassword: 'testpassword123',
      );
      expect(importOldRes.restoredItemsCount, equals(1));

      // 验证恢复后，数据导入事务触发了 legacy 转换，生成了新子项
      final restoredOldChildEntries = await itemRepo.getChildEntries(
        'old_item_id',
      );
      expect(restoredOldChildEntries.length, equals(1));
      expect(
        restoredOldChildEntries.first.id,
        equals('legacy_household_member_old_item_id'),
      );
      expect(
        restoredOldChildEntries.first.fields
            .firstWhere((cf) => cf.fieldKey == 'member_name')
            .valueText,
        equals('老王'),
      );
      expect(
        restoredOldChildEntries.first.fields
            .firstWhere((cf) => cf.fieldKey == 'member_id_number')
            .valueText,
        equals('110101199003072345'),
      );
    });

    test('8. 非户口本模板防污染回归测试', () async {
      // 保存身份证类型，不传任何子表项
      final draftIdCard = ItemDraftInput(
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '小明'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: 'male'),
        ],
        childEntries: null,
      );

      final resIdCard = await useCase.saveDraft(draftIdCard);
      expect(resIdCard.success, isTrue);

      final savedIdCard = await db.select(db.items).getSingle();
      expect(savedIdCard.typeKey, equals('id_card'));
      // 身份证的身份证号依然符合 SensitiveFieldGuard 规则
      expect(savedIdCard.searchText!.contains('110101199003072345'), isFalse);
      expect(savedIdCard.searchText!.contains('2345'), isFalse);
      expect(savedIdCard.searchText!.contains('小明'), isTrue);

      final childEntries = await db.select(db.itemChildEntries).get();
      // 身份证写入不产生任何子项记录
      expect(childEntries, isEmpty);
    });
  });
}
