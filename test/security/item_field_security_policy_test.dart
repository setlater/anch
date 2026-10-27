@Tags(['security'])
library;

import 'package:anch/core/widgets/anch_step_indicator.dart';
import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/security/field_render_policy.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/widgets/anch_sensitive_field_row.dart';
import 'package:anch/core/widgets/anch_info_field_row.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;
  String? copiedText;

  setUp(() {
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
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
    copiedText = null;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildDetailWidget(String itemId) {
    return wrapTest(
      MaterialApp(home: ItemDetailPage(itemId: itemId)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  Widget buildEntryWidget({String? existingItemId}) {
    return wrapTest(
      MaterialApp(home: ItemEntryFlowPage(existingItemId: existingItemId)),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  void setupMockClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = methodCall.arguments['text'] as String?;
          return null;
        }
        return null;
      },
    );
  }

  group('FieldPolicy Unit Tests', () {
    test('verify shouldRenderField rules', () {
      expect(
        FieldRenderPolicy.shouldRenderField(SensitiveLevel.forbidden),
        isFalse,
      );
      expect(FieldRenderPolicy.shouldRenderField(SensitiveLevel.high), isTrue);
      expect(
        FieldRenderPolicy.shouldRenderField(SensitiveLevel.medium),
        isTrue,
      );
      expect(FieldRenderPolicy.shouldRenderField(SensitiveLevel.low), isTrue);
      expect(FieldRenderPolicy.shouldRenderField(SensitiveLevel.none), isTrue);
    });

    test('verify shouldMaskField rules', () {
      expect(
        FieldRenderPolicy.shouldMaskField(SensitiveLevel.forbidden),
        isFalse,
      );
      expect(FieldRenderPolicy.shouldMaskField(SensitiveLevel.high), isTrue);
      expect(FieldRenderPolicy.shouldMaskField(SensitiveLevel.medium), isFalse);
      expect(FieldRenderPolicy.shouldMaskField(SensitiveLevel.low), isFalse);
      expect(FieldRenderPolicy.shouldMaskField(SensitiveLevel.none), isFalse);
    });
  });

  group('ItemDetailPage Field Sensitive Rendering & Copy Tests', () {
    testWidgets(
      '1. Verify high sensitivity fields show as ****** and low show normally',
      (WidgetTester tester) async {
        setupMockClipboard(tester);

        final draft = ItemDraftInput(
          memberId: systemFamilyMemberId,
          categoryKey: 'card',
          typeKey: 'debit_card',
          title: '测试安全收口储蓄卡',
          note: '测试备注文字',
          fields: [
            ItemFieldDraftInput(
              fieldKey: 'bank_name',
              valueText: '测试银行',
            ), // low
            ItemFieldDraftInput(
              fieldKey: 'card_number',
              valueText: '6225881234567890',
            ), // high
            ItemFieldDraftInput(
              fieldKey: 'account_name',
              valueText: '测试户名',
            ), // medium
          ],
        );

        final saveResult = await service.saveDraft(draft);
        expect(saveResult.success, isTrue);
        final itemId = saveResult.itemId!;

        await tester.pumpWidget(buildDetailWidget(itemId));
        await tester.pumpAndSettle();

        // Verify low sensitivity value is shown
        expect(find.text('测试银行'), findsAtLeastNWidgets(1));

        // Verify high sensitivity value is NOT shown in cleartext initially
        expect(find.text('6225881234567890'), findsNothing);

        // Sensitive fields are rendered directly in their group cards (masked by default)
        expect(find.text('高敏信息'), findsNothing);
        expect(find.text('••••  ••••  ••••  7890'), findsOneWidget);
        expect(find.text('6225881234567890'), findsNothing);

        // Reveal the high sensitive field
        final eyeIcon = findAnchIcon(AnchIcons.visibility);
        expect(eyeIcon, findsOneWidget);
        await tester.tap(eyeIcon);
        await tester.pumpAndSettle();

        // Now cleartext should be shown and mask is gone
        expect(find.text('6225  8812  3456  7890'), findsOneWidget);
        expect(find.text('••••  ••••  ••••  7890'), findsNothing);

        // 2. Note section (备注信息 / 备注卡片) must be rendered in UI
        expect(find.text('备注'), findsOneWidget);
        expect(find.text('测试备注文字'), findsOneWidget);
      },
    );

    testWidgets('2. 顶部敏感铭牌确认复制，下方字段行直接复制', (WidgetTester tester) async {
      setupMockClipboard(tester);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '测试复制储蓄卡',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'bank_name',
            valueText: '测试银行',
          ), // low, copyable = true
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ), // high, copyable = true
          ItemFieldDraftInput(
            fieldKey: 'account_name',
            valueText: '测试户名',
          ), // medium, copyable = true
        ],
      );

      final saveResult = await service.saveDraft(draft);
      final itemId = saveResult.itemId!;

      await tester.pumpWidget(buildDetailWidget(itemId));
      await tester.pumpAndSettle();

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // Sensitive fields rendered directly (no high-sensitivity card to expand)
      expect(find.text('高敏信息'), findsNothing);

      // Find copy icons.
      final copyIcons = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is AnchSensitiveFieldRow || w is AnchInfoFieldRow,
        ),
        matching: findAnchIcon(AnchIcons.copy),
      );
      expect(copyIcons, findsNWidgets(2));

      // Test Copy for bank_name (low): should copy directly, no dialog
      final lowCopyBtn = copyIcons.at(0);
      await tester.scrollUntilVisible(lowCopyBtn, 50.0, scrollable: scrollable);
      await tester.tap(lowCopyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(copiedText, equals('测试银行'));
      expect(find.text('已复制'), findsNothing);
      await tester.pumpAndSettle(); // Dismiss snackbar
      copiedText = null;

      // Test Copy for card_number (high, in primary card): should prompt confirmation via menu
      final highCopyBtn = find.byKey(const Key('debit_card_header_copy'));
      await tester.scrollUntilVisible(
        highCopyBtn,
        50.0,
        scrollable: scrollable,
      );
      await tester.tap(highCopyBtn);
      await tester.pumpAndSettle();

      // Tap '仅复制卡号' on the sheet
      expect(find.text('仅复制卡号'), findsOneWidget);
      await tester.tap(find.text('仅复制卡号'));
      await tester.pumpAndSettle();

      expect(find.text('确认复制敏感字段？'), findsOneWidget);
      await tester.tap(find.text('确认复制'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(copiedText, equals('6225881234567890'));
      expect(find.text('已复制'), findsNothing);
      await tester.pumpAndSettle();
      copiedText = null;

      // Test Copy for account_name (medium): lower field rows copy directly.
      final medCopyBtn = copyIcons.at(1);
      await tester.scrollUntilVisible(medCopyBtn, 50.0, scrollable: scrollable);
      await tester.tap(medCopyBtn);
      await tester.pumpAndSettle();

      expect(find.text('确认复制敏感字段？'), findsNothing);

      expect(copiedText, equals('测试户名'));
      expect(find.text('已复制'), findsNothing);
    });
  });

  group('ItemEntryFlowPage UI Note Restore Tests', () {
    testWidgets('Verify note input UI is restored in entry flow step 3', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildEntryWidget());
      await tester.pumpAndSettle();

      // Go to Step 1

      // Select ID Card template (which is the first category and element, avoiding scrolling issues)
      await openEntryFields(tester, find.text('身份证'));
      await tester.pumpAndSettle();

      // Fill required fields
      final idNumberFinder = find.byKey(
        const Key('item_field_control_id_number'),
      );
      expect(idNumberFinder, findsOneWidget);
      await tester.enterText(idNumberFinder, '110101199003072345');
      await tester.pumpAndSettle();

      final nameFinder = find.byKey(const Key('item_field_control_name'));
      expect(nameFinder, findsOneWidget);
      await tester.enterText(nameFinder, '张三');
      await tester.pumpAndSettle();

      // Go to Step 3
      await tester.tap(find.text('下一步'));
      await tester.pumpAndSettle();

      // Verify that Step 3 is reached (progress step 4, counter 4 / 4)
      expect(
        tester
            .widget<AnchStepIndicator>(find.byKey(const Key('step_indicator')))
            .currentStep,
        3,
      );

      // Verify note input textfield is rendered
      expect(find.text('备注'), findsOneWidget);
      expect(find.byKey(const Key('entry_note_field')), findsOneWidget);
    });
  });
}
