import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/template/type_definition.dart';
import 'package:anch/core/template/template_registry.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/time/time_domain_source.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;

  setUp(() {
    runtime = RuntimeProvider.create(const AnchSecurityRuntimeConfig(
      mode: AnchSecurityMode.dev,
      useEncryptedDatabase: false,
      enableSecureWindow: false,
      enablePrivacyShieldOverlay: false,
      enableAppLockGate: false,
      isFormalBlocked: false,
    ));
    di = DependencyProvider.create(
      runtime: runtime,
      timeDomainSource: DeterministicTimeDomainSource(DateTime(2026, 6, 24)),
      child: const SizedBox.shrink(),
    );
    db = di.db;
    service = di.itemUseCaseService;
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget(Widget child) {
    return wrapTest(MaterialApp(home: child), runtime, (c) => di.copyWith(child: c));
  }

  group('行驶证 (vehicle_license) 历史兼容与新建下线测试', () {
    test('1. 行驶证模板仍然存在于 registry 中', () {
      final typeDef = TemplateRegistry.getTemplate('vehicle_license');
      expect(typeDef, isNotNull);
      expect(typeDef!.label, '行驶证');
      expect(typeDef.isAvailableForCreation, isFalse);
      expect(typeDef.usesCompactSummaryHeader, isTrue);
    });

    test('2. 新增普通模板默认 usesCompactSummaryHeader 为 false', () {
      const typeDef = TypeDefinition(
        typeKey: 'test_new_template',
        label: '测试模板',
        categoryKey: 'other',
        fields: [],
      );
      expect(typeDef.usesCompactSummaryHeader, isFalse);
      expect(typeDef.isAvailableForCreation, isTrue);
    });

    testWidgets('3. 新增选择类型入口不展示行驶证', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() async => await tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestWidget(const ItemEntryFlowPage()));
      await tester.pumpAndSettle();

      // 进入类型选择步骤

      // 证件资料类别展开，其中应当只包含允许新建的类型
      expect(find.text('身份证'), findsOneWidget);
      expect(find.text('行驶证'), findsNothing);
    });

    testWidgets('4. 历史行驶证数据详情页正常渲染不崩溃', (WidgetTester tester) async {
      final result = await service.saveDraft(ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'vehicle_license',
        fields: [
          ItemFieldDraftInput(fieldKey: 'plate_number', valueText: '粤B12345'),
          ItemFieldDraftInput(fieldKey: 'vin', valueText: 'LHGXXXXXXXXX12345'),
        ],
      ));
      expect(result.success, isTrue);

      await tester.pumpWidget(buildTestWidget(ItemDetailPage(itemId: result.itemId!)));
      await tester.pumpAndSettle();

      // 验证历史行驶证卡片与字段仍然可以显示
      expect(find.text('行驶证'), findsWidgets);
      expect(find.textContaining('车辆识别'), findsOneWidget);
    });
  });
}
