@Tags(['security'])
library;

import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/features/mine/data_management_page.dart';
import 'package:anch/features/backup/export_backup_password_page.dart';
import 'package:anch/core/widgets/anch_security_banner.dart';
import 'package:anch/core/backup/backup_file_save_service.dart';
import 'package:anch/core/backup/backup_unavailable_attachment.dart';
import 'package:anch/core/backup/backup_history_manager.dart';
import 'package:anch/core/backup/backup_export_progress.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';
import 'package:anch/core/theme/anch_theme.dart';

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
  });

  tearDown(() async {
    await db.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('anch/backup_stream_v2'),
          null,
        );
  });

  Widget buildTestApp(Widget child) {
    return wrapTest(
      MaterialApp(home: child),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('安册导出备份密码设置与校验 UI 原型测试', () {
    testWidgets(
      '1. 验证从备份恢复页点击“导出备份”成功 push 进入 ExportBackupPasswordPage，且显示安全横幅与说明',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp(const DataManagementPage()));
        await tester.pumpAndSettle();

        // 向下拖动 SingleChildScrollView 以暴露出操作按钮

        await tester.pumpAndSettle();

        // 点击“导出备份”按钮
        await tester.ensureVisible(find.text('导出加密备份'));
        await tester.tap(find.text('导出加密备份'));
        await tester.pumpAndSettle();

        // 验证页面成功跳转进入密码输入原型页
        expect(find.byType(ExportBackupPasswordPage), findsOneWidget);

        // 验证开发模式警告横幅
        expect(find.text(AnchSecurityBanner.devModeMessage), findsOneWidget);

        // 验证说明卡片文案
        expect(find.text('备份安全提示'), findsOneWidget);
        expect(find.text('本次备份使用下方密码加密，安册不会保存密码。'), findsOneWidget);
        expect(find.text('忘记密码将无法恢复，请与备份文件分开保存。'), findsOneWidget);
        expect(
          find.textContaining('备份文件不包含本机数据库密钥 databaseKey。'),
          findsNothing,
        );
        expect(find.textContaining('将通过系统文件选择器保存 .abk 文件'), findsNothing);

        final passwordField = find.byType(TextFormField).first;
        final inputDecorator = tester.widget<InputDecorator>(
          find.descendant(
            of: passwordField,
            matching: find.byType(InputDecorator),
          ),
        );
        expect(inputDecorator.decoration.filled, isTrue);
        expect(inputDecorator.decoration.suffixIcon, isA<Semantics>());
        final visibilitySemantics =
            inputDecorator.decoration.suffixIcon! as Semantics;
        final visibilityButton = visibilitySemantics.child! as InkWell;
        expect(visibilityButton.splashFactory, NoSplash.splashFactory);
        expect(
          visibilityButton.overlayColor?.resolve({WidgetState.pressed}),
          Colors.transparent,
        );
        addTearDown(() => tester.binding.setSurfaceSize(null));
        for (final width in [320.0, 600.0, 1000.0]) {
          await tester.binding.setSurfaceSize(Size(width, 1000));
          for (final theme in [AnchTheme.light, AnchTheme.dark]) {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpWidget(
              wrapTest(
                MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const ExportBackupPasswordPage(),
                ),
                runtime,
                (child) => di.copyWith(child: child),
              ),
            );
            await tester.pumpAndSettle();
            final appBar = tester.widget<AppBar>(find.byType(AppBar));
            expect(
              appBar.systemOverlayStyle?.statusBarIconBrightness,
              theme.brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
            );
            await tester.ensureVisible(find.text('至少 8 位'));
            expect(find.text('至少 8 位').hitTestable(), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
      },
    );

    testWidgets('2. 验证密码为空或确认密码为空时的表单强拦截提示', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      // A. 两处均为空，直接点击继续导出
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 验证密码框提示
      expect(find.text('请输入备份密码'), findsOneWidget);

      // B. 输入密码，但确认密码为空
      final passwordInput = find.byType(TextFormField).at(0);

      await tester.enterText(passwordInput, 'validpassword123');
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(find.text('请输入备份密码'), findsNothing);
      expect(find.text('请再次输入备份密码'), findsOneWidget);
    });

    testWidgets('3. 验证密码长度少于 8 位及两次密码输入不一致的强拦截提示', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      // A. 密码长度少于 8 位
      await tester.enterText(passwordInput, 'short');
      await tester.enterText(confirmInput, 'short');
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(find.text('密码长度至少为 8 位'), findsOneWidget);

      // B. 两次密码不一致
      await tester.enterText(passwordInput, 'correctpwd123');
      await tester.enterText(confirmInput, 'differentpwd456');
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(find.text('两次输入的密码不一致'), findsOneWidget);
    });

    testWidgets('4. 验证输入合法一致密码后点击“继续导出”仅显示原型阻断 Dialog，绝不产生误导字样', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      // 录入一致合规密码 (测试中严格不打印密码)
      await tester.enterText(passwordInput, 'mypassword123');
      await tester.enterText(confirmInput, 'mypassword123');

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 验证弹出阻断对话框
      expect(find.text('无法开始导出'), findsOneWidget);
      expect(find.text('当前无法开始导出，请返回后重新进入。'), findsOneWidget);

      // ⚠️ 【安全边界】确保没有出现已生成/已启用的误导文案
      expect(find.textContaining('导出成功'), findsNothing);
      expect(find.textContaining('保存成功'), findsNothing);
      expect(find.textContaining('正在写入'), findsNothing);
      expect(find.textContaining('已生成'), findsNothing);
      expect(find.textContaining('选择保存位置'), findsNothing);

      // 点击我知道了关闭
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('无法开始导出'), findsNothing);
    });

    testWidgets('6. 验证注入成功的 Fake 导出回调时，点击继续导出正确展示正在验证、成功 Dialog 且显示脱敏信息', (
      WidgetTester tester,
    ) async {
      final mockResult = BackupFileSaveResult(
        fileName: 'anch-backup-20260611-153020.abk',
        mimeType: 'application/octet-stream',
        sizeBytes: 2048,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        displayLocation: '开发验证保存器（未写入文件）',
        isSuccess: true,
      );

      bool callbackCalled = false;
      String? receivedPassword;

      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              callbackCalled = true;
              receivedPassword = password;
              // 模拟延迟以验证正在验证文字和按钮禁用
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return mockResult;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'validpassword123');
      await tester.enterText(confirmInput, 'validpassword123');

      // 点击“继续导出”
      await tester.tap(find.text('继续导出'));
      // 开始调用回调，但未完成，此时应该处于 loading 状态，按钮文本显示 "正在验证导出流程..."
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.text('正在验证导出流程...'), findsOneWidget);

      // 等待异步操作完成
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
      expect(receivedPassword, 'validpassword123');

      // 验证弹出成功反馈 Dialog，标题及不含已保存等误导词
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
      expect(
        find.textContaining(
          '安册已通过系统文件选择器写出备份文件。请确认你已经妥善保存 .abk 文件，并单独保管备份密码。安册不会保存你的备份密码。',
        ),
        findsOneWidget,
      );
      expect(find.text('文件名'), findsOneWidget);
      expect(find.text('anch-backup-20260611-153020.abk'), findsOneWidget);
      expect(find.text('大小'), findsOneWidget);
      expect(find.text('2.0 KB'), findsOneWidget);
      expect(find.text('保存位置'), findsOneWidget);
      expect(find.text('开发验证保存器（未写入文件）'), findsOneWidget);

      // ⚠️ 【安全红线】绝不可出现真实写盘成功的诱导词
      expect(find.textContaining('保存成功'), findsNothing);
      expect(find.textContaining('已保存到'), findsNothing);
      expect(find.textContaining('导出成功'), findsNothing);

      // 关闭弹窗
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('导出流程验证完成'), findsNothing);
    });

    testWidgets('成功提示在紧凑、常规与扩展宽度均不裁切关键内容', (WidgetTester tester) async {
      final mockResult = BackupFileSaveResult(
        fileName: 'anch-20260728-133518-very-long-virtual-backup-name.abk',
        mimeType: 'application/octet-stream',
        sizeBytes: 479977265,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        displayLocation: '系统选择的位置',
        isSuccess: true,
      );

      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async =>
                mockResult,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      final exportButton = find.text('继续导出');
      await tester.ensureVisible(exportButton);
      await tester.tap(exportButton);
      await tester.pumpAndSettle();

      expect(find.text(mockResult.fileName), findsOneWidget);
      expect(find.text('大小'), findsOneWidget);
      expect(find.text('457.7 MB'), findsOneWidget);
      final compactDialogSize = tester.getSize(
        find.byKey(const ValueKey('backup_export_success_dialog')),
      );
      final compactActionSize = tester.getSize(
        find.byKey(const ValueKey('backup_export_success_action')),
      );
      expect(compactDialogSize.width, lessThanOrEqualTo(288));
      expect(compactActionSize.width, closeTo(compactDialogSize.width - 48, 1));

      await tester.binding.setSurfaceSize(const Size(600, 800));
      await tester.pumpAndSettle();
      final regularDialogSize = tester.getSize(
        find.byKey(const ValueKey('backup_export_success_dialog')),
      );
      final regularActionSize = tester.getSize(
        find.byKey(const ValueKey('backup_export_success_action')),
      );
      expect(regularDialogSize.width, lessThanOrEqualTo(420));
      expect(regularActionSize.width, lessThan(regularDialogSize.width - 48));

      await tester.binding.setSurfaceSize(const Size(900, 800));
      await tester.pumpAndSettle();
      final extendedDialogSize = tester.getSize(
        find.byKey(const ValueKey('backup_export_success_dialog')),
      );
      expect(extendedDialogSize.width, lessThanOrEqualTo(420));
    });

    testWidgets('7. 验证注入失败的 Fake 导出回调时，点击继续导出弹出失败 Dialog 且进行错误映射脱敏', (
      WidgetTester tester,
    ) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              callbackCalled = true;
              throw BackupFileSaveException(
                BackupFileSaveErrorType.permissionDenied,
                '存储介质拒绝写入。',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'validpassword123');
      await tester.enterText(confirmInput, 'validpassword123');

      // 点击“继续导出”
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);

      // 验证弹出失败 Dialog
      expect(find.text('导出未完成'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsNothing,
      );
      expect(find.textContaining('如保存位置留下文件，请勿将其作为备份使用'), findsOneWidget);

      // 验证错误原因进行了脱敏映射（不含原始 Exception 信息及底层敏感词）
      expect(find.textContaining('错误原因：系统未授予写入权限，导出未完成。'), findsOneWidget);
      expect(find.textContaining('存储介质不可达'), findsNothing);

      // ⚠️ 【安全边界】确保不包含高敏词汇及敏感内容
      final dialogFinder = find.byType(AlertDialog);
      expect(dialogFinder, findsOneWidget);
      final dialogText = tester
          .widget<AlertDialog>(dialogFinder)
          .toString()
          .toLowerCase();
      expect(dialogText, isNot(contains('validpassword123')));
      expect(dialogText, isNot(contains('content://')));
      expect(dialogText, isNot(contains('/sdcard/')));
      expect(dialogText, isNot(contains('/storage/')));

      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('导出未完成'), findsNothing);
    });

    testWidgets('附件不可用时明确提示导出前校验失败且不暴露底层信息', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              throw BackupFileSaveException(
                BackupFileSaveErrorType.sourceUnavailable,
                '底层附件来源不一致。',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(find.textContaining('错误原因：部分附件不可用，未生成备份。'), findsOneWidget);
      expect(find.textContaining('底层附件来源不一致'), findsNothing);
    });

    testWidgets('写入失败时先移除确定进度遮罩，再显示脱敏错误', (tester) async {
      final result = Completer<BackupFileSaveResult>();
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) {
              onProgress(
                const BackupExportProgress(
                  stage: BackupExportProgressStage.writing,
                  fraction: 0.4,
                ),
              );
              return result.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsOneWidget,
      );
      result.completeError(
        BackupFileSaveException(
          BackupFileSaveErrorType.insufficientSpace,
          'virtual output failure',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsNothing,
      );
      expect(find.text('导出未完成'), findsOneWidget);
      expect(find.textContaining('错误原因：存储空间不足，未生成有效备份。'), findsOneWidget);
      expect(find.textContaining('virtual output failure'), findsNothing);
    });

    testWidgets('准备加密时展示加载圈，首写失败明确提示保存位置', (tester) async {
      final result = Completer<BackupFileSaveResult>();
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) {
              onProgress(
                const BackupExportProgress(
                  stage: BackupExportProgressStage.preparing,
                  fraction: 0,
                ),
              );
              return result.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('正在准备加密，请保持应用在前台'), findsOneWidget);

      result.completeError(
        BackupFileSaveException(
          BackupFileSaveErrorType.targetWriteFailed,
          'virtual output failure',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('错误原因：所选保存位置无法开始写入。请重新选择手机本地文件夹后重试。'),
        findsOneWidget,
      );
      expect(find.textContaining('virtual output failure'), findsNothing);
    });

    testWidgets('检查附件时展示真实计数与加载圈而非伪造进度', (tester) async {
      final result = Completer<BackupFileSaveResult>();
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) {
              onProgress(
                const BackupExportProgress(
                  stage: BackupExportProgressStage.checkingAttachments,
                  fraction: 0,
                  completedAttachments: 7,
                  totalAttachments: 46,
                ),
              );
              return result.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('正在检查附件'), findsOneWidget);
      expect(find.text('已检查 7／46 个附件，请保持应用在前台'), findsOneWidget);

      result.completeError(
        BackupFileSaveException(
          BackupFileSaveErrorType.sourceUnavailable,
          'virtual attachment failure',
        ),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('已有文件操作时提示返回后重试，不展示底层异常', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              throw BackupFileSaveException(
                BackupFileSaveErrorType.operationInProgress,
                'virtual output failure',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('错误原因：上一次文件操作尚未结束。请返回数据与备份页后再试。'),
        findsOneWidget,
      );
      expect(find.textContaining('virtual output failure'), findsNothing);
    });

    testWidgets('系统写入中断时给出可重试的脱敏提示', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              throw BackupFileSaveException(
                BackupFileSaveErrorType.writeInterrupted,
                'virtual output failure',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('错误原因：系统保存写入被中断，未生成有效备份。请重新选择保存位置后重试。'),
        findsOneWidget,
      );
      expect(find.textContaining('virtual output failure'), findsNothing);
    });

    testWidgets('容量估算期间禁止重复提交，超过已验证容量须确认后才导出', (WidgetTester tester) async {
      var exportCalled = false;
      var estimateCalls = 0;
      final estimatedBytes = Completer<int>();
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onEstimateOutputForTestOrPrototype: () {
              estimateCalls++;
              return estimatedBytes.future;
            },
            onExportForTestOrPrototype: (password, onProgress) async {
              exportCalled = true;
              return BackupFileSaveResult(
                fileName: 'anch-backup-20260611-153020.abk',
                mimeType: 'application/octet-stream',
                sizeBytes: 1024,
                savedAt: 1,
                displayLocation: '开发验证',
                isSuccess: true,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(estimateCalls, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsNothing,
      );
      estimatedBytes.complete(240 * 1024 * 1024 + 1);
      await tester.pumpAndSettle();

      expect(find.text('备份较大'), findsOneWidget);
      expect(find.textContaining('导出可能耗时较长'), findsOneWidget);
      expect(find.textContaining('240 MiB'), findsNothing);
      expect(exportCalled, isFalse);

      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.text('备份较大'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller
            ?.text,
        'validpassword123',
      );
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(1))
            .controller
            ?.text,
        'validpassword123',
      );
      expect(exportCalled, isFalse);

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续导出').last);
      await tester.pumpAndSettle();

      expect(exportCalled, isTrue);
      expect(estimateCalls, 2);
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
    });

    testWidgets('附件不可用时按资料和原因分组展示', (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(320, 800));
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              throw BackupFileSaveException(
                BackupFileSaveErrorType.sourceUnavailable,
                '底层附件来源不一致。',
                unavailableAttachments: const [
                  BackupUnavailableAttachment(
                    itemId: 'test-card',
                    itemTitle: 'TEST-CARD-TITLE',
                    originalName: 'TEST-EXPIRED-ATTACHMENT.pdf',
                    reason: BackupUnavailableAttachmentReason.fileMissing,
                  ),
                  BackupUnavailableAttachment(
                    itemId: 'test-card',
                    itemTitle: 'TEST-CARD-TITLE',
                    originalName: 'TEST-UNREADABLE-ATTACHMENT.pdf',
                    reason: BackupUnavailableAttachmentReason.fileUnreadable,
                  ),
                  BackupUnavailableAttachment(
                    itemId: 'test-card',
                    itemTitle: 'TEST-CARD-TITLE',
                    originalName: 'TEST-SECOND-UNREADABLE-ATTACHMENT.pdf',
                    reason: BackupUnavailableAttachmentReason.fileUnreadable,
                  ),
                  BackupUnavailableAttachment(
                    itemId: 'other-card',
                    itemTitle: 'TEST-OTHER-CARD-TITLE',
                    originalName: 'TEST-SIZE-MISMATCH-ATTACHMENT.pdf',
                    reason: BackupUnavailableAttachmentReason.sizeMismatch,
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'validpassword123',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'validpassword123',
      );
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      expect(find.text('发现 4 个不可用附件，涉及 2 条资料。'), findsOneWidget);
      expect(find.text('TEST-CARD-TITLE · 3 个附件'), findsOneWidget);
      expect(find.text('TEST-OTHER-CARD-TITLE · 1 个附件'), findsOneWidget);
      expect(find.text('本机附件文件已不存在 · 1 个'), findsOneWidget);
      expect(find.text('本机附件文件无法读取 · 2 个'), findsOneWidget);
      expect(find.text('文件大小与记录不一致 · 1 个'), findsOneWidget);
      expect(find.text('· TEST-EXPIRED-ATTACHMENT.pdf'), findsOneWidget);
      expect(find.text('· TEST-UNREADABLE-ATTACHMENT.pdf'), findsOneWidget);
      expect(
        find.text('· TEST-SECOND-UNREADABLE-ATTACHMENT.pdf'),
        findsOneWidget,
      );
      expect(find.text('资料：TEST-CARD-TITLE'), findsNothing);
      expect(find.textContaining(RegExp(r'^原因：')), findsNothing);
      expect(find.textContaining('底层附件来源不一致'), findsNothing);

      for (final width in [600.0, 900.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
        await tester.pumpAndSettle();
        expect(
          tester
              .getSize(
                find.byKey(const ValueKey('backup_export_failure_dialog')),
              )
              .width,
          lessThanOrEqualTo(480),
        );
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('8. 验证返回结果 toString() 及错误 Exception toString() 满足严格的脱敏过滤', (
      WidgetTester tester,
    ) async {
      final res = BackupFileSaveResult(
        fileName: 'anch-backup-20260611-153020.abk',
        mimeType: 'application/octet-stream',
        sizeBytes: 100,
        savedAt: 1234567,
        displayLocation: '开发验证保存器（未写入文件）',
        isSuccess: true,
      );

      final resStr = res.toString().toLowerCase();
      expect(resStr, isNot(contains('content://')));
      expect(resStr, isNot(contains('/storage/')));
      expect(resStr, isNot(contains('/sdcard/')));
      // ⚠️ 允许泛词 password/key 出现，但是不得包含具体的值，不得包含完整密文或完整 MAC，不得包含 JSON 格式
      expect(resStr, isNot(contains('test-pass-123')));
      expect(resStr, isNot(contains('{"'))); // 不包含 JSON
      expect(resStr, isNot(contains('envelope')));
      expect(resStr, isNot(contains('payload')));
      expect(resStr, isNot(contains('ciphertext')));

      final ex = BackupFileSaveException(
        BackupFileSaveErrorType.insufficientSpace,
        '磁盘空间不足',
        unavailableAttachments: const [
          BackupUnavailableAttachment(
            originalName: 'TEST-ATTACHMENT-NAME.pdf',
            reason: BackupUnavailableAttachmentReason.fileMissing,
          ),
        ],
      );
      final exStr = ex.toString().toLowerCase();
      expect(exStr, isNot(contains('content://')));
      expect(exStr, isNot(contains('/storage/')));
      expect(exStr, isNot(contains('test-pass-123')));
      expect(exStr, isNot(contains('test-attachment-name.pdf')));
      expect(exStr, isNot(contains('{"')));
    });

    testWidgets('9. 验证成功导出后返回备份恢复页且清空密码输入框', (WidgetTester tester) async {
      // 从 DataManagementPage 点击“导出备份”进入 ExportBackupPasswordPage
      await tester.pumpWidget(buildTestApp(const DataManagementPage()));
      await tester.pumpAndSettle();

      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('导出加密备份'));

      await tester.tap(find.text('导出加密备份'));
      await tester.pumpAndSettle();

      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      // 输入合法测试密码，使用 TEST-* 假数据
      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 断言成功 Dialog 出现
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);

      // 点击“我知道了”
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 验证已经 pop，返回了 DataManagementPage
      expect(find.byType(ExportBackupPasswordPage), findsNothing);
      expect(find.byType(DataManagementPage), findsOneWidget);
      expect(find.text('导出加密备份'), findsOneWidget);
      expect(find.text('从备份恢复'), findsOneWidget);
    });

    testWidgets('10. 验证失败后仍停留在密码页不自动返回', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              throw BackupFileSaveException(
                BackupFileSaveErrorType.userCancelled,
                '用户取消了导出操作',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 断言失败 Dialog 出现
      expect(find.text('导出未完成'), findsOneWidget);
      expect(find.textContaining('错误原因：导出已取消，未写入备份文件。'), findsOneWidget);

      // 点击“我知道了”
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 验证依然停留在 ExportBackupPasswordPage，没有返回
      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);
      expect(find.text('继续导出'), findsOneWidget);
    });

    testWidgets('11. 验证无回调原型模式不变且不自动 pop', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildTestApp(
          const ExportBackupPasswordPage(onExportForTestOrPrototype: null),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 断言原型阻断 Dialog 出现
      expect(find.text('无法开始导出'), findsOneWidget);

      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 验证依然在密码页，不自动 pop
      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);
    });

    testWidgets('12. 导出期间显示不可关闭进度遮罩并阻断页面操作与返回', (WidgetTester tester) async {
      final completer = Completer<BackupFileSaveResult>();
      final locationSelected = Completer<void>();
      int callCount = 0;

      await tester.pumpWidget(buildTestApp(const Scaffold()));
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ExportBackupPasswordPage(
              onExportForTestOrPrototype: (password, onProgress) async {
                callCount++;
                await locationSelected.future;
                onProgress(
                  const BackupExportProgress(
                    stage: BackupExportProgressStage.writing,
                    fraction: 0.42,
                  ),
                );
                return completer.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      // 第一次点击
      await tester.tap(find.text('继续导出'));
      await tester.pump(); // 触发 onPressed 逻辑进入异步

      expect(tester.widget<TextFormField>(passwordInput).enabled, isFalse);
      expect(tester.widget<TextFormField>(confirmInput).enabled, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);

      // 系统保存位置尚未选定时不提前显示遮罩。
      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsNothing,
      );

      locationSelected.complete();
      await tester.pump();

      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsOneWidget,
      );
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('正在导出备份'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      final popScope = tester.widget<PopScope>(
        find.byKey(const ValueKey('export_backup_pop_scope')),
      );
      expect(popScope.canPop, isFalse);
      await navigator.maybePop();
      await tester.pump();
      expect(find.byType(ExportBackupPasswordPage), findsOneWidget);

      // 遮罩下的密码显隐按钮不能响应点击。
      final passwordVisibilityButton = find.bySemanticsLabel('显示密码').first;
      final passwordEditable = find.descendant(
        of: passwordInput,
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(passwordEditable).obscureText, isTrue);
      await tester.tap(passwordVisibilityButton, warnIfMissed: false);
      await tester.pump();
      expect(tester.widget<EditableText>(passwordEditable).obscureText, isTrue);

      expect(find.text('正在验证导出流程...'), findsOneWidget);

      final buttonFinder = find.widgetWithText(ElevatedButton, '正在验证导出流程...');
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<ElevatedButton>(buttonFinder);
      expect(button.onPressed, isNull);

      await tester.tap(buttonFinder, warnIfMissed: false);
      await tester.pump();

      expect(callCount, 1);

      // 完成异步以正常关闭
      completer.complete(
        BackupFileSaveResult(
          fileName: 'anch-backup-20260611-153020.abk',
          mimeType: 'application/octet-stream',
          sizeBytes: 100,
          savedAt: DateTime.now().millisecondsSinceEpoch,
          displayLocation: '系统选择的位置',
          isSuccess: true,
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('export_backup_loading_barrier')),
        findsNothing,
      );
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
      expect(find.text('位置: 系统选择的位置'), findsNothing);

      // 点击我知道了关闭 Dialog
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
    });

    testWidgets(
      '13. 导出页 - 输入密码后触发 AppLifecycleState.paused，两个输入框被清空，且回到前台后展示 SnackBar 提示并不显示密码明文/密文',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
        await tester.pumpAndSettle();

        final passwordInput = find.byType(TextFormField).at(0);
        final confirmInput = find.byType(TextFormField).at(1);

        await tester.enterText(passwordInput, 'TEST-pass-123');
        await tester.enterText(confirmInput, 'TEST-pass-123');
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextFormField>(passwordInput).controller?.text,
          'TEST-pass-123',
        );
        expect(
          tester.widget<TextFormField>(confirmInput).controller?.text,
          'TEST-pass-123',
        );

        // 触发 AppLifecycleState.paused，再触发 resumed（符合系统生命周期序列：resumed -> inactive -> hidden -> paused -> hidden -> inactive -> resumed）
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        // 断言输入框被清空，不展示密码
        expect(
          tester.widget<TextFormField>(passwordInput).controller?.text,
          '',
        );
        expect(tester.widget<TextFormField>(confirmInput).controller?.text, '');
        expect(find.text('TEST-pass-123'), findsNothing);

        // 验证 SnackBar 提示
        expect(find.text('为保护备份密码，请重新输入后再导出。'), findsOneWidget);
      },
    );

    testWidgets('14. 导出页 - 仅 AppLifecycleState.inactive 往返时保留两个输入框且不弹出安全提示', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextFormField>(passwordInput).controller?.text,
        'TEST-pass-123',
      );
      expect(
        tester.widget<TextFormField>(confirmInput).controller?.text,
        'TEST-pass-123',
      );
      expect(find.text('安全保护已生效'), findsNothing);
    });

    testWidgets('15. 导出页 - 切后台被清理后再次点击继续导出，必须触发空密码拦截校验', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // Dismiss security dialog
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 点击继续导出
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 验证触发了空密码校验拦截
      expect(find.text('请输入备份密码'), findsOneWidget);
    });

    testWidgets('16. 导出页 - 导出 loading 期间触发生命周期变化，清空密码但在 Future 完成后展示导出结果', (
      WidgetTester tester,
    ) async {
      final completer = Completer<BackupFileSaveResult>();
      bool callbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          ExportBackupPasswordPage(
            onExportForTestOrPrototype: (password, onProgress) async {
              callbackCalled = true;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField).at(0);
      final confirmInput = find.byType(TextFormField).at(1);

      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.enterText(confirmInput, 'TEST-pass-123');

      // 点击继续导出进入 loading
      await tester.tap(find.text('继续导出'));
      await tester.pump(); // 触发 onPressed 异步

      expect(find.text('正在验证导出流程...'), findsOneWidget);
      expect(callbackCalled, isTrue);

      // 在 loading 期间切换生命周期
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // 不等待无限进度条 settle；此时导出 Future 仍在进行。
      await tester.pump();

      // 密码应被清空
      expect(tester.widget<TextFormField>(passwordInput).controller?.text, '');
      expect(tester.widget<TextFormField>(confirmInput).controller?.text, '');

      // 完成 Future
      completer.complete(
        BackupFileSaveResult(
          fileName: 'anch-backup-20260611-153020.abk',
          mimeType: 'application/octet-stream',
          sizeBytes: 1024,
          savedAt: DateTime.now().millisecondsSinceEpoch,
          displayLocation: '开发验证',
          isSuccess: true,
        ),
      );
      await tester.pumpAndSettle();

      // SAF 返回属于正常导出结果，密码虽然已清空，仍须给出最终反馈。
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
      expect(find.text('为保护备份密码，请重新输入后再导出。'), findsNothing);
    });

    testWidgets('17. 导出页 - dispose 时不抛异常', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const ExportBackupPasswordPage()));
      await tester.pumpAndSettle();

      // 切换到其他页面（通过重新 pump 其他 Widget）来销毁当前页面
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // 无异常抛出即代表通过
    });
  });

  group('ExportBackupPasswordPage PrivacyShield 防窥信号测试', () {
    late PrivacyShieldController shieldController;
    late PrivacyShieldCoordinator coordinator;

    setUp(() {
      shieldController = PrivacyShieldController();
      coordinator = PrivacyShieldCoordinator(
        controller: shieldController,
        source: PrivacyShieldSource.backupExport,
      );
    });

    Widget buildPrivacyTestWidget({
      PrivacyShieldCoordinator? shieldCoordinator,
      Future<BackupFileSaveResult> Function(
        String,
        BackupExportProgressCallback,
      )?
      onExport,
    }) {
      return buildTestApp(
        ExportBackupPasswordPage(
          privacyShieldCoordinator: shieldCoordinator,
          onExportForTestOrPrototype: onExport,
        ),
      );
    }

    testWidgets('1. 未注入 coordinator 时，页面输入与按钮交互正常且不崩溃', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPrivacyTestWidget());
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      expect(textFields, findsNWidgets(2));

      await tester.enterText(textFields.at(0), 'TEST-backup-pass');
      await tester.enterText(textFields.at(1), 'TEST-backup-pass');
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 未提供测试导出函数时，弹出开发验证说明 Dialog 且不崩溃
      expect(find.text('无法开始导出'), findsOneWidget);
    });

    testWidgets('2. 前台输入备份密码不显示遮罩，避免阻断确认输入', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildPrivacyTestWidget(shieldCoordinator: coordinator),
      );
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);

      final textFields = find.byType(TextFormField);

      // 输入第一个
      await tester.enterText(textFields.at(0), 'TEST-pwd1');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 清空第一个，输入第二个
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), 'TEST-pwd2');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);

      // 两个都清空
      await tester.enterText(textFields.at(1), '');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);
    });

    testWidgets('3. 导出成功并关闭/退出时，isVisible 重置为 false', (
      WidgetTester tester,
    ) async {
      final mockResult = BackupFileSaveResult(
        isSuccess: true,
        fileName: 'TEST.abk',
        mimeType: 'application/octet-stream',
        sizeBytes: 1024,
        savedAt: DateTime.now().millisecondsSinceEpoch,
        displayLocation: 'Documents',
      );

      await tester.pumpWidget(
        buildPrivacyTestWidget(
          shieldCoordinator: coordinator,
          onExport: (pwd, onProgress) async => mockResult,
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'TEST-pass-123');
      await tester.enterText(textFields.at(1), 'TEST-pass-123');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);

      // 点击导出
      await tester.tap(find.text('继续导出'));
      await tester.pumpAndSettle();

      // 弹出成功 Dialog，密码框已自动清空且防窥信号重置
      expect(find.text('备份文件已交给系统保存'), findsOneWidget);
      expect(shieldController.isVisible, isFalse);
    });

    testWidgets('4. 模拟生命周期触发重新遮蔽，防窥遮罩同步清理为 false', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildPrivacyTestWidget(shieldCoordinator: coordinator),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'TEST-pass-123');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);

      // 模拟进入后台 (inactive)
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      // 页面重置了密码，且防窥信号应重置为 false
      expect(shieldController.isVisible, isFalse);
    });

    testWidgets('5. 页面销毁 dispose 时只清理 backupExport 来源', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        wrapTest(
          MaterialApp(
            routes: {
              '/': (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamed('/export'),
                  child: const Text('Go'),
                ),
              ),
              '/export': (context) => ExportBackupPasswordPage(
                privacyShieldCoordinator: coordinator,
              ),
            },
          ),
          runtime,
          (child) => di.copyWith(child: child),
        ),
      );
      await tester.pumpAndSettle();

      // 手动触发其它活跃来源
      shieldController.show(PrivacyShieldSource.itemDetail);

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'TEST-pass');
      await tester.pump();
      expect(shieldController.activeSources, {PrivacyShieldSource.itemDetail});

      // 返回退出
      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigatorState.pop();
      await tester.pumpAndSettle();

      // 验证销毁后只清了 backupExport 来源，itemDetail 仍在
      expect(shieldController.isVisible, isTrue);
      expect(shieldController.activeSources, {PrivacyShieldSource.itemDetail});
    });
  });
}
