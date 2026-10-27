import 'dart:ui' show Tristate;

import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/repository/models/save_member_input.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

void main() {
  const config = AnchSecurityRuntimeConfig(
    mode: AnchSecurityMode.dev,
    useEncryptedDatabase: false,
    enableSecureWindow: false,
    enablePrivacyShieldOverlay: false,
    enableAppLockGate: false,
    isFormalBlocked: false,
    enableAutoFillScaffold: false,
  );

  Future<void> saveIdentity(
    DependencyProvider di,
    String memberId, {
    required String name,
    required String gender,
    required String birthDate,
  }) async {
    await di.itemUseCaseService.saveDraft(
      ItemDraftInput(
        memberId: memberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: name),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '990000200101020024',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: gender),
          ItemFieldDraftInput(fieldKey: 'birth_date', valueText: birthDate),
        ],
      ),
    );
  }

  test('仅唯一活跃身份证可以提供基础资料字段', () async {
    final context = createTestRepositoryContext(config: config);
    final memberId = await context.memberRepository.saveMember(
      SaveMemberInput(memberType: 'person', name: '测试成员'),
    );
    await saveIdentity(
      context.di,
      memberId,
      name: '测试成员',
      gender: '女',
      birthDate: '2001-01-02',
    );

    final profile = await context.itemRepository.getSingleActiveIdentityProfile(
      memberId,
    );

    expect(profile, {
      'name': '测试成员',
      'gender': '女',
      'birth_date': '2001-01-02',
    });

    await saveIdentity(
      context.di,
      memberId,
      name: '测试成员',
      gender: '女',
      birthDate: '2001-01-02',
    );
    expect(
      await context.itemRepository.getSingleActiveIdentityProfile(memberId),
      isNull,
    );
  });

  testWidgets('带入身份证基础信息只填空白字段', (tester) async {
    final runtime = RuntimeProvider.create(config);
    final di = DependencyProvider.create(runtime: runtime, child: Container());
    addTearDown(di.db.close);
    final memberId = await di.memberRepo.saveMember(
      SaveMemberInput(memberType: 'person', name: '测试成员'),
    );
    await saveIdentity(
      di,
      memberId,
      name: '测试成员',
      gender: '女',
      birthDate: '2001-01-02',
    );

    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(home: ItemEntryFlowPage()),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    await openEntryFields(tester, find.text('护照'), owner: '测试成员');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('identity_profile_suggestion')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const Key('item_field_control_name_cn')),
      '手动姓名',
    );
    await tester.tap(
      find.byKey(const Key('identity_profile_suggestion_apply')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('item_field_control_name_cn')),
          )
          .controller
          ?.text,
      '手动姓名',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const Key('item_field_control_birth_date')),
          )
          .controller
          ?.text,
      '2001-01-02',
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('性别－女'))
          .getSemanticsData()
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
  });
}
