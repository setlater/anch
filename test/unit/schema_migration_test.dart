import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/repository/models/save_item_input.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/models/execution_context.dart';
import 'package:anch/core/service/validation/field_validation_error.dart';
import 'package:anch/core/service/validation/field_contract_validator.dart';
import 'package:anch/core/service/validation/validation_observer.dart';
import 'package:anch/core/template/schema_compatibility_resolver.dart';
import 'package:anch/core/template/migration_service.dart';
import 'package:anch/core/template/migration_dto.dart';
import '../../tool/migration_orchestrator.dart';
import 'package:anch/core/template/field_value_type.dart';
import 'dart:io';
import 'package:anch/core/template/migration_state_store.dart';

class TestValidationObserver implements ValidationObserver {
  ValidationResult? lastResult;
  String? lastTypeKey;

  @override
  void onValidationResult(ValidationResult result, {required String typeKey}) {
    lastResult = result;
    lastTypeKey = typeKey;
  }
}

void main() {
  late AppDatabase db;
  late MemberRepository memberRepo;
  late ItemRepository itemRepo;
  late ItemUseCaseService service;

  setUp(() {
    final opener = NativeAppDatabaseOpener(inMemory: true);
    db = AppDatabase.fromOpener(opener);
    memberRepo = MemberRepository(db);
    itemRepo = ItemRepository(db);
    service = ItemUseCaseService(
      itemRepo: itemRepo,
      memberRepo: memberRepo,
      runtime: RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('Schema Versioning & Compatibility Resolver Tests', () {
    test('精确匹配存在的版本号', () {
      final typeDef = SchemaCompatibilityResolver.resolveCompatibleTemplate(
        'debit_card',
        1,
      );
      expect(typeDef, isNotNull);
      expect(typeDef!.version, equals(1));
    });

    test('精确匹配另一个存在的版本号', () {
      final typeDef = SchemaCompatibilityResolver.resolveCompatibleTemplate(
        'debit_card',
        2,
      );
      expect(typeDef, isNotNull);
      expect(typeDef!.version, equals(2));
    });

    test('请求版本号不存在时，fallback 到最新兼容版本', () {
      final typeDef = SchemaCompatibilityResolver.resolveCompatibleTemplate(
        'debit_card',
        null,
      );
      expect(typeDef, isNotNull);
      expect(typeDef!.version, equals(2)); // 未传版本时直接返回最新版本
    });

    test('完全不兼容版本返回 null', () {
      final typeDef = SchemaCompatibilityResolver.resolveCompatibleTemplate(
        'debit_card',
        999,
      );
      expect(typeDef, isNull);
    });
  });

  group('FieldContractValidator Version & Deprecation Behavior', () {
    test('匹配的版本不会触发任何错误/警告/迁移计划', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 2,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );

      final result = FieldContractValidator.validate(draft);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
      expect(result.warnings, isEmpty);
      expect(result.migrationRequired, isFalse);
    });

    test('低版本且存在迁移路径的数据会触发 migrationRequired 警告与 SchemaValidationError', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1, // 当前最新是 2，故触发迁移
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );

      final result = FieldContractValidator.validate(draft);
      expect(result.isValid, isTrue); // 不阻断，所以 isValid 为 true
      expect(
        result.warnings.any(
          (w) => w.errorCode == FieldValidationErrorCode.migrationRequired,
        ),
        isTrue,
      );
      expect(result.warnings.first, isA<SchemaValidationError>());
      expect(result.migrationRequired, isTrue);
    });

    test('弃用字段检测（仅标记为 warnings 且为 SchemaValidationError 且不阻断保存）', () {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 2,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(
            fieldKey: 'account_type',
            valueText: '个人借记卡',
          ), // 已经在 TemplateRegistry 中被标记为 v2 废弃
        ],
      );

      final result = FieldContractValidator.validate(draft);
      expect(result.isValid, isTrue); // 依然能通过 validation (非阻塞)
      expect(
        result.warnings.any(
          (w) => w.errorCode == FieldValidationErrorCode.deprecatedField,
        ),
        isTrue,
      );
      expect(result.warnings.first, isA<SchemaValidationError>());
      expect(result.warnings.first.fieldKey, equals('account_type'));
    });

    test('其他资料 v1 保持可编辑，不触发会丢失字段语义的自动迁移', () {
      final result = FieldContractValidator.validate(
        ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 1,
          fields: [
            ItemFieldDraftInput(fieldKey: 'title', valueText: '旧资料'),
            ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '家庭'),
          ],
        ),
      );

      expect(result.errors, isEmpty);
      expect(result.migrationRequired, isFalse);
    });
  });

  group('Migration Execution, Observability & Orchestration Tests', () {
    test('MigrationService 可以正确执行字段值的转换升级', () {
      final fields = [
        const MigrationFieldInput(
          fieldKey: 'bank_name',
          valueText: '  招商银行  ',
        ), // 会被 v1_to_v2 strategy 去除两端空格
        const MigrationFieldInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
      ];

      final migrated = MigrationService.migrateFields(fields);

      final bankField = migrated.firstWhere((f) => f.fieldKey == 'bank_name');
      expect(bankField.valueText, equals('招商银行')); // 成功去除了前后空格
    });

    test('ItemUseCaseService saveDraft 自动执行迁移落库，并在数据库中升级版本', () async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1, // 传入 v1
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '  招商银行  '),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );

      final saveResult = await service.saveDraft(draft);
      expect(saveResult.persisted, isTrue);
      expect(saveResult.itemId, isNotNull);

      // 从数据库中重新读取该资料，验证是否升级为 v2，且字段是否成功转换
      final savedItem = await itemRepo.getItemWithFields(saveResult.itemId!);
      expect(savedItem, isNotNull);
      expect(savedItem!.templateVersion, equals(2)); // 版本已升级到 2
      final bankField = savedItem.fields.firstWhere(
        (f) => f.fieldKey == 'bank_name',
      );
      expect(bankField.valueText, equals('招商银行')); // 转换也已生效
    });

    test('ValidationObserver 能够在 UseCase 调用时接收到校验警告事件', () async {
      final observer = TestValidationObserver();
      final context = ExecutionContext(observer: observer);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 2,
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(
            fieldKey: 'account_type',
            valueText: '个人借记卡',
          ), // 废弃警告
        ],
      );

      final saveResult = await service.saveDraft(draft, context: context);
      expect(saveResult.persisted, isTrue);

      expect(observer.lastResult, isNotNull);
      expect(observer.lastTypeKey, equals('debit_card'));
      expect(
        observer.lastResult!.warnings.any(
          (w) => w.errorCode == FieldValidationErrorCode.deprecatedField,
        ),
        isTrue,
      );
    });

    test('MigrationOrchestrator 能够正确进行批量不一致数据检测与数据库升版修复', () async {
      // 1. 手动绕过用例写库，在数据库里存储一条 v1 版本的旧格式资料
      final oldInput = SaveItemInput(
        id: 'legacy_batch_item_1',
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        templateVersion: 1, // 旧版 v1
        title: '旧版银行卡',
        fields: [
          SaveItemFieldInput(
            fieldKey: 'bank_name',
            valueType: FieldValueType.text,
            valueText: '  建设银行  ', // 首尾有空格，待升级清洗
            sortOrder: 0,
          ),
          SaveItemFieldInput(
            fieldKey: 'card_number',
            valueType: FieldValueType.bankCardNumber,
            valueText: '6222021234567890123',
            sortOrder: 1,
          ),
        ],
      );
      await itemRepo.saveItemWithFields(oldInput);

      // 2. 检查批量扫描是否成功识别出该行记录
      final inconsistent = await MigrationOrchestrator.scanInconsistentData(
        itemRepo,
      );
      expect(inconsistent.length, equals(1));
      expect(inconsistent.first.id, equals('legacy_batch_item_1'));
      expect(inconsistent.first.templateVersion, equals(1));

      // 3. 执行一站式批量自动修复
      final tempDir = Directory.systemTemp.createTempSync(
        'schema_migration_test_temp',
      );
      final stateStore = MigrationStateStore(baseDirectory: tempDir);
      try {
        await MigrationOrchestrator.migrateAll(
          itemRepo: itemRepo,
          memberRepo: memberRepo,
          stateStore: stateStore,
        );
      } finally {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }

      // 4. 从数据库验证，版本已被刷新至 v2 且银行名称已清除空格
      final repaired = await itemRepo.getItemWithFields('legacy_batch_item_1');
      expect(repaired, isNotNull);
      expect(repaired!.templateVersion, equals(2));
      final bankField = repaired.fields.firstWhere(
        (f) => f.fieldKey == 'bank_name',
      );
      expect(bankField.valueText, equals('建设银行'));
    });

    test('MigrationOrchestrator 不自动迁移其他资料 v1，保留历史字段语义', () async {
      await itemRepo.saveItemWithFields(
        SaveItemInput(
          id: 'legacy_generic_item_1',
          memberId: systemFamilyMemberId,
          categoryKey: 'other',
          typeKey: 'generic',
          templateVersion: 1,
          title: '旧版其他资料',
          fields: [
            SaveItemFieldInput(
              fieldKey: 'title',
              valueType: FieldValueType.text,
              valueText: '旧版其他资料',
              sortOrder: 0,
            ),
            SaveItemFieldInput(
              fieldKey: 'owner_name',
              valueType: FieldValueType.sensitiveText,
              valueText: '家庭',
              sortOrder: 1,
            ),
          ],
        ),
      );

      final inconsistent = await MigrationOrchestrator.scanInconsistentData(
        itemRepo,
      );
      expect(inconsistent, isEmpty);

      final legacy = await itemRepo.getItemWithFields('legacy_generic_item_1');
      expect(legacy!.templateVersion, 1);
      expect(
        legacy.fields.map((field) => field.fieldKey),
        contains('owner_name'),
      );
    });
  });
}
