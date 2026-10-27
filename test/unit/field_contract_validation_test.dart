import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/database/database_opener.dart';
import 'package:anch/core/repository/item_repository.dart';
import 'package:anch/core/repository/member_repository.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/service/validation/field_validation_error.dart';

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
    service = ItemUseCaseService(itemRepo: itemRepo, memberRepo: memberRepo, runtime: RuntimeProvider.create(const AnchSecurityRuntimeConfig(mode: AnchSecurityMode.dev, useEncryptedDatabase: false, enableSecureWindow: false, enablePrivacyShieldOverlay: false, enableAppLockGate: false, isFormalBlocked: false)));
  });

  tearDown(() async {
    await db.close();
  });

  test('验证非 registry fieldKey 被拒绝', () async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'non_existent_key_xyz', valueText: 'some-value'), // 违背静态注册表契约
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    expect(result.errors, isNotEmpty);
    expect(
      result.errors.any((e) => e.errorCode == FieldValidationErrorCode.unknownFieldKey),
      isTrue,
    );
    expect(result.errors.first.errorMessage, contains('未在任何注册的静态字段契约中定义'));
  });

  test('验证 template mismatch (大类与子类型不匹配) 被拦截', () async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate', // debit_card 所属大类应该是 card
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
        ItemFieldDraftInput(fieldKey: 'card_number', valueText: '6225881234567890'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    expect(result.errors, isNotEmpty);
    expect(
      result.errors.any((e) => e.errorCode == FieldValidationErrorCode.categoryMismatch),
      isTrue,
    );
    expect(result.errors.first.errorMessage, contains('不匹配'));
  });

  test('验证 version mismatch (模板版本不存在或不对应) 被拦截', () async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      templateVersion: 999, // 不存在此版本的身份证模板
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    expect(result.errors, isNotEmpty);
    expect(
      result.errors.any((e) => e.errorCode == FieldValidationErrorCode.versionMismatch),
      isTrue,
    );
    expect(result.errors.first.errorMessage, contains('未找到版本为 [999] 的模板'));
  });

  test('验证 invalid field definition (不符合 schema 规定的值) 不允许写入', () async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'id_number', valueText: '110101199003072345'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990年3月7日'), // 违背 YYYY-MM-DD 的 date 格式 schema
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    expect(result.errors, isNotEmpty);
    expect(
      result.errors.any((e) => e.errorCode == FieldValidationErrorCode.invalidFormat),
      isTrue,
    );
    expect(result.errors.first.errorMessage, contains('格式不合规'));
  });
}
