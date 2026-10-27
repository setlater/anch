import 'package:anch/core/theme/anch_icons.dart';
import '../support/anch_icon_finder.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/core/backup/backup_history_manager.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/core/widgets/anch_route_back.dart';
import 'package:anch/features/mine/mine_page.dart';
import 'package:anch/features/mine/data_management_page.dart';
import 'package:anch/features/backup/export_backup_password_page.dart';
import 'package:anch/features/backup/restore_backup_password_page.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/features/all_items/all_items_page.dart';
import 'package:anch/features/mine/recently_deleted_page.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;
  var streamingWrittenBytes = 0;

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
      backupHistoryManager: BackupHistoryManager(MemorySecureKeyValueStore()),
      child: const SizedBox.shrink(),
    );
    db = di.db;
    streamingWrittenBytes = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('anch/backup_stream_v2'),
          (MethodCall methodCall) async {
            switch (methodCall.method) {
              case 'beginStreamingBackupDocument':
                return <Object?, Object?>{'success': true};
              case 'writeStreamingBackupChunk':
                final bytes = methodCall.arguments['bytes'] as Uint8List;
                streamingWrittenBytes += bytes.length;
                return <Object?, Object?>{'success': true};
              case 'finishStreamingBackupDocument':
                return <Object?, Object?>{
                  'success': true,
                  'savedAt': 1718035200000,
                  'sizeBytes': streamingWrittenBytes,
                };
              case 'abortStreamingBackupDocument':
                return null;
            }
            return null;
          },
        );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('anch/backup_file_read'), (
          MethodCall methodCall,
        ) async {
          if (methodCall.method == 'openBackupDocumentAndRead') {
            return <Object?, Object?>{
              'success': true,
              'bytes': Uint8List.fromList(
                utf8.encode(
                  '{"magic":"ANCH_BACKUP","version":1,"createdAt":1718035200000,'
                  '"payloadFormat":"anch.backup.payload","payloadVersion":1,'
                  '"kdf":{"name":"pbkdf2","iterations":1000,"salt":"c2FsdA==","keyLength":32},'
                  '"cipher":{"name":"aes-gcm","nonce":"bm9uY2U=","tagLength":16},'
                  '"ciphertext":"Y2lwaGVydGV4dA==","mac":"bWFj"}',
                ),
              ),
              'readAt': 1718035200000,
            };
          }
          return null;
        });
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('anch/backup_file_read'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('anch/backup_stream_v2'),
          null,
        );
  });

  Widget buildTestApp(Widget child, {ThemeData? theme, double textScale = 1}) {
    return wrapTest(
      MaterialApp(
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: child,
      ),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  testWidgets('资料管理与备份在三档宽度、亮暗主题和大字号下保留可滚动操作', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final width in [320.0, 600.0, 1000.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      for (final theme in [AnchTheme.light, AnchTheme.dark]) {
        for (final page in <Widget>[
          const DataManagementPage(),
          const ExportBackupPasswordPage(),
          const AllItemsPage(),
          const RecentlyDeletedPage(),
        ]) {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(
            buildTestApp(page, theme: theme, textScale: 2),
          );
          await tester.pumpAndSettle();
          if (page is DataManagementPage) {
            final export = find.text('导出加密备份');
            await tester.ensureVisible(export);
            final text = tester.widget<Text>(export);
            expect(
              text.style?.color,
              tester.element(export).anchColors.accentInk,
            );
            final status = find.text('尚未创建备份');
            expect(
              tester.widget<Text>(status).style?.color,
              tester.element(status).anchColors.textSecondary,
            );
            await tester.scrollUntilVisible(find.text('删除本机资料'), 150);
          } else if (page is ExportBackupPasswordPage) {
            await tester.ensureVisible(find.text('继续导出'));
          } else if (page is AllItemsPage) {
            expect(find.text('全部资料'), findsOneWidget);
            expect(
              find.descendant(
                of: find.byType(AppBar),
                matching: find.text('0 条'),
              ),
              findsOneWidget,
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType}, $width',
          );
        }
      }
    }
  });

  group('安册备份恢复页面测试', () {
    testWidgets('1. 验证“我的页”数据与备份入口及点击跳转，且具有 InkWell 反馈样式', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const MinePage()));
      await tester.pumpAndSettle();

      // 向下拖动 ListView 使下方的数据与备份入口呈现并加载
      await tester.drag(find.byType(ListView), const Offset(0, -350));
      await tester.pumpAndSettle();

      // 验证入口名称及副标题文案
      expect(find.text('数据与备份'), findsOneWidget);
      expect(find.text('备份、恢复或删除本机资料'), findsOneWidget);

      // 验证通过 InkWell 包裹
      final inkWellFinder = find.descendant(
        of: find.byType(MinePage),
        matching: find.byType(InkWell),
      );
      expect(inkWellFinder, findsWidgets);

      // 点击该入口跳转
      await tester.tap(find.text('数据与备份'));
      await tester.pumpAndSettle();

      // 验证跳转进入了数据管理页，并仅展示数量。
      expect(find.byType(DataManagementPage), findsOneWidget);
      expect(find.text('0 条'), findsOneWidget);
      expect(find.text('0 个'), findsOneWidget);
      expect(find.text('导出加密备份'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('删除本机资料'), 100);
      expect(find.text('删除本机资料'), findsOneWidget);

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.automaticallyImplyLeading, isFalse);
      expect(appBar.leadingWidth, 48);
      expect(appBar.titleSpacing, 0);
      expect(appBar.leading, isA<AnchRouteBack>());
    });

    testWidgets('2. 按指定层级展示说明、操作卡和未备份状态', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      expect(find.text(AnchSecurityBanner.devModeMessage), findsOneWidget);
      expect(find.text('备份文件经过加密，只能使用创建时设置的密码恢复。安册不会上传或找回密码。'), findsOneWidget);
      expect(find.text('导出加密备份'), findsOneWidget);
      expect(find.text('创建备份，包含当前资料和附件'), findsOneWidget);
      expect(find.text('导出加密备份'), findsOneWidget);
      expect(find.text('从备份恢复'), findsOneWidget);
      expect(find.text('恢复备份前验证文件与密码，再确认覆盖范围'), findsOneWidget);
      expect(find.text('从备份恢复'), findsOneWidget);
      expect(findAnchIcon(AnchIcons.download), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('backup_status_empty')),
      );
      expect(find.text('尚未创建备份'), findsOneWidget);
      expect(find.byKey(const ValueKey('backup_status_empty')), findsOneWidget);
      expect(find.text('本地手动备份'), findsNothing);
      expect(find.text('数据备份范围'), findsNothing);
      expect(find.text('密钥与密码'), findsNothing);
      expect(find.text('恢复策略'), findsNothing);
      expect(find.textContaining('当前即使启用加密验证模式'), findsNothing);
    });

    testWidgets('3. 读取并展示持久化的上次备份时间和文件名', (WidgetTester tester) async {
      await di.backupHistoryManager.record(
        fileName: 'anch-backup-20260722-120102.abk',
        savedAt: DateTime(2026, 7, 22, 12, 1, 2).millisecondsSinceEpoch,
      );
      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('backup_status_success')),
      );
      expect(find.text('上次备份时间：2026-07-22 12:01:02'), findsOneWidget);
      expect(
        find.text('备份文件名称：anch-backup-20260722-120102.abk'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('backup_status_success')),
        findsOneWidget,
      );
      expect(find.text('尚未创建备份'), findsNothing);
    });

    testWidgets('4. 验证点击“导出备份”和“恢复备份”按钮的占位与跳转逻辑，且能在密码页验证全链路假保存成功', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      // 向下拖拽到底部，使操作按钮完全呈现在可视范围内

      await tester.pumpAndSettle();

      // A. 测试导出按钮跳转至密码设置原型页
      await tester.ensureVisible(find.text('导出加密备份'));
      await tester.tap(find.text('导出加密备份'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);

      // 录入合法密码并执行导出
      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);
      await tester.enterText(passwordInput, 'validpassword123');
      await tester.enterText(confirmInput, 'validpassword123');

      await tester.tap(find.text('继续导出'));
      // 等待全流程跑完并弹出 Dialog
      await tester.pumpAndSettle();

      // 验证最终展现了成功反馈 Dialog
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
      expect(find.textContaining('位置: 系统选择的位置'), findsNothing);

      // 关闭弹窗并验证已自动返回前页
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportBackupPasswordPage), findsNothing);
      expect(find.byType(DataManagementPage), findsOneWidget);
      expect(find.textContaining('上次备份时间：'), findsOneWidget);
      expect(find.textContaining('备份文件名称：anch-'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('0 条'), -100);
      expect(find.text('0 个'), findsOneWidget);
      expect(find.text('读取中'), findsNothing);

      // 再次向下拉动露出操作按钮

      await tester.pumpAndSettle();

      // B. 测试恢复按钮跳转至 RestoreBackupPasswordPage 原型页
      await tester.ensureVisible(find.text('从备份恢复'));
      await tester.tap(find.text('从备份恢复'));
      await tester.pumpAndSettle();

      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
      expect(find.text('尚未选择备份文件'), findsOneWidget);
      expect(find.text('选择文件'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);

      // 返回前一页
      await tester.tap(
        find.descendant(
          of: find.byType(RestoreBackupPasswordPage),
          matching: findAnchIcon(AnchIcons.back),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DataManagementPage), findsOneWidget);
    });

    testWidgets('5. 重点断言：验证测试中绝对没有误导或暗示功能已启用的已完成状态文案', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      // 绝对不能包含已启用的状态文案
      expect(find.textContaining('导出成功'), findsNothing);
      expect(find.textContaining('恢复成功'), findsNothing);
      expect(find.textContaining('备份已保存'), findsNothing);
      expect(find.textContaining('已读取'), findsNothing);
      expect(find.textContaining('正在选择文件'), findsNothing);
    });

    testWidgets('6. 验证在系统选择器弹出后用户取消，返回 App 后弹出对应失败 Dialog 且仍停留在密码页', (
      WidgetTester tester,
    ) async {
      // 临时覆盖 MockMethodCallHandler 使得抛出 userCancelled
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('anch/backup_stream_v2'),
            (MethodCall methodCall) async {
              if (methodCall.method == 'beginStreamingBackupDocument') {
                throw PlatformException(
                  code: 'userCancelled',
                  message: '用户取消了导出操作',
                );
              }
              return null;
            },
          );

      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      // 向下拉动以露出按钮

      await tester.pumpAndSettle();

      // 点击“导出备份”
      await tester.ensureVisible(find.text('导出加密备份'));
      await tester.tap(find.text('导出加密备份'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);
      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 断言失败 Dialog 出现且包含“导出已取消，未写入备份文件”
      expect(find.text('导出未完成'), findsOneWidget);
      expect(find.textContaining('错误原因：导出已取消，未写入备份文件。'), findsOneWidget);

      // 点击“我知道了”关闭 Dialog
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 断言仍留在 ExportBackupPasswordPage，没有 pop 回去
      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);
      expect(find.text('继续导出'), findsOneWidget);
    });
  });
}
