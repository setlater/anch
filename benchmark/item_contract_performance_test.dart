import 'package:anch/core/runtime/runtime_context.dart';
import '../test/support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/features/home/home_page.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import '../test/contracts/contract_extractor.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;

  setUp(() {
    runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
        enableAutoFillScaffold: true,
      ),
    );
    di = DependencyProvider.create(
      runtime: runtime,
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget page) {
    return wrapTest(
      MaterialApp(home: page),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('Contract 测试优化与性能压测', () {
    testWidgets('1. 空状态与列表状态的契约提取随树重构更新', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      final contract1 = ContractExtractor.fromListItem(tester);
      expect(contract1.hasEmptyState, isTrue);

      final contract2 = ContractExtractor.fromListItem(tester);
      expect(contract2.hasEmptyState, contract1.hasEmptyState);
      expect(contract2.emptyStateType, contract1.emptyStateType);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '测试性能储蓄卡',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final saveResult = await service.saveDraft(draft);
      expect(saveResult.success, isTrue);

      final homeState =
          tester.state<State<HomePage>>(find.byType(HomePage)) as dynamic;
      homeState.reloadItems();
      await tester.pumpAndSettle();

      final contract3 = ContractExtractor.fromListItem(tester);
      expect(contract3.hasEmptyState, isFalse);
      expect(contract3.title, '测试性能储蓄卡（7890）');
    });

    testWidgets('2. 资料量增长时首页仍只构建固定数量的预览卡片', (WidgetTester tester) async {
      // 写入 10 条数据
      for (int i = 0; i < 10; i++) {
        final saveRes = await service.saveDraft(
          ItemDraftInput(
            memberId: systemFamilyMemberId,
            categoryKey: 'card',
            typeKey: 'debit_card',
            title: '卡片 $i',
            fields: [
              ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
              ItemFieldDraftInput(
                fieldKey: 'card_number',
                valueText: '6225881234567890',
              ),
            ],
          ),
        );
        expect(saveRes.success, isTrue);
      }

      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      final c10 = ContractExtractor.fromListItem(tester);
      expect(c10.hasEmptyState, isFalse);
      final cardsAt10 = find.byType(AnchUnifiedDataCard).evaluate().length;
      expect(cardsAt10, lessThanOrEqualTo(5));

      // 写入 1000 条数据进行压测
      for (int i = 10; i < 1010; i++) {
        final saveRes = await service.saveDraft(
          ItemDraftInput(
            memberId: systemFamilyMemberId,
            categoryKey: 'card',
            typeKey: 'debit_card',
            title: '卡片 $i',
            fields: [
              ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
              ItemFieldDraftInput(
                fieldKey: 'card_number',
                valueText: '6225881234567890',
              ),
            ],
          ),
        );
        expect(saveRes.success, isTrue);
      }

      // 重启 HomePage
      await tester.pumpWidget(buildTestApp(const HomePage()));
      await tester.pumpAndSettle();

      final c1000 = ContractExtractor.fromListItem(tester);
      expect(c1000.hasEmptyState, isFalse);
      final cardsAt1000 = find.byType(AnchUnifiedDataCard).evaluate().length;
      expect(cardsAt1000, cardsAt10);
    });
  });
}
