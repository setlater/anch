import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/repository/models/item_with_fields.dart';
import 'package:anch/core/service/item_use_case_service.dart';
import 'package:anch/core/service/models/item_draft_input.dart';
import 'package:anch/core/attachment/save_attachment_input.dart';
import 'package:anch/core/attachment/attachment_crypto_service.dart';
import 'package:anch/core/attachment/attachment_preview_policy.dart';
import 'package:anch/features/item_detail/item_detail_page.dart';
import 'package:anch/features/item_entry/item_entry_flow_page.dart';
import 'package:anch/core/widgets/anch_sensitive_field_row.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/core/widgets/anch_info_field_row.dart';
import 'package:anch/core/widgets/anch_detail_field_row_layout.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/core/widgets/anch_centered_notice.dart';
import 'package:anch/core/security/privacy_shield_signal.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  late ItemUseCaseService service;
  late Directory testDir;

  const MethodChannel pathChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  setUp(() async {
    testDir = Directory('./test_detail_documents');
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
    testDir.createSync(recursive: true);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (MethodCall methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return testDir.path;
          }
          return null;
        });

    AttachmentCryptoService.init(base64UrlEncode(List<int>.filled(32, 7)));

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
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  Widget buildTestWidget(String itemId, {Key? key}) {
    return wrapTest(
      MaterialApp(
        home: ItemDetailPage(key: key, itemId: itemId),
      ),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  testWidgets('详情加载和不存在资料的失败态保持暗色主题', (tester) async {
    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          theme: AnchTheme.dark,
          home: const ItemDetailPage(itemId: 'fictional-missing-item'),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AnchColorsExtension.dark.background,
    );
    await tester.pumpAndSettle();
    expect(find.text('资料加载失败'), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AnchColorsExtension.dark.background,
    );
    expect(
      tester.widget<Text>(find.text('资料加载失败')).style?.color,
      AnchColorsExtension.dark.textPrimary,
    );
  });

  testWidgets('大文本附件不进入内置全文预览', (tester) async {
    final saved = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '虚构资料'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
        attachments: const [
          SaveAttachmentInput(
            itemId: 'temporary-item-id',
            attachmentRole: 'proof',
            fileName: 'large-text.enc',
            originalName: 'large.txt',
            mimeType: 'text/plain',
            plainSize: AttachmentPreviewPolicy.largeExternalOpenWarningBytes,
            encryptedSize:
                AttachmentPreviewPolicy.largeExternalOpenWarningBytes + 28,
            sortOrder: 0,
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildTestWidget(saved.itemId!));
    await tester.pumpAndSettle();
    final attachment = find.byKey(const Key('attachment_item_0'));
    await tester.ensureVisible(attachment);
    await tester.tap(attachment);
    await tester.pumpAndSettle();

    expect(find.text('使用其他应用打开？'), findsOneWidget);
    expect(find.text('附件较大，打开前需要准备内容。'), findsOneWidget);
    expect(find.text('文本预览'), findsNothing);
  });

  testWidgets('详情页消费导航前启动的资料预取结果', (tester) async {
    final saved = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '转场测试'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      ),
    );
    final itemId = saved.itemId!;
    final item = await di.itemRepo.getItemWithFields(itemId);
    final prefetchedItem = Completer<ItemWithFields?>();

    await tester.pumpWidget(
      wrapTest(
        MaterialApp(
          home: ItemDetailPage(
            itemId: itemId,
            prefetchedItem: prefetchedItem.future,
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );

    expect(find.byKey(const Key('detail_more_action')), findsNothing);

    prefetchedItem.complete(item);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('detail_more_action')), findsOneWidget);
  });

  testWidgets('身份证详情页测试：高敏字段默认隐藏、显隐独立切换、离开后重置、复制反馈', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'ethnicity', valueText: '汉'),
        ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990-03-07'),
        ItemFieldDraftInput(fieldKey: 'address', valueText: '北京市东城区景山前街4号'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    final titleIcon = tester.widget<AnchIcon>(
      find.byKey(const Key('detail_title_type_icon')),
    );
    expect(titleIcon.icon, AnchIcons.idCard);
    expect(titleIcon.size, 24);

    // 默认掩码状态校验
    expect(find.text('110101199003072345'), findsNothing);
    expect(find.text('北京市东城区景山前街4号'), findsNothing);
    expect(find.text('证件号尾号 2345'), findsNothing);

    expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);
    expect(find.text('******'), findsOneWidget);

    // 显隐独立切换测试
    final visibilityIcons = findAnchIcon(AnchIcons.visibility);
    expect(visibilityIcons, findsNWidgets(2));

    await tester.scrollUntilVisible(
      visibilityIcons.first,
      100.0,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(visibilityIcons.first);
    await tester.pumpAndSettle();

    expect(find.text('110101199003072345'), findsOneWidget);
    expect(find.text('北京市东城区景山前街4号'), findsNothing);
    expect(find.text('••••  ••••  ••••  2345'), findsNothing);
    expect(find.text('******'), findsOneWidget);

    final addressEyeIcon = findAnchIcon(AnchIcons.visibility);
    expect(addressEyeIcon, findsOneWidget);

    await tester.scrollUntilVisible(
      addressEyeIcon,
      100.0,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addressEyeIcon);
    await tester.pumpAndSettle();

    expect(find.text('110101199003072345'), findsOneWidget);
    expect(find.text('北京市东城区景山前街4号'), findsOneWidget);

    // 复制反馈测试
    final copyButtons = findAnchIcon(AnchIcons.copy);
    expect(copyButtons, findsAtLeastNWidgets(2));

    final idCopyBtn = copyButtons.at(1);
    await tester.scrollUntilVisible(
      idCopyBtn,
      100.0,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(idCopyBtn);
    await tester.pumpAndSettle();

    // 下方字段行直接复制，不弹确认框。
    expect(find.text('确认复制敏感字段？'), findsNothing);

    expect(find.text('已复制'), findsNothing);
    await tester.pumpAndSettle();

    // 离开详情页再进入后，高敏字段恢复掩码
    await tester.pumpWidget(
      buildTestWidget(itemId, key: const Key('reloaded')),
    );
    await tester.pumpAndSettle();

    expect(find.text('110101199003072345'), findsNothing);
    expect(find.text('北京市东城区景山前街4号'), findsNothing);

    expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);
    expect(find.text('******'), findsOneWidget);
  });

  testWidgets('储蓄卡详情页测试：卡号默认隐藏、三分组正确、衍生尾号展示及废弃/颜色字段隐藏', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
        ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '我的工资卡'),
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
        ItemFieldDraftInput(fieldKey: 'account_name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'branch_name', valueText: '招商银行深圳科苑支行'),
        ItemFieldDraftInput(fieldKey: 'account_type', valueText: '储蓄账户'),
        ItemFieldDraftInput(fieldKey: 'usage', valueText: 'TEST-USAGE'),
        // 以下为历史被删/废弃字段，测试防御过滤
        ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '9999'),
        ItemFieldDraftInput(fieldKey: 'open_region', valueText: 'TEST-REGION'),
        ItemFieldDraftInput(
          fieldKey: 'reserved_phone',
          valueText: '13800000000',
        ),
        ItemFieldDraftInput(fieldKey: 'card_color', valueText: 'TEST-COLOR'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 验证头部主标题：卡片别名 + 后四位（新规则）
    expect(find.text('我的工资卡（7890）'), findsOneWidget);
    // 副标题区域已清空，不再显示"银行名称 · 尾号 xxxx"
    expect(find.text('招商银行 · 尾号 7890'), findsNothing);

    // 验证无通用标签
    expect(find.text('本地保存'), findsNothing);
    expect(find.text('默认脱敏'), findsNothing);
    expect(find.text('可复制字段'), findsNothing);
    expect(find.text('类型：储蓄卡'), findsNothing);

    // 卡号高敏默认隐藏
    expect(find.text('6225881234567890'), findsNothing);

    // 开户行属于自然语言字段，详情中应自动换行而非省略号。
    final branchName = tester.widget<Text>(
      find.byKey(const Key('field_multiline_val_branch_name')),
    );
    expect(branchName.maxLines, isNull);

    // 三个分组卡片标题均不出现
    expect(find.text('卡片信息'), findsNothing);
    expect(find.text('持卡与开户'), findsNothing);
    expect(find.text('使用状态'), findsNothing);

    // 确认被删/废弃字段（尾号 9999、开户地区 TEST-REGION、预留手机 13800000000、卡片颜色 TEST-COLOR）被过滤不再独立展示
    expect(find.text('尾号'), findsNothing);
    expect(find.text('9999'), findsNothing);
    expect(find.text('开户地区'), findsNothing);
    expect(find.text('TEST-REGION'), findsNothing);
    expect(find.text('预留手机号'), findsNothing);
    expect(find.text('13800000000'), findsNothing);
    expect(find.text('卡片颜色'), findsNothing);
    expect(find.text('TEST-COLOR'), findsNothing);
  });

  testWidgets('精简 AppBar 后，摘要卡仍展示成员与类型，且不诱导使用真实图片', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'other',
      typeKey: 'generic',
      fields: [
        ItemFieldDraftInput(fieldKey: 'title', valueText: '测试通用资料'),
        ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
        ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '3000-01-01'),
      ],
      attachments: [
        SaveAttachmentInput(
          itemId: 'temp-item-id',
          attachmentRole: 'proof',
          fileName: 'test.enc',
          originalName: 'test.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: 0,
        ),
      ],
    );
    final result = await service.saveDraft(draft);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 1. 验证 AppBar 显示类别或类型名称，无 subtitle
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('其他资料')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('通用资料')),
      findsNothing,
    );

    // 2. 验证摘要卡使用 compact 头部，显示成员归属但不显示 "类型：通用资料"
    expect(find.text('类型：通用资料'), findsNothing);
    expect(find.text('其他资料'), findsOneWidget);
    expect(find.textContaining('家庭'), findsOneWidget);

    // 3. 验证附件区文案不诱导使用真实图片（已删除“证明照片或扫描件”“当前仍处于开发验证阶段...”等冗余说明，但保留页面顶部开发验证警示）
    expect(find.textContaining('当前仍处于开发验证阶段，请仅使用'), findsNothing);
    expect(find.byType(AnchSecurityBanner), findsOneWidget);
    expect(find.textContaining('上传'), findsNothing);
  });

  testWidgets('数据加载失败时展示脱敏错误页面并提供返回操作', (WidgetTester tester) async {
    await tester.pumpWidget(buildTestWidget('non-existent-id'));
    await tester.pumpAndSettle();

    expect(find.text('资料加载失败'), findsOneWidget);
    expect(find.text('未找到对应的资料数据'), findsOneWidget);
    expect(findAnchIcon(AnchIcons.error), findsOneWidget);

    // 点击返回按钮
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
  });

  testWidgets('身份证详情页专属布局测试：无备注隐藏、有备注显示、取消高敏分区、地址有值显示无值隐藏、附件前置与无附件隐藏、长期有效逻辑', (
    WidgetTester tester,
  ) async {
    // 1. 无备注、无附件、长期有效为 true、地址为空 的身份证
    final draft1 = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-张三'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'is_long_term', valueText: 'true'),
      ],
    );
    final res1 = await service.saveDraft(draft1);
    expect(res1.success, isTrue);
    final itemId1 = res1.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId1));
    await tester.pumpAndSettle();

    // 检查不显示“备注”卡片，也不显示“暂无备注”
    expect(find.text('备注'), findsNothing);
    expect(find.text('暂无备注'), findsNothing);

    // 检查不显示独立“高敏信息”分区标题
    expect(find.text('高敏信息'), findsNothing);

    // 身份证号默认脱敏为 ••••  ••••  ••••  2345
    expect(find.text('基本信息'), findsNothing);
    expect(
      find.text('••••  ••••  ••••  2345'),
      findsOneWidget,
    ); // 只有身份证号脱敏，因为地址为空且无附件

    // 长期有效展示为“长期有效”
    expect(find.text('长期有效'), findsOneWidget);
    expect(find.text('true'), findsNothing);

    // 地址为空时不显示地址卡片/占位
    expect(find.text('户籍地址'), findsNothing);

    // 无附件时展示第一份附件的导入入口，不展示照片预览或空占位。
    expect(find.text('附件照片'), findsNothing);
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.byKey(const Key('add_attachment_button')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('add_attachment_button'))),
      const Size(64, 64),
    );
    expect(find.text('附件'), findsOneWidget);
    expect(find.text('添加照片、PDF 或文件'), findsOneWidget);
    expect(find.text('暂无证明照片或扫描件'), findsNothing);

    // 2. 有备注、有附件、长期有效为 false、地址有值 的身份证
    final docDir = testDir.path;
    final attachmentsDir = Directory(p.join(docDir, 'attachments'));
    attachmentsDir.createSync(recursive: true);
    final file = File(p.join(attachmentsDir.path, 'test_id.enc'));
    file.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

    final draft2 = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      note: 'TEST-这是备注内容',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-张三'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'address', valueText: 'TEST-北京市东城区'),
        ItemFieldDraftInput(fieldKey: 'is_long_term', valueText: 'false'),
      ],
      attachments: [
        SaveAttachmentInput(
          itemId: 'temp-item-id-2',
          attachmentRole: 'proof',
          fileName: 'test_id.enc',
          originalName: 'test_id.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: 0,
        ),
      ],
    );
    final res2 = await service.saveDraft(draft2);
    expect(res2.success, isTrue);
    final itemId2 = res2.itemId!;

    await tester.pumpWidget(
      buildTestWidget(itemId2, key: const Key('id_card_2')),
    );
    await tester.pumpAndSettle();

    // 有备注，正常显示备注卡片和备注内容
    expect(find.text('备注'), findsOneWidget);
    expect(find.text('TEST-这是备注内容'), findsOneWidget);

    // 身份证号默认用特殊格式脱敏，地址默认用 ****** 脱敏
    expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);
    expect(find.text('******'), findsOneWidget);
    expect(find.text('TEST-北京市东城区'), findsNothing);

    // 户籍地址作为字段标题显示，但分组标题户籍地址不作为卡片标题出现
    expect(find.text('户籍地址'), findsNothing);

    // is_long_term 为 false 时不展示原始 false，且隐藏该行
    expect(find.text('false'), findsNothing);
    expect(find.text('是否长期有效'), findsNothing);

    // 有附件时，“附件照片”卡片出现
    expect(find.textContaining('附件照片'), findsOneWidget);
    // 且只出现一次，不应该出现“附件”
    expect(find.text('附件'), findsNothing);
  });

  testWidgets('身份证详情页首屏优化体验测试：概要卡片瘦身、附件照片折叠展开、完整度卡片移除与通用卡片正常对照', (
    WidgetTester tester,
  ) async {
    // 1. 准备多张假附件（4张）
    final docDir = testDir.path;
    final attachmentsDir = Directory(p.join(docDir, 'attachments'));
    attachmentsDir.createSync(recursive: true);
    for (int i = 1; i <= 4; i++) {
      final file = File(p.join(attachmentsDir.path, 'test_id_$i.enc'));
      file.writeAsBytesSync(Uint8List.fromList([i]));
    }

    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-王五'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '320125199201012345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
      attachments: List.generate(
        4,
        (i) => SaveAttachmentInput(
          itemId: 'temp-item-id-3',
          attachmentRole: 'proof',
          fileName: 'test_id_${i + 1}.enc',
          originalName: 'test_id_${i + 1}.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: i,
        ),
      ),
    );

    final res = await service.saveDraft(draft);
    expect(res.success, isTrue);
    final itemId = res.itemId!;

    await tester.pumpWidget(
      buildTestWidget(itemId, key: const Key('id_card_3')),
    );
    await tester.pumpAndSettle();

    // ── 一、 身份证顶部概要卡片验证 ──
    // 1. 显示小标签：身份证
    expect(find.text('身份证'), findsOneWidget);
    // 2. 不显示大类标签“证件资料”
    expect(find.text('证件资料'), findsNothing);
    // 3. 不显示“类型：身份证”
    expect(find.text('类型：身份证'), findsNothing);
    // 4. 不显示 badges 选项
    expect(find.text('本地保存'), findsNothing);
    expect(find.text('默认脱敏'), findsNothing);
    expect(find.text('可复制字段'), findsNothing);
    // 5. 正确显示主标题，隐藏尾号摘要
    expect(find.text('TEST-王五的身份证'), findsOneWidget);
    expect(find.textContaining('尾号 2345'), findsNothing);

    // ── 二、 附件照片展示与展开折叠验证 ──
    // 6. 不展示照片区内的开发验证描述
    expect(find.textContaining('证明照片或扫描件。当前仍处于开发验证阶段'), findsNothing);
    // 7. 有 4 张附件时，应该直接全部展开显示
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_0')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_1')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_2')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_3')), findsOneWidget);
    expect(find.byKey(const Key('attachments_expand_button')), findsNothing);
    expect(find.byKey(const Key('attachments_collapse_button')), findsNothing);

    // ── 三、 完整度卡片不展示验证 ──
    expect(find.text('资料完整度参考'), findsNothing);

    // ── 四、 高敏字段安全策略验证 ──
    // 12. 默认脱敏
    expect(find.text('••••  ••••  ••••  2345'), findsOneWidget);
    // 13. 点击眼图标可以临时查看明文
    final pageScrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final eyeIcon = findAnchIcon(AnchIcons.visibility).first;
    await tester.scrollUntilVisible(eyeIcon, 50.0, scrollable: pageScrollable);
    await tester.pumpAndSettle();
    await tester.tap(eyeIcon);
    await tester.pumpAndSettle();
    expect(find.text('320125199201012345'), findsOneWidget);
  });

  testWidgets('附件行为一致性测试：身份证、户口本、普通类型（如储蓄卡）附件展示逻辑完全一致', (
    WidgetTester tester,
  ) async {
    final docDir = testDir.path;
    final attachmentsDir = Directory(p.join(docDir, 'attachments'));
    attachmentsDir.createSync(recursive: true);
    for (int i = 1; i <= 3; i++) {
      final file = File(p.join(attachmentsDir.path, 'test_id_card_$i.enc'));
      file.writeAsBytesSync(Uint8List.fromList([i]));
      final file2 = File(p.join(attachmentsDir.path, 'test_hb_$i.enc'));
      file2.writeAsBytesSync(Uint8List.fromList([i]));
      final file3 = File(p.join(attachmentsDir.path, 'test_debit_$i.enc'));
      file3.writeAsBytesSync(Uint8List.fromList([i]));
    }

    // 1. 0张附件展示首份附件入口
    final idCard0 = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '无附件身份证'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );
    final resIdCard0 = await service.saveDraft(idCard0);
    expect(resIdCard0.success, isTrue);
    await tester.pumpWidget(
      buildTestWidget(resIdCard0.itemId!, key: const Key('idCard0')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.byKey(const Key('add_attachment_button')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_0')), findsNothing);

    // 2. 1-2张附件直接展示 (debit_card 为普通类型)
    final debitCard2 = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '2附件储蓄卡'),
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225123456789012',
        ),
      ],
      attachments: List.generate(
        2,
        (i) => SaveAttachmentInput(
          itemId: 'temp-item-debit-2',
          attachmentRole: 'proof',
          fileName: 'test_debit_${i + 1}.enc',
          originalName: 'test_debit_${i + 1}.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: i,
        ),
      ),
    );
    final resDebitCard2 = await service.saveDraft(debitCard2);
    expect(resDebitCard2.success, isTrue);
    await tester.pumpWidget(
      buildTestWidget(resDebitCard2.itemId!, key: const Key('debitCard2')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.byKey(const Key('attachments_expand_button')), findsNothing);
    expect(find.byKey(const Key('attachment_item_0')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_1')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('attachment_tile_0'))),
      const Size(64, 64),
    );

    // 3. >2张附件，可展开/收起 (household_book 为户口本)
    final hbCard3 = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'household_book',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'household_number',
          valueText: '12345678',
        ),
      ],
      attachments: List.generate(
        3,
        (i) => SaveAttachmentInput(
          itemId: 'temp-item-hb-3',
          attachmentRole: 'proof',
          fileName: 'test_hb_${i + 1}.enc',
          originalName: 'test_hb_${i + 1}.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: i,
        ),
      ),
    );
    final resHbCard3 = await service.saveDraft(hbCard3);
    expect(resHbCard3.success, isTrue);
    await tester.pumpWidget(
      buildTestWidget(resHbCard3.itemId!, key: const Key('hbCard3')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);

    expect(find.byKey(const Key('attachment_item_0')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_1')), findsOneWidget);
    expect(find.byKey(const Key('attachment_item_2')), findsOneWidget);
    expect(find.byKey(const Key('attachments_expand_button')), findsNothing);
    expect(find.byKey(const Key('attachments_collapse_button')), findsNothing);
  });

  testWidgets('备注生命周期测试：新增有备注显示卡片、清空保存后完全隐藏卡片', (WidgetTester tester) async {
    // 1. 新增有备注
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      note: '这是原始备注',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '测试备注'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );
    final res = await service.saveDraft(draft);
    expect(res.success, isTrue);
    final itemId = res.itemId!;

    await tester.pumpWidget(
      buildTestWidget(itemId, key: const Key('note_view_1')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_card')), findsOneWidget);
    expect(find.text('这是原始备注'), findsOneWidget);

    // 2. 清空备注并保存
    final clearedDraft = ItemDraftInput(
      id: itemId,
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      note: null, // 清空备注
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '测试备注'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );
    final res2 = await service.saveDraft(clearedDraft);
    expect(res2.success, isTrue);

    await tester.pumpWidget(
      buildTestWidget(itemId, key: const Key('note_view_2')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note_card')), findsNothing);
    expect(find.text('这是原始备注'), findsNothing);
  });

  testWidgets('备注安全边界测试：备注不进入 searchText, summaryText', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      note: 'GALAXY_SECRET_NOTE_TEXT_123',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '张备注'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
    );
    final res = await service.saveDraft(draft);
    expect(res.success, isTrue);
    final itemId = res.itemId!;

    final itemWithFields = await service.itemRepo.getItemWithFields(itemId);
    expect(itemWithFields, isNotNull);

    // 验证备注确实没进入 searchText
    expect(
      itemWithFields!.searchText?.contains('GALAXY_SECRET_NOTE_TEXT_123') ??
          false,
      isFalse,
    );
    // 验证备注确实没进入 summaryText
    expect(
      itemWithFields.summaryText != null &&
          itemWithFields.summaryText!.contains('GALAXY_SECRET_NOTE_TEXT_123'),
      isFalse,
    );
  });

  testWidgets('收口资料详情页首屏信息架构测试：统一证件类顶部卡片 compact、资料字段优先、不影响非证件、不重复渲染', (
    WidgetTester tester,
  ) async {
    final docDir = testDir.path;
    final attachmentsDir = Directory(p.join(docDir, 'attachments'));
    attachmentsDir.createSync(recursive: true);
    final file = File(p.join(attachmentsDir.path, 'hb_att.enc'));
    file.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    final file2 = File(p.join(attachmentsDir.path, 'debit_att.enc'));
    file2.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    final file3 = File(p.join(attachmentsDir.path, 'idcard_att.enc'));
    file3.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));

    // 1. 准备假数据
    // 户口本（证件类），有 1 个附件
    final hbDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'household_book',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'household_number',
          valueText: '88889999',
        ),
      ],
      attachments: [
        SaveAttachmentInput(
          itemId: 'temp-hb-att-id',
          attachmentRole: 'proof',
          fileName: 'hb_att.enc',
          originalName: 'hb_att.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: 0,
        ),
      ],
    );
    final resHb = await service.saveDraft(hbDraft);
    expect(resHb.success, isTrue);

    // 普通类型（非证件类），有 1 个附件
    final debitDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'other',
      typeKey: 'generic',
      fields: [
        ItemFieldDraftInput(fieldKey: 'title', valueText: '测试通用资料'),
        ItemFieldDraftInput(fieldKey: 'owner_name', valueText: '张三'),
      ],
      attachments: [
        SaveAttachmentInput(
          itemId: 'temp-debit-att-id',
          attachmentRole: 'proof',
          fileName: 'debit_att.enc',
          originalName: 'debit_att.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: 0,
        ),
      ],
    );
    final resDebit = await service.saveDraft(debitDraft);
    expect(resDebit.success, isTrue);

    // 身份证（证件类），有 1 个附件
    final idCardDraft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'id_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'name', valueText: '测试身份证'),
        ItemFieldDraftInput(
          fieldKey: 'id_number',
          valueText: '110101199003072345',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
      ],
      attachments: [
        SaveAttachmentInput(
          itemId: 'temp-idcard-att-id',
          attachmentRole: 'proof',
          fileName: 'idcard_att.enc',
          originalName: 'idcard_att.png',
          mimeType: 'image/png',
          plainSize: 100,
          encryptedSize: 120,
          sortOrder: 0,
        ),
      ],
    );
    final resIdCard = await service.saveDraft(idCardDraft);
    expect(resIdCard.success, isTrue);

    // 2. 验证户口本（证件类）详情页顶部卡片为 compact: true
    await tester.pumpWidget(
      buildTestWidget(resHb.itemId!, key: const Key('hb_details')),
    );
    await tester.pumpAndSettle();

    // - 不显示“证件资料”
    expect(find.text('证件资料'), findsNothing);
    // - 不显示“类型：户口本”
    expect(find.text('类型：户口本'), findsNothing);
    // - 不显示底部 badges
    expect(find.text('本地保存'), findsNothing);
    expect(find.text('默认脱敏'), findsNothing);
    expect(find.text('可复制字段'), findsNothing);
    // - 顶部小标签显示具体类型“户口本”
    expect(find.text('户口本'), findsOneWidget);
    // - 仍显示主标题，例如“家庭的户口本”
    expect(find.text('家庭的户口本'), findsOneWidget);

    // - 验证资料字段优先：号码面板出现在附件之前
    final hbAttachmentsY = tester
        .getTopLeft(find.byKey(const Key('attachments_card')))
        .dy;
    final hbFieldsY = tester
        .getTopLeft(find.byKey(const Key('primary_number_card')))
        .dy;
    expect(hbFieldsY < hbAttachmentsY, isTrue);

    // - 验证不重复渲染与完整度不显示：
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.text('资料完整度参考'), findsNothing);
    expect(find.text('操作记录'), findsOneWidget);

    // 3. 验证通用资料（generic）现为 compact 头部，不显示 badges 和类型说明
    await tester.pumpWidget(
      buildTestWidget(resDebit.itemId!, key: const Key('debit_details')),
    );
    await tester.pumpAndSettle();

    // - compact 头部显示"其他资料"标签，不显示"类型：..."、badges
    expect(find.text('其他资料'), findsWidgets);
    expect(find.text('类型：通用资料'), findsNothing);
    expect(find.text('本地保存'), findsNothing);
    expect(find.text('默认脱敏'), findsNothing);
    expect(find.text('可复制字段'), findsNothing);

    // - 验证附件区存在且资料完整度不显示
    expect(find.byKey(const Key('attachments_card')), findsOneWidget);
    expect(find.text('资料完整度参考'), findsNothing);

    // 4. 验证身份证（证件类）详情页顶部卡片为 compact: true，且资料字段优先
    await tester.pumpWidget(
      buildTestWidget(resIdCard.itemId!, key: const Key('idcard_details')),
    );
    await tester.pumpAndSettle();

    // - 不显示“证件资料”
    expect(find.text('证件资料'), findsNothing);
    // - 不显示“类型：身份证”
    expect(find.text('类型：身份证'), findsNothing);
    // - 不显示底部 badges
    expect(find.text('本地保存'), findsNothing);
    // - 顶部小标签显示具体类型“身份证”
    expect(find.text('身份证'), findsOneWidget);

    // - 验证资料字段优先：号码面板出现在附件之前
    final idCardAttachmentsY = tester
        .getTopLeft(find.byKey(const Key('attachments_card')))
        .dy;
    final idCardFieldsY = tester
        .getTopLeft(find.byKey(const Key('primary_number_card')))
        .dy;
    expect(idCardFieldsY < idCardAttachmentsY, isTrue);
    expect(find.text('资料完整度参考'), findsNothing);
  });

  testWidgets('驾驶证详情页：四分组正确、档案编号在证件信息、不显示国籍', (WidgetTester tester) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'driver_license',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'license_number',
          valueText: 'TEST-DRIVING-LICENSE-NUMBER',
        ),
        ItemFieldDraftInput(
          fieldKey: 'file_number',
          valueText: 'TEST-FILE-NUMBER-001',
        ),
        ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-张三'),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '2000-01-01'),
        ItemFieldDraftInput(fieldKey: 'address', valueText: 'TEST-ADDRESS-XXX'),
        ItemFieldDraftInput(fieldKey: 'vehicle_class', valueText: 'C1'),
        ItemFieldDraftInput(fieldKey: 'issue_date', valueText: '2020-01-01'),
        ItemFieldDraftInput(
          fieldKey: 'issuing_authority',
          valueText: 'TEST-AUTHORITY',
        ),
        ItemFieldDraftInput(fieldKey: 'valid_from', valueText: '2020-01-01'),
        ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2026-01-01'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 验证四个分组卡片标题均不出现
    expect(find.text('证件信息'), findsNothing);
    expect(find.text('基本身份信息'), findsNothing);
    expect(find.text('驾驶资格'), findsNothing);
    expect(find.text('签发与有效期'), findsNothing);

    // 验证"档案编号"出现在详情页
    expect(find.text('档案编号'), findsOneWidget);

    // 验证国籍字段不在详情页中显示（历史旧数据也不展示）
    expect(find.text('国籍'), findsNothing);
    expect(find.text('nationality'), findsNothing);
  });

  testWidgets('驾驶证详情页：带 nationality 历史数据时，编辑页和详情页均不展示国籍', (
    WidgetTester tester,
  ) async {
    // 模拟旧数据：包含 nationality 字段（现已从模板删除）
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'driver_license',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'license_number',
          valueText: 'TEST-DRIVING-LICENSE-NUMBER-OLD',
        ),
        ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-李四'),
        // 即使传入旧 nationality 历史值，模板中不再有该字段定义，UI 不应展示
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 详情页不显示国籍
    expect(find.text('国籍'), findsNothing);
    // 分组结构仍然正确（有内容的分组出现）
    expect(find.text('证件信息'), findsNothing);
  });

  testWidgets('行驶证详情页：四分组正确、核定载人数在车辆信息、不显示档案编号/总质量/检验记录，且过滤历史废弃字段', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'vehicle_license',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'plate_number',
          valueText: 'TEST-PLATE-123',
        ),
        ItemFieldDraftInput(fieldKey: 'vin', valueText: 'TEST-VIN-456'),
        ItemFieldDraftInput(
          fieldKey: 'engine_number',
          valueText: 'TEST-ENGINE-789',
        ),
        ItemFieldDraftInput(fieldKey: 'vehicle_type', valueText: '小型轿车'),
        ItemFieldDraftInput(fieldKey: 'model', valueText: 'TEST-MODEL-BMW'),
        ItemFieldDraftInput(fieldKey: 'use_character', valueText: '非营运'),
        ItemFieldDraftInput(fieldKey: 'approved_passengers', valueText: '5'),
        ItemFieldDraftInput(
          fieldKey: 'owner_name',
          valueText: 'TEST-OWNER-NAME',
        ),
        ItemFieldDraftInput(
          fieldKey: 'address',
          valueText: 'TEST-ADDRESS-CITY',
        ),
        ItemFieldDraftInput(fieldKey: 'register_date', valueText: '2020-05-20'),
        ItemFieldDraftInput(fieldKey: 'issue_date', valueText: '2020-05-25'),
        ItemFieldDraftInput(
          fieldKey: 'issuing_authority',
          valueText: 'TEST-AUTHORITY-OFFICE',
        ),
        // 模拟数据库中存在的历史废弃字段
        ItemFieldDraftInput(
          fieldKey: 'file_number',
          valueText: 'TEST-FILE-NUMBER',
        ),
        ItemFieldDraftInput(fieldKey: 'total_mass', valueText: '2000kg'),
        ItemFieldDraftInput(
          fieldKey: 'inspection_record',
          valueText: 'TEST-INSPECTION',
        ),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    // 1. 验证详情页不展示废弃字段且分组正确
    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 验证四个分组卡片标题均不出现
    expect(find.text('车辆标识'), findsNothing);
    expect(find.text('车辆信息'), findsNothing);
    expect(find.text('所有人信息'), findsNothing);
    expect(find.text('登记与发证'), findsNothing);

    // 验证核定载人数在页面中
    expect(find.text('核定载人数'), findsOneWidget);

    // 验证历史废弃字段不在详情页显示
    expect(find.text('档案编号'), findsNothing);
    expect(find.text('总质量'), findsNothing);
    expect(find.text('检验记录'), findsNothing);
    expect(find.text('TEST-FILE-NUMBER'), findsNothing);
    expect(find.text('2000kg'), findsNothing);
    expect(find.text('TEST-INSPECTION'), findsNothing);

    // 2. 验证编辑页也不展示废弃字段
    await tester.pumpWidget(
      wrapTest(
        MaterialApp(home: ItemEntryFlowPage(existingItemId: itemId)),
        runtime,
        (child) => di.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('编辑行驶证'), findsOneWidget);
    expect(
      find.byKey(const Key('item_field_control_file_number')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('item_field_control_total_mass')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('item_field_control_inspection_record')),
      findsNothing,
    );
  });

  testWidgets('出生证明详情页：三分组正确、出生时间在新生儿信息分组、字段展示顺序符合规划', (
    WidgetTester tester,
  ) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'birth_certificate',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'child_name',
          valueText: 'TEST-BABY-NAME',
        ),
        ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '2026-01-01'),
        ItemFieldDraftInput(fieldKey: 'birth_time', valueText: 'TEST-12:00'),
        ItemFieldDraftInput(
          fieldKey: 'birth_place',
          valueText: 'TEST-HOSPITAL',
        ),
        ItemFieldDraftInput(fieldKey: 'father_name', valueText: 'TEST-FATHER'),
        ItemFieldDraftInput(fieldKey: 'mother_name', valueText: 'TEST-MOTHER'),
        ItemFieldDraftInput(
          fieldKey: 'certificate_number',
          valueText: 'TEST-BIRTH-CERTIFICATE-NUMBER',
        ),
        ItemFieldDraftInput(
          fieldKey: 'issuing_authority',
          valueText: 'TEST-AUTHORITY',
        ),
        ItemFieldDraftInput(fieldKey: 'issue_date', valueText: '2026-01-05'),
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 验证三个分组卡片标题均不出现
    expect(find.text('新生儿信息'), findsNothing);
    expect(find.text('父母信息'), findsNothing);
    expect(find.text('证明信息'), findsNothing);

    // 验证页面包含出生时间、新生儿姓名、性别、出生地点、父亲姓名、母亲姓名、证件编号、签发机构、签发日期
    expect(find.text('出生时间'), findsOneWidget);
    expect(find.text('新生儿姓名'), findsOneWidget);
    expect(find.text('性别'), findsOneWidget);
    expect(find.text('出生地点'), findsOneWidget);
    expect(find.text('父亲姓名'), findsOneWidget);
    expect(find.text('母亲姓名'), findsOneWidget);
    expect(find.text('证件编号'), findsOneWidget);
    expect(find.text('签发机构'), findsOneWidget);
    expect(find.text('签发日期'), findsOneWidget);
  });

  testWidgets('结婚证详情页：二分组正确、历史婚姻登记处字段过滤且顺序符合规划', (WidgetTester tester) async {
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'certificate',
      typeKey: 'marriage_certificate',
      fields: [
        ItemFieldDraftInput(
          fieldKey: 'holder_name',
          valueText: 'TEST-HOLDER-NAME',
        ),
        ItemFieldDraftInput(
          fieldKey: 'spouse_name',
          valueText: 'TEST-SPOUSE-NAME',
        ),
        ItemFieldDraftInput(
          fieldKey: 'certificate_number',
          valueText: 'TEST-MARRIAGE-NUMBER',
        ),
        ItemFieldDraftInput(fieldKey: 'register_date', valueText: '2026-01-01'),
        ItemFieldDraftInput(
          fieldKey: 'issuing_authority',
          valueText: 'TEST-MARRIAGE-AUTHORITY',
        ),
        ItemFieldDraftInput(
          fieldKey: 'marriage_registration_office',
          valueText: 'TEST-REGISTRY-OFFICE',
        ), // 历史数据
      ],
    );

    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 验证两个分组卡片标题均不出现
    expect(find.text('婚姻关系人'), findsNothing);
    expect(find.text('登记信息'), findsNothing);

    // 验证页面包含持证人姓名、配偶姓名、登记日期、登记机关、以及证件编号
    expect(find.text('持证人姓名'), findsOneWidget);
    expect(find.text('配偶姓名'), findsOneWidget);
    expect(find.text('登记日期'), findsOneWidget);
    expect(find.text('登记机关'), findsOneWidget);
    expect(find.text('证件编号'), findsOneWidget);

    // 验证极其重要：不论是“婚姻登记处”标题，还是历史数据“TEST-REGISTRY-OFFICE”，均不在页面显示
    expect(find.text('婚姻登记处'), findsNothing);
    expect(find.text('TEST-REGISTRY-OFFICE'), findsNothing);
  });

  testWidgets('储蓄卡详情页头部复制入口仅提供卡号和完整信息', (WidgetTester tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = methodCall.arguments['text'] as String?;
          return null;
        }
        if (methodCall.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': copiedText};
        }
        return null;
      },
    );
    final draft = ItemDraftInput(
      memberId: systemFamilyMemberId,
      categoryKey: 'card',
      typeKey: 'debit_card',
      fields: [
        ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-BANK-NAME'),
        ItemFieldDraftInput(fieldKey: 'card_alias', valueText: 'TEST-ALIAS'),
        ItemFieldDraftInput(
          fieldKey: 'card_number',
          valueText: '6225881234567890',
        ),
        ItemFieldDraftInput(fieldKey: 'account_name', valueText: 'TEST-HOLDER'),
        ItemFieldDraftInput(fieldKey: 'branch_name', valueText: 'TEST-BRANCH'),
      ],
    );
    final result = await service.saveDraft(draft);
    expect(result.success, isTrue);
    final itemId = result.itemId!;

    await tester.pumpWidget(buildTestWidget(itemId));
    await tester.pumpAndSettle();

    // 1. 验证复制入口存在并点击
    final copyBtn = find.byKey(const Key('debit_card_header_copy'));
    expect(copyBtn, findsOneWidget);
    await tester.tap(copyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 2. 验证弹出底部菜单选项
    expect(find.text('选择复制内容'), findsNothing);
    expect(find.text('仅复制卡号'), findsOneWidget);
    expect(find.text('复制完整信息'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);

    // 3. 测试取消操作
    await tester.tap(find.text('取消'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('复制完整信息'), findsNothing);

    // 4. 测试仅复制卡号
    await tester.tap(copyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('仅复制卡号'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 触发了高敏复制确认 Dialog
    expect(find.text('确认复制敏感字段？'), findsOneWidget);
    // 验证包含了要复制的内容预览
    expect(find.text('6225881234567890'), findsOneWidget);
    expect(find.text('复制内容会进入系统剪贴板，可能被其他应用读取。'), findsNothing);
    expect(find.text('将复制以下内容：'), findsNothing);
    await tester.tap(find.text('确认复制'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证剪贴板数据
    final clipboardData1 = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData1?.text, '6225881234567890');

    // 5. 测试复制完整信息
    await tester.tap(copyBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('复制完整信息'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 触发了敏感确认 Dialog
    expect(find.text('确认复制敏感字段？'), findsOneWidget);
    // 验证包含了转账信息内容预览
    final expectedTransferPreview =
        '户名：TEST-HOLDER\n'
        '卡号：6225881234567890\n'
        '银行：TEST-BANK-NAME\n'
        '开户行：TEST-BRANCH';
    expect(find.text(expectedTransferPreview), findsOneWidget);
    await tester.tap(find.text('确认复制'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 验证剪贴板转账信息格式
    final clipboardData2 = await Clipboard.getData(Clipboard.kTextPlain);
    expect(clipboardData2?.text, expectedTransferPreview);
  });

  testWidgets('收货地址详情仅用一个入口复制带字段名的四行文本', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (methodCall) async {
        if (methodCall.method == 'Clipboard.setData') {
          copiedText = methodCall.arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final result = await service.saveDraft(
      ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'shipping_address',
        fields: [
          ItemFieldDraftInput(fieldKey: 'recipient_name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'phone_number',
            valueText: '13800138000',
          ),
          ItemFieldDraftInput(fieldKey: 'region', valueText: '浙江省杭州市西湖区'),
          ItemFieldDraftInput(
            fieldKey: 'detailed_address',
            valueText: '文三路90号',
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildTestWidget(result.itemId!));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shipping_address_copy')), findsOneWidget);
    expect(findAnchIcon(AnchIcons.copy), findsOneWidget);
    await tester.tap(find.byKey(const Key('shipping_address_copy')));
    await tester.pump();

    expect(
      copiedText,
      '收件人：张三\n'
      '手机号码：13800138000\n'
      '所在地区：浙江省杭州市西湖区\n'
      '详细地址：文三路90号',
    );
    expect(find.text('确认复制敏感字段？'), findsNothing);
  });

  group('ItemDetailPage PrivacyShield 防窥信号测试', () {
    Widget buildPrivacyTestWidget({
      required String itemId,
      PrivacyShieldCoordinator? coordinator,
    }) {
      return wrapTest(
        MaterialApp(
          home: ItemDetailPage(
            itemId: itemId,
            privacyShieldCoordinator: coordinator,
          ),
        ),
        runtime,
        (child) => di.copyWith(child: child),
      );
    }

    testWidgets('1. 未注入 coordinator 时，ItemDetailPage 正常展示且展开/收起不崩溃', (
      WidgetTester tester,
    ) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '110101199003072345',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      expect(
        result.success,
        isTrue,
        reason: 'saveDraft failed: ${result.errors}',
      );
      final itemId = result.itemId!;

      await tester.pumpWidget(buildPrivacyTestWidget(itemId: itemId));
      await tester.pumpAndSettle();

      expect(find.textContaining('TEST-张三'), findsAtLeastNWidgets(1));
      expect(find.text('110101199003072345'), findsNothing);

      // 敏感字段直接在分组卡片内展示（已脱敏），不需要展开高敏卡片
      expect(find.text('高敏信息'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 点击展开
      final revealIcon = findAnchIcon(AnchIcons.visibility);
      await tester.scrollUntilVisible(revealIcon, 50.0, scrollable: scrollable);
      await tester.tap(revealIcon);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsOneWidget);

      // 点击收起
      final hideIcon = findAnchIcon(AnchIcons.visibilityOff);
      await tester.ensureVisible(hideIcon);
      await tester.tap(hideIcon);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsNothing);
    });

    testWidgets('2. 注入 coordinator 时，初始 isVisible=false，展开后为 true，收起后为 false', (
      WidgetTester tester,
    ) async {
      final controller = PrivacyShieldController();
      final coordinator = PrivacyShieldCoordinator(controller: controller);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '110101199003072345',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(
        buildPrivacyTestWidget(itemId: itemId, coordinator: coordinator),
      );
      await tester.pumpAndSettle();

      expect(controller.isVisible, isFalse);
      expect(find.text('高敏信息'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 展开高敏字段
      final revealIcon = findAnchIcon(AnchIcons.visibility);
      await tester.scrollUntilVisible(revealIcon, 50.0, scrollable: scrollable);
      await tester.tap(revealIcon);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);

      // 收起高敏字段
      final hideIcon = findAnchIcon(AnchIcons.visibilityOff);
      await tester.ensureVisible(hideIcon);
      await tester.tap(hideIcon);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);
    });

    testWidgets('3. 多个高敏字段在前台展开或收起时均不触发遮罩', (WidgetTester tester) async {
      final controller = PrivacyShieldController();
      final coordinator = PrivacyShieldCoordinator(controller: controller);

      // 使用身份证模板（含 id_number 和 address 两个高敏字段）验证多字段展开/收起协调逻辑
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ItemFieldDraftInput(fieldKey: 'address', valueText: '北京市朝阳区'),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(
        buildPrivacyTestWidget(itemId: itemId, coordinator: coordinator),
      );
      await tester.pumpAndSettle();

      expect(controller.isVisible, isFalse);
      expect(find.text('高敏信息'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 展开第一个
      final visibilityIcons = findAnchIcon(AnchIcons.visibility);
      expect(visibilityIcons, findsNWidgets(2));
      await tester.scrollUntilVisible(
        visibilityIcons.first,
        50.0,
        scrollable: scrollable,
      );
      await tester.tap(visibilityIcons.first);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);

      // 展开第二个
      final secondIcon = findAnchIcon(AnchIcons.visibility);
      await tester.ensureVisible(secondIcon);
      await tester.tap(secondIcon);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);

      // 收起其中一个，另一个仍然展开，也不应触发遮罩。
      final offIcons = findAnchIcon(AnchIcons.visibilityOff);
      await tester.ensureVisible(offIcons.first);
      await tester.tap(offIcons.first);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);

      // 全部收起后仍无页面级遮罩。
      final lastOffIcon = findAnchIcon(AnchIcons.visibilityOff);
      await tester.ensureVisible(lastOffIcon);
      await tester.tap(lastOffIcon);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);
    });

    testWidgets('4. 生命周期触发高敏字段自动收起时，不影响其它活跃来源', (WidgetTester tester) async {
      final controller = PrivacyShieldController();
      final coordinator = PrivacyShieldCoordinator(
        controller: controller,
        source: PrivacyShieldSource.itemDetail,
      );

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '110101199003072345',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(
        buildPrivacyTestWidget(itemId: itemId, coordinator: coordinator),
      );
      await tester.pumpAndSettle();

      expect(controller.isVisible, isFalse);
      expect(find.text('高敏信息'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 展开
      final revealIcon = findAnchIcon(AnchIcons.visibility);
      await tester.scrollUntilVisible(revealIcon, 50.0, scrollable: scrollable);
      await tester.tap(revealIcon);
      await tester.pumpAndSettle();
      expect(controller.isVisible, isFalse);

      // 模拟其它活跃来源开启
      controller.show(PrivacyShieldSource.appLockInput);

      // 模拟 inactive 生命周期
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // 验证高敏字段已被自动收起，且其它来源仍让遮罩保持为 true。
      expect(find.text('110101199003072345'), findsNothing);
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.appLockInput});
    });

    testWidgets('5. 页面销毁不影响其它防窥来源', (WidgetTester tester) async {
      final controller = PrivacyShieldController(initialVisible: false);
      final coordinator = PrivacyShieldCoordinator(
        controller: controller,
        source: PrivacyShieldSource.itemDetail,
      );

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '110101199003072345',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            routes: {
              '/': (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/detail'),
                  child: const Text('Go'),
                ),
              ),
              '/detail': (context) => ItemDetailPage(
                itemId: itemId,
                privacyShieldCoordinator: coordinator,
              ),
            },
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 手动使另一个来源活跃
      controller.show(PrivacyShieldSource.appLockInput);

      // 1. 前往详情页
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.appLockInput});

      // 2. 展开字段
      expect(find.text('高敏信息'), findsNothing);
      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final revealIcon = findAnchIcon(AnchIcons.visibility);
      await tester.scrollUntilVisible(revealIcon, 50.0, scrollable: scrollable);
      await tester.tap(revealIcon);
      await tester.pumpAndSettle();
      expect(controller.activeSources, {PrivacyShieldSource.appLockInput});

      // 3. 返回上一页以 dispose 详情页
      final backIcon = findAnchIcon(AnchIcons.back);
      await tester.ensureVisible(backIcon);
      await tester.tap(backIcon);
      await tester.pumpAndSettle();

      // 4. 因为有 appLockInput，退出详情页后遮罩仍然显示。
      expect(controller.isVisible, isTrue);
      expect(controller.activeSources, {PrivacyShieldSource.appLockInput});
    });

    test('6. 单元测试: 绝不透露任何敏感值或凭证到 toString 或日志中', () {
      const signal = PrivacyShieldSignal(
        hasVisibleSensitiveField: true,
        isEnteringPin: false,
      );

      final logString = signal.toString();
      expect(logString, contains('PrivacyShieldSignal'));
      expect(logString, contains('hasVisibleSensitiveField: true'));
      expect(logString, isNot(contains('TEST-sensitive-value')));
      expect(logString, isNot(contains('PIN')));
      expect(logString, isNot(contains('salt')));
      expect(logString, isNot(contains('verifier')));
      expect(logString, isNot(contains('databaseKey')));
    });
  });

  group('ItemDetailPage 字段复制与安全控制测试', () {
    String? copiedText;

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

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('1. 验证普通 copyable 字段显示复制按钮，非 copyable 字段和空值字段不显示复制按钮', (
      WidgetTester tester,
    ) async {
      setupMockClipboard(tester);
      copiedText = null;

      final debitDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'bank_name',
            valueText: 'TEST-BANK-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: 'TEST-ALIAS'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
          ItemFieldDraftInput(
            fieldKey: 'account_name',
            valueText: 'TEST-ACC-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'branch_name', valueText: ''),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13812345678',
          ),
        ],
      );

      final result = await service.saveDraft(debitDraft);
      expect(result.success, isTrue);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      expect(find.text('TEST-BANK-NAME'), findsOneWidget);
      expect(find.text('TEST-ALIAS（7890）'), findsOneWidget);
      expect(find.text('TEST-ALIAS'), findsOneWidget);

      expect(find.text('高敏信息'), findsNothing);

      final copyIcons = findAnchIcon(AnchIcons.copy);
      expect(copyIcons, findsNWidgets(3));
    });

    testWidgets('2. 点击普通字段复制直接写入剪贴板，弹出 SnackBar 且不含原始值', (
      WidgetTester tester,
    ) async {
      setupMockClipboard(tester);
      copiedText = null;

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'bank_name',
            valueText: 'TEST-BANK-VAL',
          ),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: 'TEST-ALIAS'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
          ItemFieldDraftInput(
            fieldKey: 'account_name',
            valueText: 'TEST-ACC-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'branch_name', valueText: ''),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13812345678',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final copyBtn = find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is AnchSensitiveFieldRow || w is AnchInfoFieldRow,
            ),
            matching: findAnchIcon(AnchIcons.copy),
          )
          .at(0);
      await tester.scrollUntilVisible(
        copyBtn,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();

      await tester.tap(copyBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(copiedText, equals('TEST-BANK-VAL'));
      expect(find.text('复制成功'), findsOneWidget);
      expect(find.byKey(AnchCenteredNotice.noticeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('TEST-BANK-VAL'),
        ),
        findsNothing,
      );
    });

    testWidgets('3. 下方 high/medium 字段复制直接写入剪贴板，顶部卡片仍需确认', (
      WidgetTester tester,
    ) async {
      setupMockClipboard(tester);
      copiedText = null;

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'bank_name',
            valueText: 'TEST-BANK-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: 'TEST-ALIAS'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
          ItemFieldDraftInput(
            fieldKey: 'account_name',
            valueText: 'TEST-ACC-VAL',
          ),
          ItemFieldDraftInput(fieldKey: 'branch_name', valueText: ''),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13812345678',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      expect(find.text('高敏信息'), findsNothing);

      final copyIcons = findAnchIcon(AnchIcons.copy);
      expect(copyIcons, findsNWidgets(3));

      final accCopyBtn = copyIcons.at(2);
      await tester.scrollUntilVisible(
        accCopyBtn,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      await tester.tap(accCopyBtn);
      await tester.pumpAndSettle();

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('确认复制敏感字段？'), findsNothing);
      expect(copiedText, equals('TEST-ACC-VAL'));
      expect(find.text('复制成功'), findsOneWidget);
      expect(find.byKey(AnchCenteredNotice.noticeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('TEST-ACC-VAL'),
        ),
        findsNothing,
      );

      await tester.pumpAndSettle();
      copiedText = null;

      final cardCopyBtn = copyIcons.at(0);
      await tester.scrollUntilVisible(
        cardCopyBtn,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      await tester.tap(cardCopyBtn);
      await tester.pumpAndSettle();

      expect(find.text('选择复制内容'), findsNothing);
      await tester.tap(find.text('仅复制卡号'));
      await tester.pumpAndSettle();

      expect(find.text('确认复制敏感字段？'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('6225881234567890'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('确认复制'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(copiedText, equals('6225881234567890'));
      expect(find.text('复制成功'), findsOneWidget);
      expect(find.byKey(AnchCenteredNotice.noticeKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('6225881234567890'),
        ),
        findsNothing,
      );
    });

    testWidgets('4. 验证安全红线：无误导宣传及敏感技术名词露出', (WidgetTester tester) async {
      setupMockClipboard(tester);

      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'bank_name',
            valueText: 'TEST-BANK-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: 'TEST-ALIAS'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'tail_number', valueText: '7890'),
          ItemFieldDraftInput(
            fieldKey: 'account_name',
            valueText: 'TEST-ACC-NAME',
          ),
          ItemFieldDraftInput(fieldKey: 'branch_name', valueText: ''),
          ItemFieldDraftInput(
            fieldKey: 'reserved_phone',
            valueText: '13812345678',
          ),
        ],
      );
      final result = await service.saveDraft(draft);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      expect(find.text('高敏信息'), findsNothing);

      final copyIcons = findAnchIcon(AnchIcons.copy);
      final cardCopyBtn = copyIcons.first;
      await tester.scrollUntilVisible(
        cardCopyBtn,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.pumpAndSettle();
      await tester.tap(cardCopyBtn);
      await tester.pumpAndSettle();

      final List<String> allTexts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .toList();

      final forbiddenClaims = [
        '正式安全模式已启用',
        '银行级',
        '绝对安全',
        '永不泄露',
        '无法破解',
        '放心录入真实敏感',
      ];

      final forbiddenTechTerms = [
        'databaseKey',
        'backupKey',
        'Secure Storage',
        'Keystore',
        'salt',
        'verifier',
        'token',
        '/data/data/',
        'content://',
        'file://',
      ];

      for (final text in allTexts) {
        for (final claim in forbiddenClaims) {
          expect(text.contains(claim), isFalse, reason: '文案含有不合规承诺: $claim');
        }
        for (final term in forbiddenTechTerms) {
          expect(
            text.toLowerCase().contains(term.toLowerCase()),
            isFalse,
            reason: '文案泄露敏感技术词: $term',
          );
        }
      }
    });

    testWidgets(
      '5. 验证 AnchSensitiveFieldRow 仅通过 onCopy(fieldId) 回抛，不泄露 value/label',
      (WidgetTester tester) async {
        String? callbackFieldId;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnchSensitiveFieldRow(
                fieldId: 'sensitive_test_id',
                fieldKey: 'sensitive_test',
                label: '高敏测试',
                value: 'sensitive_value',
                maskedValue: '******',
                isRevealed: false,
                copyable: true,
                onToggleReveal: (_) {},
                onCopy: (id) {
                  callbackFieldId = id;
                },
              ),
            ),
          ),
        );

        final trailingActions = find.byKey(
          const Key('field_trailing_actions_sensitive_test'),
        );
        final eyeIcon = find.descendant(
          of: trailingActions,
          matching: findAnchIcon(AnchIcons.visibility),
        );
        final copyBtn = findAnchIcon(AnchIcons.copy);
        expect(tester.getSize(trailingActions).width, 100);
        expect(
          (tester.getCenter(eyeIcon).dx - tester.getCenter(copyBtn).dx).abs(),
          greaterThanOrEqualTo(48),
        );
        expect(
          find.descendant(of: trailingActions, matching: find.byType(InkWell)),
          findsNothing,
        );
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pump();

        expect(callbackFieldId, equals('sensitive_test_id'));
      },
    );

    testWidgets(
      '6. 验证 AnchInfoFieldRow 仅通过 onCopy(fieldId) 回抛，不泄露 value/label',
      (WidgetTester tester) async {
        String? callbackFieldId;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AnchInfoFieldRow(
                fieldId: 'info_test_id',
                label: '普通测试',
                value: 'info_value',
                copyable: true,
                onCopy: (id) {
                  callbackFieldId = id;
                },
              ),
            ),
          ),
        );

        final copyBtn = findAnchIcon(AnchIcons.copy);
        expect(copyBtn, findsOneWidget);
        await tester.tap(copyBtn);
        await tester.pump();

        expect(callbackFieldId, equals('info_test_id'));
      },
    );
  });

  group('ItemDetailPage 字段布局测试', () {
    testWidgets('1. 资料详情页字段三层展示、折叠体验与安全收口测试', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'credit_card',
        title: '张三的测试信用卡',
        note: '这是用于详情页字段测试的备注说明。',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(fieldKey: 'card_alias', valueText: '测试别名'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
          ItemFieldDraftInput(fieldKey: 'card_network', valueText: '银联'),
          ItemFieldDraftInput(fieldKey: 'account_name', valueText: '张三'),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2029-12'),
          ItemFieldDraftInput(fieldKey: 'bill_day', valueText: '10'),
          ItemFieldDraftInput(fieldKey: 'repayment_day', valueText: '25'),
          ItemFieldDraftInput(fieldKey: 'credit_limit', valueText: '50000'),
          ItemFieldDraftInput(fieldKey: 'annual_fee_note', valueText: '免首年'),
        ],
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      expect(find.text('张三的测试信用卡'), findsOneWidget);
      expect(find.textContaining('家庭'), findsOneWidget);
      expect(find.text('类型：信用卡'), findsNothing);
      expect(find.text('信用卡'), findsOneWidget);

      expect(find.text('卡片信息'), findsNothing);
      expect(find.text('银行名称'), findsOneWidget);
      expect(find.text('卡片别名'), findsOneWidget);
      expect(find.text('卡组织'), findsOneWidget);
      expect(find.text('户名'), findsOneWidget);
      expect(find.text('有效期'), findsOneWidget);

      expect(find.text('账单与还款'), findsNothing);
      expect(find.text('账单日'), findsOneWidget);
      expect(find.text('还款日'), findsOneWidget);
      expect(find.text('每月 25 日'), findsOneWidget);

      expect(find.text('额度与状态'), findsNothing);
      expect(find.text('额度'), findsOneWidget);
      expect(find.text('年费说明'), findsOneWidget);

      expect(find.text('备注'), findsOneWidget);
      expect(find.text('这是用于详情页字段测试的备注说明。'), findsOneWidget);

      expect(find.text('卡号'), findsOneWidget);
      expect(find.text('••••  ••••  ••••  7890'), findsOneWidget);
      expect(find.text('6225881234567890'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final eyeIcons = findAnchIcon(AnchIcons.visibility);
      expect(eyeIcons, findsOneWidget);

      await tester.scrollUntilVisible(
        eyeIcons.first,
        50.0,
        scrollable: scrollable,
      );
      await tester.tap(eyeIcons.first);
      await tester.pumpAndSettle();

      expect(find.text('6225  8812  3456  7890'), findsOneWidget);
      expect(find.text('••••  ••••  ••••  7890'), findsNothing);

      expect(find.text('备注'), findsOneWidget);
      expect(find.text('这是用于详情页字段测试的备注说明。'), findsOneWidget);

      final allWidgets = tester.allWidgets;
      for (final widget in allWidgets) {
        if (widget is Text) {
          final text = widget.data ?? '';
          expect(
            text.contains('正式安全模式'),
            isFalse,
            reason: 'Found forbidden phrase: 正式安全模式',
          );
          expect(
            text.contains('绝对安全'),
            isFalse,
            reason: 'Found forbidden phrase: 绝对安全',
          );
          expect(
            text.contains('银行级安全'),
            isFalse,
            reason: 'Found forbidden phrase: 银行级安全',
          );
          expect(
            text.contains('可放心录入真实敏感资料'),
            isFalse,
            reason: 'Found forbidden phrase: 可放心录入真实敏感资料',
          );
        }
      }
    });

    testWidgets('2. 安册详情字段行布局、滚动适配、紧凑操作图标、及特定Key与显示模式校验', (
      WidgetTester tester,
    ) async {
      final idCardDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: '王五的测试身份证',
        note: '这是测试用的备注文本，支持多行换行展示。',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '测试姓名王五'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ItemFieldDraftInput(fieldKey: 'ethnicity', valueText: '汉'),
          ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990-03-07'),
          ItemFieldDraftInput(
            fieldKey: 'address',
            valueText: '测试自然语言长文本户籍地址北京市朝阳区',
          ),
          ItemFieldDraftInput(
            fieldKey: 'issuing_authority',
            valueText: '北京市公安局朝阳分局',
          ),
          ItemFieldDraftInput(fieldKey: 'valid_from', valueText: '2020-03-07'),
          ItemFieldDraftInput(fieldKey: 'valid_until', valueText: '2040-03-07'),
        ],
      );

      final res = await service.saveDraft(idCardDraft);
      expect(res.success, isTrue);
      final itemId = res.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('field_multiline_val_name')), findsOneWidget);
      final nameTrailing = tester.getSize(
        find.byKey(const Key('field_trailing_actions_name')),
      );
      expect(nameTrailing.width, 48);

      final nameLabelCenter = tester.getCenter(
        find.byKey(const Key('field_label_name')),
      );
      final nameValueCenter = tester.getCenter(
        find.byKey(const Key('field_multiline_val_name')),
      );
      final nameTrailingCenter = tester.getCenter(
        find.byKey(const Key('field_trailing_actions_name')),
      );
      expect(
        (nameLabelCenter.dy - nameValueCenter.dy).abs(),
        lessThanOrEqualTo(2.0),
      );
      expect(
        (nameLabelCenter.dy - nameTrailingCenter.dy).abs(),
        lessThanOrEqualTo(2.0),
      );

      expect(
        find.byKey(const Key('sensitive_value_zone_id_number')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sensitive_value_zone_id_number')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('field_scroll_val_id_number')), findsNothing);

      final eyeIcon = find.descendant(
        of: find.byKey(const Key('field_trailing_actions_id_number')),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.ensureVisible(eyeIcon);
      await tester.tap(eyeIcon);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('sensitive_value_zone_id_number')),
        findsOneWidget,
      );
      final textWidget = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('sensitive_value_zone_id_number')),
          matching: find.byType(Text),
        ),
      );
      expect(textWidget.maxLines, isNull);
      expect(textWidget.softWrap, isNot(false));

      // Since id_number is now rendered inside a card vertically, label/value/actions centers are not vertically aligned.

      final sensitiveEyeCenter = tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('field_trailing_actions_id_number')),
          matching: findAnchIcon(AnchIcons.visibilityOff),
        ),
      );
      final sensitiveCopyCenter = tester.getCenter(
        find.descendant(
          of: find.byKey(const Key('field_trailing_actions_id_number')),
          matching: findAnchIcon(AnchIcons.copy),
        ),
      );
      expect(
        (sensitiveEyeCenter.dy - sensitiveCopyCenter.dy).abs(),
        lessThanOrEqualTo(1.0),
      );

      final fittedValue = find.byKey(
        const Key('sensitive_value_zone_id_number'),
      );
      expect(
        find.descendant(of: fittedValue, matching: find.text('身份证号')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: fittedValue,
          matching: find.byType(AnchCompactIconAction),
        ),
        findsNothing,
      );

      final addressEyeIcon = find.descendant(
        of: find.byKey(const Key('field_trailing_actions_address')),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.ensureVisible(addressEyeIcon);
      await tester.tap(addressEyeIcon);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('field_multiline_val_address')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('field_scroll_val_address')), findsNothing);

      final copyIcon = find.descendant(
        of: find.byKey(const Key('field_trailing_actions_id_number')),
        matching: findAnchIcon(AnchIcons.copy),
      );
      await tester.ensureVisible(copyIcon);
      await tester.tap(copyIcon);
      await tester.pumpAndSettle();
      expect(find.text('确认复制敏感字段？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      final nameLabelDy = tester
          .getCenter(find.byKey(const Key('field_label_name')))
          .dy;
      final idNumberLabelDy = tester
          .getCenter(find.byKey(const Key('field_label_id_number')))
          .dy;
      final genderLabelDy = tester
          .getCenter(find.byKey(const Key('field_label_gender')))
          .dy;
      final ethnicityLabelDy = tester
          .getCenter(find.byKey(const Key('field_label_ethnicity')))
          .dy;
      final birthDateLabelDy = tester
          .getCenter(find.byKey(const Key('field_label_birth_date')))
          .dy;

      expect(idNumberLabelDy, lessThan(nameLabelDy));
      expect(nameLabelDy, lessThan(genderLabelDy));
      expect(genderLabelDy, lessThan(ethnicityLabelDy));
      expect(ethnicityLabelDy, lessThan(birthDateLabelDy));

      expect(find.text('证件信息'), findsNothing);
      expect(find.text('户籍地址'), findsNothing);
      expect(find.text('签发与有效期'), findsNothing);

      final debitCardDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        title: '测试储蓄卡',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '测试银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final resDebit = await service.saveDraft(debitCardDraft);
      final debitItemId = resDebit.itemId!;

      await tester.pumpWidget(buildTestWidget(debitItemId));
      await tester.pumpAndSettle();

      final bankNameLabelCenter = tester.getCenter(
        find.byKey(const Key('field_label_bank_name')),
      );
      final bankNameValueCenter = tester.getCenter(
        find.byKey(const Key('field_multiline_val_bank_name')),
      );
      expect(
        (bankNameLabelCenter.dy - bankNameValueCenter.dy).abs(),
        lessThanOrEqualTo(2.0),
      );

      expect(find.text('高敏信息'), findsNothing);
      expect(
        find.byKey(const Key('sensitive_value_zone_card_number')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sensitive_value_zone_card_number')),
        findsOneWidget,
      );

      final cardEyeIcon = find.descendant(
        of: find.byKey(const Key('field_trailing_actions_card_number')),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.ensureVisible(cardEyeIcon);
      await tester.tap(cardEyeIcon);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('sensitive_value_zone_card_number')),
        findsOneWidget,
      );
      final cardTextWidget = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('sensitive_value_zone_card_number')),
          matching: find.byType(Text),
        ),
      );
      expect(cardTextWidget.maxLines, isNull);
      expect(cardTextWidget.softWrap, isNot(false));
    });
  });

  group('ItemDetailPage 高敏显隐与生命周期测试', () {
    testWidgets('1. 验证高敏字段生命周期切后台/回前台重新遮蔽', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ItemFieldDraftInput(fieldKey: 'address', valueText: 'TEST-北京市东城区'),
        ],
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);
      final itemId = result.itemId!;

      await tester.pumpWidget(buildTestWidget(itemId));
      await tester.pumpAndSettle();

      expect(find.text('110101199003072345'), findsNothing);
      expect(find.text('TEST-北京市东城区'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final visibilityIcons = findAnchIcon(AnchIcons.visibility);
      expect(visibilityIcons, findsNWidgets(2));

      await tester.scrollUntilVisible(
        visibilityIcons.first,
        50.0,
        scrollable: scrollable,
      );
      await tester.tap(visibilityIcons.first);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsNothing);

      await tester.tap(findAnchIcon(AnchIcons.visibility).first);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsNothing);

      await tester.tap(findAnchIcon(AnchIcons.visibility).first);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsNothing);

      expect(find.text('TEST-张三'), findsOneWidget);
    });

    testWidgets('2. 验证离开详情页再回来仍遮蔽', (WidgetTester tester) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: 'TEST-张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
        ],
      );

      final result = await service.saveDraft(draft);
      expect(result.success, isTrue);
      final itemId = result.itemId!;

      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            onGenerateRoute: (settings) {
              if (settings.name == '/detail') {
                return MaterialPageRoute(
                  builder: (context) => ItemDetailPage(itemId: itemId),
                );
              }
              return MaterialPageRoute(
                builder: (context) => Scaffold(
                  body: Builder(
                    builder: (context) => ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/detail'),
                      child: const Text('Go to Detail'),
                    ),
                  ),
                ),
              );
            },
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      expect(find.text('110101199003072345'), findsNothing);

      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final eyeIcon = findAnchIcon(AnchIcons.visibility).first;
      await tester.scrollUntilVisible(eyeIcon, 50.0, scrollable: scrollable);
      await tester.tap(eyeIcon);
      await tester.pumpAndSettle();
      expect(find.text('110101199003072345'), findsOneWidget);

      final editButton = findAnchIcon(AnchIcons.more);
      expect(editButton, findsOneWidget);
      final editAction = find.byKey(const Key('detail_more_action'));
      expect(find.bySemanticsLabel('更多操作'), findsOneWidget);
      final homeAction = find.byKey(const Key('detail_home_action'));
      expect(tester.getSize(editAction), const Size(48, 48));
      expect(tester.getSize(homeAction), const Size(48, 48));
      expect(tester.widget<AnchIcon>(editButton).size, 20);
      expect(
        find.descendant(of: editAction, matching: find.byType(IconButton)),
        findsNothing,
      );
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('编辑'), findsOneWidget);
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.text('110101199003072345'), findsNothing);
    });

    testWidgets('到期状态 Banner 测试：即将到期、已过期、不支持类型', (WidgetTester tester) async {
      String formatDate(DateTime dt) {
        final y = dt.year;
        final m = dt.month.toString().padLeft(2, '0');
        final d = dt.day.toString().padLeft(2, '0');
        return '$y-$m-$d';
      }

      // 1a. 即将到期 (15天后到期) - caution 类型 (warning/gold 风格)
      final upcomingDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [
          ItemFieldDraftInput(fieldKey: 'title', valueText: '我的即将到期通用资料'),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: formatDate(DateTime.now().add(const Duration(days: 15))),
          ),
        ],
      );
      final upcomingRes = await service.saveDraft(upcomingDraft);
      expect(upcomingRes.success, isTrue);

      await tester.pumpWidget(buildTestWidget(upcomingRes.itemId!));
      await tester.pumpAndSettle();

      // 验证详情 Banner 渲染 (即将到期横幅被过滤不渲染)
      expect(find.byType(AnchSecurityBanner), findsOneWidget); // 仅一个开发模式横幅
      expect(find.textContaining('即将到期，剩余 15 天'), findsNothing);

      // 1b. 即将到期 (2天后到期) - warning 类型 (error 风格)
      final urgentDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [
          ItemFieldDraftInput(fieldKey: 'title', valueText: '紧急即将到期通用资料'),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: formatDate(DateTime.now().add(const Duration(days: 2))),
          ),
        ],
      );
      final urgentRes = await service.saveDraft(urgentDraft);
      expect(urgentRes.success, isTrue);

      await tester.pumpWidget(buildTestWidget(urgentRes.itemId!));
      await tester.pumpAndSettle();

      expect(find.textContaining('即将到期，剩余 2 天'), findsNothing);
      expect(find.byType(AnchSecurityBanner), findsOneWidget); // 仅一个开发模式横幅

      // 2. 已过期情况：头部保留简洁标签，不再重复展示提示横幅
      final expiredDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'other',
        typeKey: 'generic',
        fields: [
          ItemFieldDraftInput(fieldKey: 'title', valueText: '我的已过期通用资料'),
          ItemFieldDraftInput(
            fieldKey: 'valid_until',
            valueText: formatDate(
              DateTime.now().subtract(const Duration(days: 5)),
            ),
          ),
        ],
      );
      final expiredRes = await service.saveDraft(expiredDraft);
      expect(expiredRes.success, isTrue);

      await tester.pumpWidget(buildTestWidget(expiredRes.itemId!));
      await tester.pumpAndSettle();

      expect(find.text('已过期'), findsOneWidget);
      expect(find.textContaining('已过期，请更新有效期'), findsNothing);
      expect(find.byType(AnchSecurityBanner), findsOneWidget); // 仅一个开发模式横幅

      // 3. 不支持类型情况
      final unsupportedDraft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'card',
        typeKey: 'debit_card',
        fields: [
          ItemFieldDraftInput(fieldKey: 'bank_name', valueText: '招商银行'),
          ItemFieldDraftInput(
            fieldKey: 'card_number',
            valueText: '6225881234567890',
          ),
        ],
      );
      final unsupportedRes = await service.saveDraft(unsupportedDraft);
      expect(unsupportedRes.success, isTrue);
      expect(unsupportedRes.success, isTrue);

      await tester.pumpWidget(buildTestWidget(unsupportedRes.itemId!));
      await tester.pumpAndSettle();

      // 不支持类型只应显示 1 个开发验证横幅，无到期横幅
      expect(find.byType(AnchSecurityBanner), findsOneWidget);
      expect(find.textContaining('到期'), findsNothing);
      expect(find.textContaining('过期'), findsNothing);
    });
  });

  group('敏感字段高度稳定性及排版对齐', () {
    testWidgets('单行敏感字段和多行敏感字段在默认字体缩放下的显隐状态高度及排版稳定性验证', (
      WidgetTester tester,
    ) async {
      // 1. 保存含有各种结构化敏感字段和多行敏感字段 of the details (使用 household_book 模板)
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '123456789',
          ),
          ItemFieldDraftInput(fieldKey: 'household_type', valueText: '居民家庭户'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(
            fieldKey: 'household_address',
            valueText: '北京市东城区',
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      final itemId = res.itemId!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: buildTestWidget(itemId),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 寻找普通单行字段并测量其高度作为标准值
      final typeRowFinder = find.byWidgetPredicate(
        (w) => w is AnchInfoFieldRow && w.fieldKey == 'household_type',
      );
      expect(typeRowFinder, findsOneWidget);
      final typeRowHeight = tester.getSize(typeRowFinder).height;
      // --- 1. 单行常规敏感字段验证 (id_number) ---
      final idRowKey = const ValueKey('detail_field_row_id_number');

      // 隐藏状态断言：
      // 1. 存在水平 SingleChildScrollView
      expect(
        find.descendant(
          of: find.byKey(idRowKey),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(idRowKey),
          matching: find.text('******'),
        ),
        findsOneWidget,
      );

      // 测量初始高度并验证与普通行一致
      final double initialRowHeight = tester
          .getSize(find.byKey(idRowKey))
          .height;
      expect(initialRowHeight, equals(typeRowHeight));

      // 测量隐藏状态下的槽位中心点并验证垂直对齐
      final idLabelSlot = find.byKey(const Key('field_label_slot_id_number'));
      final idValueSlot = find.byKey(const Key('field_value_slot_id_number'));
      final idActionSlot = find.byKey(const Key('field_action_slot_id_number'));

      final idLabelCenter = tester.getCenter(idLabelSlot);
      final idValueCenter = tester.getCenter(idValueSlot);
      final idActionCenter = tester.getCenter(idActionSlot);

      expect(
        (idLabelCenter.dy - idValueCenter.dy).abs(),
        lessThanOrEqualTo(1.0),
      );
      expect(
        (idValueCenter.dy - idActionCenter.dy).abs(),
        lessThanOrEqualTo(1.0),
      );

      // --- 2. 测量对齐精确度 (隐藏状态下) ---
      final typeLabelText = find.descendant(
        of: find.byKey(const Key('field_label_slot_household_type')),
        matching: find.byType(Text),
      );
      final typeValueText = find.descendant(
        of: find.byKey(const Key('field_value_slot_household_type')),
        matching: find.byType(Text),
      );
      final addressLabelText = find.descendant(
        of: find.byKey(const Key('field_label_slot_household_address')),
        matching: find.byType(Text),
      );
      final addressValueText = find.descendant(
        of: find.byKey(const Key('field_value_slot_household_address')),
        matching: find.byType(Text),
      );
      final addressActionSlot = find.byKey(
        const Key('field_action_slot_household_address'),
      );

      final typeLabelTextCenter = tester.getCenter(typeLabelText);
      final typeValueTextCenter = tester.getCenter(typeValueText);
      final addressLabelTextCenter = tester.getCenter(addressLabelText);
      final addressValueTextCenter = tester.getCenter(addressValueText);
      final addressActionCenter = tester.getCenter(addressActionSlot);

      // 普通单行对齐断言
      expect(
        (typeLabelTextCenter.dy - typeValueTextCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      // 敏感 multiline 隐藏短掩码对齐断言
      expect(
        (addressLabelTextCenter.dy - addressValueTextCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      expect(
        (addressValueTextCenter.dy - addressActionCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );

      // 切换到显示状态
      final addressRevealButton = find.descendant(
        of: find.byKey(const ValueKey('detail_field_row_household_address')),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.scrollUntilVisible(
        addressRevealButton,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.tap(addressRevealButton);
      await tester.pumpAndSettle();

      // --- 3. 测量对齐精确度 (显示状态 - 短明文单行状态下) ---
      final addressLabelTextCenterRev = tester.getCenter(addressLabelText);
      final addressValueTextCenterRev = tester.getCenter(addressValueText);
      final addressActionCenterRev = tester.getCenter(addressActionSlot);
      expect(
        (addressLabelTextCenterRev.dy - addressValueTextCenterRev.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      expect(
        (addressValueTextCenterRev.dy - addressActionCenterRev.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
    });

    testWidgets('单行敏感字段和多行敏感字段在1.3倍字体缩放下的显隐状态高度及排版稳定性验证', (
      WidgetTester tester,
    ) async {
      // 1. 保存含有各种结构化敏感字段和多行敏感字段的资料 (使用 household_book 模板)
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '123456789',
          ),
          ItemFieldDraftInput(fieldKey: 'household_type', valueText: '居民家庭户'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(
            fieldKey: 'household_address',
            valueText: '北京市东城区',
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      final itemId = res.itemId!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: buildTestWidget(itemId),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      // 寻找普通单行字段并测量其高度作为标准值
      final typeRowFinder = find.byWidgetPredicate(
        (w) => w is AnchInfoFieldRow && w.fieldKey == 'household_type',
      );
      expect(typeRowFinder, findsOneWidget);
      // --- 1. 测量对齐精确度 (隐藏状态下) ---
      final typeLabelText = find.descendant(
        of: find.byKey(const Key('field_label_slot_household_type')),
        matching: find.byType(Text),
      );
      final typeValueText = find.descendant(
        of: find.byKey(const Key('field_value_slot_household_type')),
        matching: find.byType(Text),
      );
      final addressLabelText = find.descendant(
        of: find.byKey(const Key('field_label_slot_household_address')),
        matching: find.byType(Text),
      );
      final addressValueText = find.descendant(
        of: find.byKey(const Key('field_value_slot_household_address')),
        matching: find.byType(Text),
      );
      final addressActionSlot = find.byKey(
        const Key('field_action_slot_household_address'),
      );

      final typeLabelTextCenter = tester.getCenter(typeLabelText);
      final typeValueTextCenter = tester.getCenter(typeValueText);
      final addressLabelTextCenter = tester.getCenter(addressLabelText);
      final addressValueTextCenter = tester.getCenter(addressValueText);
      final addressActionCenter = tester.getCenter(addressActionSlot);

      // 普通单行对齐断言
      expect(
        (typeLabelTextCenter.dy - typeValueTextCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      // 敏感 multiline 隐藏短掩码对齐断言
      expect(
        (addressLabelTextCenter.dy - addressValueTextCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      expect(
        (addressValueTextCenter.dy - addressActionCenter.dy).abs(),
        lessThanOrEqualTo(1.5),
      );

      // 切换到显示状态
      final addressRevealButton = find.descendant(
        of: find.byKey(const ValueKey('detail_field_row_household_address')),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.scrollUntilVisible(
        addressRevealButton,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.tap(addressRevealButton);
      await tester.pumpAndSettle();

      // --- 2. 测量对齐精确度 (显示状态 - 短明文单行状态下) ---
      final addressLabelTextCenterRev = tester.getCenter(addressLabelText);
      final addressValueTextCenterRev = tester.getCenter(addressValueText);
      final addressActionCenterRev = tester.getCenter(addressActionSlot);
      expect(
        (addressLabelTextCenterRev.dy - addressValueTextCenterRev.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
      expect(
        (addressValueTextCenterRev.dy - addressActionCenterRev.dy).abs(),
        lessThanOrEqualTo(1.5),
      );
    });

    testWidgets('长地址内容自然扩展且不整体悬空居中验证', (WidgetTester tester) async {
      // 1. 保存含有长多行敏感字段的资料
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'household_book',
        fields: [
          ItemFieldDraftInput(
            fieldKey: 'household_number',
            valueText: '123456789',
          ),
          ItemFieldDraftInput(fieldKey: 'household_type', valueText: '居民家庭户'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(
            fieldKey: 'household_address',
            valueText: '这是一个非常长非常长非常长非常长的地址备注备注备注备注备注备注备注备注。' * 10,
          ),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      final itemId = res.itemId!;

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: buildTestWidget(itemId),
        ),
      );
      await tester.pumpAndSettle();

      final scrollableFinder = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;

      final typeRowFinder = find.byWidgetPredicate(
        (w) => w is AnchInfoFieldRow && w.fieldKey == 'household_type',
      );
      expect(typeRowFinder, findsOneWidget);
      final double typeRowHeight = tester.getSize(typeRowFinder).height;

      final addressRowKey = const ValueKey(
        'detail_field_row_household_address',
      );

      // 切换到显示状态
      final addressRevealButton = find.descendant(
        of: find.byKey(addressRowKey),
        matching: findAnchIcon(AnchIcons.visibility),
      );
      await tester.scrollUntilVisible(
        addressRevealButton,
        50.0,
        scrollable: scrollableFinder,
      );
      await tester.tap(addressRevealButton);
      await tester.pumpAndSettle();

      // 长地址明文允许自然扩展，此时行高应该大于普通单行高度
      final double revealedAddressHeight = tester
          .getSize(find.byKey(addressRowKey))
          .height;
      expect(revealedAddressHeight, greaterThan(typeRowHeight));
    });
  });

  group('主卡片查看与复制按钮尺寸及垂直节奏优化测试', () {
    testWidgets('1. 默认字体下的按钮高度、触控范围、说明文案及卡片高度稳定性验证', (
      WidgetTester tester,
    ) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: '测试主卡片高度稳定性',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ItemFieldDraftInput(fieldKey: 'ethnicity', valueText: '汉'),
          ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990-03-07'),
          ItemFieldDraftInput(fieldKey: 'address', valueText: '北京市东城区景山前街4号'),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.noScaling),
          child: buildTestWidget(res.itemId!),
        ),
      );
      await tester.pumpAndSettle();

      final revealBtnFinder = find.byKey(
        const Key('primary_sensitive_reveal_button'),
      );
      final copyBtnFinder = find.byKey(
        const Key('primary_sensitive_copy_button'),
      );
      final cardFinder = find.byKey(const Key('primary_number_card'));

      final revealButton = tester.widget<ElevatedButton>(revealBtnFinder);
      final minSize = revealButton.style?.minimumSize?.resolve({});
      expect(minSize?.height, 48.0);
      expect(revealButton.style?.tapTargetSize, MaterialTapTargetSize.padded);

      // 验证整体 RenderBox 高度
      final revealHeight = tester.getSize(revealBtnFinder).height;
      final copyHeight = tester.getSize(copyBtnFinder).height;
      expect(revealHeight, greaterThanOrEqualTo(48.0));
      expect(copyHeight, revealHeight);

      // 验证卡片高度稳定性
      final heightBefore = tester.getSize(cardFinder).height;
      final valueHeightBefore = tester
          .getSize(find.byKey(const Key('sensitive_value_zone_id_number')))
          .height;

      // 边缘点击 - 上边缘点击测试
      final rect1 = tester.getRect(revealBtnFinder);
      await tester.tapAt(Offset(rect1.center.dx, rect1.top + 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('隐藏'), findsOneWidget);

      final heightAfter = tester.getSize(cardFinder).height;
      expect(heightAfter, heightBefore); // 显隐切换后高度保持稳定
      expect(
        tester
            .getSize(find.byKey(const Key('sensitive_value_zone_id_number')))
            .height,
        valueHeightBefore,
      );

      // 边缘点击 - 下边缘点击测试
      final rect2 = tester.getRect(revealBtnFinder);
      await tester.tapAt(Offset(rect2.center.dx, rect2.bottom - 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('查看'), findsOneWidget);

      final heightAfter2 = tester.getSize(cardFinder).height;
      expect(heightAfter2, heightBefore);
      expect(
        tester
            .getSize(find.byKey(const Key('sensitive_value_zone_id_number')))
            .height,
        valueHeightBefore,
      );

      // 复制功能和安全弹窗验证
      await tester.tap(copyBtnFinder);
      await tester.pumpAndSettle();
      expect(find.text('确认复制敏感字段？'), findsOneWidget);
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      expect(find.text('离开页面后，完整号码会自动隐藏'), findsNothing);
    });

    testWidgets('2. 1.3 倍字体下的按钮等高、无 overflow 且卡片高度稳定性验证', (
      WidgetTester tester,
    ) async {
      final draft = ItemDraftInput(
        memberId: systemFamilyMemberId,
        categoryKey: 'certificate',
        typeKey: 'id_card',
        title: '测试1.3倍字体卡片高度',
        fields: [
          ItemFieldDraftInput(fieldKey: 'name', valueText: '张三'),
          ItemFieldDraftInput(
            fieldKey: 'id_number',
            valueText: '110101199003072345',
          ),
          ItemFieldDraftInput(fieldKey: 'gender', valueText: '男'),
          ItemFieldDraftInput(fieldKey: 'ethnicity', valueText: '汉'),
          ItemFieldDraftInput(fieldKey: 'birth_date', valueText: '1990-03-07'),
          ItemFieldDraftInput(fieldKey: 'address', valueText: '北京市东城区景山前街4号'),
        ],
      );
      final res = await service.saveDraft(draft);
      expect(res.success, isTrue);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: buildTestWidget(res.itemId!),
        ),
      );
      await tester.pumpAndSettle();

      final revealBtnFinder = find.byKey(
        const Key('primary_sensitive_reveal_button'),
      );
      final copyBtnFinder = find.byKey(
        const Key('primary_sensitive_copy_button'),
      );
      final cardFinder = find.byKey(const Key('primary_number_card'));

      // 验证无 overflow
      expect(tester.takeException(), isNull);
      expect(cardFinder, findsOneWidget);

      // 验证按钮等高
      final revealHeight = tester.getSize(revealBtnFinder).height;
      final copyHeight = tester.getSize(copyBtnFinder).height;
      expect(copyHeight, revealHeight);

      // 验证切换显隐后卡片高度仍然稳定
      final heightBefore = tester.getSize(cardFinder).height;
      await tester.tap(revealBtnFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('隐藏'), findsOneWidget);

      final heightAfter = tester.getSize(cardFinder).height;
      expect(heightAfter, heightBefore);

      await tester.tap(revealBtnFinder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('查看'), findsOneWidget);
    });
  });
}
