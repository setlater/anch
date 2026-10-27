@Tags(['security'])
library;

import 'package:anch/core/runtime/runtime_context.dart';
import '../support/test_bootstrap.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/database/app_database.dart';
import 'package:anch/features/backup/restore_backup_password_page.dart';
import 'package:anch/core/backup/backup_file_restore_preview_coordinator.dart';
import 'package:anch/core/backup/backup_file_read_service.dart';
import 'package:anch/core/backup/backup_file_policy.dart';
import 'package:anch/core/backup/backup_file_restore_decrypt_preview_coordinator.dart';
import 'package:anch/core/backup/backup_file_restore_apply_coordinator.dart';
import 'package:anch/core/backup/backup_package_content_preview.dart';
import 'package:anch/core/backup/backup_restore_progress.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';

void main() {
  late RuntimeContext runtime;
  late DependencyProvider di;
  late AppDatabase db;

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
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp(Widget child, {bool nestedNavigator = false}) {
    final home = nestedNavigator
        ? Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push<void>(MaterialPageRoute<void>(builder: (_) => child)),
                  child: const Text('打开恢复页'),
                ),
              ),
            ),
          )
        : child;
    return wrapTest(
      MaterialApp(home: home),
      runtime,
      (child) => di.copyWith(child: child),
    );
  }

  group('安册恢复备份密码输入与确认 UI 原型测试', () {
    testWidgets('2. 验证覆盖恢复风险卡片内容及核心警示条款展示', (WidgetTester tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in [320.0, 600.0, 1000.0]) {
        await tester.binding.setSurfaceSize(Size(width, 800));
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
                home: const RestoreBackupPasswordPage(),
              ),
              runtime,
              (child) => di.copyWith(child: child),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<AppBar>(find.byType(AppBar))
                .systemOverlayStyle
                ?.statusBarIconBrightness,
            theme.brightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark,
          );
          await tester.ensureVisible(find.text('至少 8 位'));
          expect(find.text('至少 8 位').hitTestable(), findsOneWidget);

          // 验证警示卡片标题
          expect(find.text('覆盖恢复风险'), findsOneWidget);

          // 验证核心条款
          expect(find.textContaining('恢复备份会覆盖当前 App 内已有资料。'), findsOneWidget);
          expect(
            find.textContaining('选择 .abk 文件并验证密码、核对清单后，再确认覆盖。'),
            findsOneWidget,
          );
          expect(find.textContaining('密码错误、文件损坏或版本不兼容时无法恢复。'), findsOneWidget);
          expect(find.textContaining('安册不会保存备份密码。'), findsOneWidget);
          expect(
            find.byWidgetPredicate(
              (widget) => widget is AnchIcon && widget.icon == AnchIcons.danger,
            ),
            findsOneWidget,
          );
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is AnchIcon && widget.icon == AnchIcons.radioUnchecked,
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
          expect(find.textContaining('恢复失败时，安册必须保证当前数据不被破坏。'), findsNothing);
          expect(
            find.textContaining('恢复前会验证备份密码、预览脱敏摘要，并要求再次确认覆盖操作。'),
            findsNothing,
          );
        }
      }
    });

    testWidgets('3. 验证表单基本校验逻辑：空密码、全空白、少于8位等拦截报错', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      // A. 两处均为空，直接点击继续恢复
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('请输入备份密码'), findsOneWidget);

      // B. 输入全空白密码
      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, '   ');
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('请输入备份密码'), findsOneWidget);

      // C. 输入长度小于8的密码
      await tester.enterText(passwordInput, 'short');
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('密码长度至少为 8 位'), findsOneWidget);
    });

    testWidgets('4. 验证覆盖确认校验拦截：未勾选时表单报错且不弹出 Dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      // 输入合规测试密码
      await tester.enterText(passwordInput, 'TEST-restore-123');

      // 未勾选复选框，点击继续恢复
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 断言复选框校验错误出现
      expect(find.text('请先确认你理解覆盖恢复风险'), findsOneWidget);

      // 断言阻断 Dialog 没有出现
      expect(find.text('无法开始恢复'), findsNothing);
    });

    testWidgets('5. 验证合规输入且勾选覆盖确认时，点击继续恢复仅弹出阻断 Dialog', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      // 1. 输入合法测试密码，不使用真实敏感资料
      await tester.enterText(passwordInput, 'TEST-restore-123');

      // 2. 勾选我理解覆盖确认框
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 3. 点击继续恢复
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 4. 断言弹出阻断 Dialog 且内容匹配
      expect(find.text('无法开始恢复'), findsOneWidget);
      expect(find.text('当前无法开始恢复，请返回后重新进入。'), findsOneWidget);

      // 5. 点击“我知道了”关闭 Dialog
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(find.text('无法开始恢复'), findsNothing);
    });

    testWidgets('6. 验证文案禁区审计：页面绝不包含任何诱导已开始真实物理恢复的文案', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('恢复成功'), findsNothing);
      expect(find.textContaining('已恢复'), findsNothing);
      expect(find.textContaining('正在读取文件'), findsNothing);
      expect(find.textContaining('正在解密'), findsNothing);
      expect(find.textContaining('正在覆盖数据'), findsNothing);
      expect(find.textContaining('请选择备份文件'), findsNothing);
      expect(find.textContaining('文件读取完成'), findsNothing);
      expect(find.textContaining('数据已写入'), findsNothing);
    });

    testWidgets('7. 验证注入成功的 preview 回调时，点击继续恢复正确展示 loading 与格式校验通过 Dialog', (
      WidgetTester tester,
    ) async {
      final mockResult = BackupFileRestorePreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        envelopeVersion: 1,
        payloadVersion: 1,
        kdfName: 'pbkdf2',
        cipherName: 'aes-gcm',
      );

      bool callbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onPreview: () async {
              callbackCalled = true;
              await Future<void>.delayed(const Duration(milliseconds: 100));
              return mockResult;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      // 开始调用回调但尚未完成，此时处于 loading 状态，按钮文本显示 "正在验证备份文件..."
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.text('正在验证备份文件...'), findsOneWidget);

      // 等待异步完成
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);

      // 验证弹出成功反馈 Dialog，标题匹配
      expect(find.text('备份文件格式校验通过'), findsOneWidget);
      expect(
        find.textContaining('已读取并识别备份文件格式。输入备份密码后可继续验证并确认覆盖恢复。'),
        findsOneWidget,
      );
      expect(find.textContaining('大小: 1 KB'), findsOneWidget);
      expect(find.textContaining('来源: 系统选择的文件'), findsOneWidget);
      expect(find.textContaining('外壳版本: V1'), findsOneWidget);
      expect(find.textContaining('负载版本: V1'), findsOneWidget);
      expect(find.textContaining('算法: aes-gcm (pbkdf2)'), findsOneWidget);

      // ⚠️ 【安全红线】绝不能出现解密成功或已恢复字样
      expect(find.textContaining('解密成功'), findsNothing);
      expect(find.textContaining('导入成功'), findsNothing);

      // 关闭弹窗
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.text('备份文件格式校验通过'), findsNothing);
    });

    testWidgets('8. 验证注入失败的 preview 回调时，点击继续恢复弹出失败 Dialog 且正常脱敏并停留在当前页', (
      WidgetTester tester,
    ) async {
      bool callbackCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onPreview: () async {
              callbackCalled = true;
              throw BackupFileReadException(
                BackupFileReadErrorType.fileTooLarge,
                '文件太大',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);

      // 验证弹出失败 Dialog
      expect(find.text('备份文件读取失败'), findsOneWidget);
      expect(find.textContaining('错误原因: 备份文件过大，暂不支持读取。'), findsOneWidget);

      // 关闭弹窗
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(find.text('备份文件读取失败'), findsNothing);

      // 断言依然停留在密码确认页
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
      expect(find.text('继续恢复'), findsOneWidget);
    });

    testWidgets(
      '9. 验证注入成功的 decrypt preview 回调时，点击继续恢复正确展示 loading 与成功摘要 Dialog',
      (WidgetTester tester) async {
        final mockResult = BackupFileRestoreDecryptPreviewResult(
          sizeBytes: 2048,
          sizeLabel: '2 KB',
          readAt: 1718035200000,
          displaySource: '系统选择的文件',
          payloadVersion: 1,
          schemaVersion: 1,
          membersCount: 2,
          itemsCount: 5,
          itemFieldsCount: 15,
          appSettingsCount: 3,
        );

        bool callbackCalled = false;
        String passedPassword = '';

        await tester.pumpWidget(
          buildTestApp(
            RestoreBackupPasswordPage(
              onDecryptPreview: (password) async {
                callbackCalled = true;
                passedPassword = password;
                await Future<void>.delayed(const Duration(milliseconds: 100));
                return mockResult;
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        final passwordInput = find.byType(TextFormField);
        await tester.enterText(passwordInput, 'TEST-restore-123');

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        await tester.tap(find.text('继续恢复'));
        // 开始调用回调但尚未完成，此时处于 loading 状态，按钮文本显示 "正在验证备份密码..."
        await tester.pump(const Duration(milliseconds: 20));
        expect(find.text('正在验证备份密码...'), findsOneWidget);
        expect(find.text('正在验证备份'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('restore_verification_loading_barrier')),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // 等待异步完成
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
        expect(passedPassword, 'TEST-restore-123');

        // 验证弹出成功反馈 Dialog，标题匹配
        expect(find.text('备份密码验证通过'), findsOneWidget);
        expect(
          find.textContaining('已验证备份密码。请先核对以下恢复范围；确认后会整包覆盖当前数据。'),
          findsOneWidget,
        );
        expect(find.textContaining('成员数量：2'), findsOneWidget);
        expect(find.textContaining('资料数量：5'), findsOneWidget);
        expect(find.textContaining('字段数量：15'), findsOneWidget);
        expect(find.textContaining('设置数量：3'), findsNothing);
        expect(find.textContaining('Payload 版本：'), findsNothing);
        expect(find.textContaining('Schema 版本：'), findsNothing);
        expect(find.textContaining('仅列出成员、资料名称、类型、状态和附件数量'), findsNothing);
        expect(find.textContaining('文件大小：2 KB'), findsOneWidget);

        // ⚠️ 【安全红线】绝不能出现解密成功或已恢复字样
        expect(find.textContaining('恢复成功'), findsNothing);
        expect(find.textContaining('已恢复'), findsNothing);
        expect(find.textContaining('数据已写入'), findsNothing);
        expect(find.textContaining('覆盖完成'), findsNothing);
        expect(find.textContaining('导入成功'), findsNothing);
        expect(find.textContaining('当前数据已替换'), findsNothing);

        // 关闭弹窗
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
        expect(find.text('备份密码验证通过'), findsNothing);
      },
    );

    testWidgets('超过已验证容量的备份仍可进入恢复清单，并提示风险', (WidgetTester tester) async {
      final preview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: BackupFilePolicy.verifiedV2CapacityBytes + 1,
        sizeLabel: '240.0 MB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 2,
        schemaVersion: 1,
        membersCount: 0,
        itemsCount: 0,
        itemFieldsCount: 0,
        appSettingsCount: 0,
      );
      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => preview,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证通过'), findsOneWidget);
      expect(find.textContaining('恢复可能耗时较长。可以继续恢复'), findsOneWidget);
      expect(find.text('继续覆盖恢复'), findsOneWidget);
    });

    testWidgets('认证完成后按成员显示恢复清单，不显示字段值或附件内容', (WidgetTester tester) async {
      final preview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 8,
        membersCount: 1,
        itemsCount: 2,
        itemFieldsCount: 6,
        appSettingsCount: 0,
        contentPreview: const BackupPackageContentPreview(
          attachmentCount: 3,
          members: [
            BackupPackageMemberPreview(
              displayName: 'TEST-清单成员',
              items: [
                BackupPackageItemPreview(
                  title: 'TEST-当前资料',
                  typeKey: 'insurance',
                  templateVersion: 1,
                  status: BackupPackageItemPreviewStatus.active,
                  attachmentCount: 2,
                ),
                BackupPackageItemPreview(
                  title: 'TEST-归档资料',
                  typeKey: 'generic',
                  templateVersion: 1,
                  status: BackupPackageItemPreviewStatus.archived,
                  attachmentCount: 1,
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => preview,
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('TEST-清单成员 · 2 条资料'), findsOneWidget);
      expect(find.text('TEST-当前资料'), findsOneWidget);
      expect(find.text('TEST-归档资料'), findsOneWidget);
      expect(find.text('保险资料 · 当前资料 · 2 个附件'), findsOneWidget);
      expect(find.text('其他资料 · 已归档 · 1 个附件'), findsOneWidget);
      expect(find.textContaining('TEST-字段值'), findsNothing);
      expect(find.textContaining('TEST-附件内容'), findsNothing);
      expect(find.text('继续覆盖恢复'), findsOneWidget);

      final dialogSize = tester.getSize(
        find.byKey(const ValueKey('restore_content_preview_dialog')),
      );
      final viewportWidth =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(dialogSize.width, greaterThan(viewportWidth * 0.8));
    });

    testWidgets('10. 验证注入失败的 decrypt preview 回调时，弹出密码错误 Dialog 并停留在当前页', (
      WidgetTester tester,
    ) async {
      bool callbackCalled = false;
      final previewCompleter =
          Completer<BackupFileRestoreDecryptPreviewResult>();

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async {
              callbackCalled = true;
              return previewCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');

      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pump(const Duration(milliseconds: 20));

      expect(
        find.byKey(const ValueKey('restore_verification_loading_barrier')),
        findsOneWidget,
      );
      previewCompleter.completeError(
        BackupFileRestoreDecryptPreviewException(
          BackupFileRestoreDecryptPreviewErrorType
              .invalidPasswordOrCorruptedData,
          '备份密码不正确，或备份文件已损坏。',
        ),
      );
      await tester.pumpAndSettle();

      expect(callbackCalled, isTrue);
      expect(
        find.byKey(const ValueKey('restore_verification_loading_barrier')),
        findsNothing,
      );

      // 验证弹出失败 Dialog
      expect(find.text('备份密码验证失败'), findsOneWidget);
      expect(find.textContaining('备份密码不正确，或备份文件已损坏。'), findsOneWidget);

      // 关闭弹窗
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证失败'), findsNothing);

      // 断言依然停留在密码确认页
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
    });

    testWidgets('密码错误只清空输入并保留已选文件，可直接再次验证', (WidgetTester tester) async {
      var decryptCalls = 0;
      var clearCalls = 0;
      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            preparedFileSizeLabel: '1 KB',
            onDecryptPreview: (password) async {
              decryptCalls++;
              throw BackupFileRestoreDecryptPreviewException(
                BackupFileRestoreDecryptPreviewErrorType
                    .invalidPasswordOrCorruptedData,
                '备份密码不正确，或备份文件已损坏。',
              );
            },
            onApplyRestore: (password) async {
              throw StateError('密码验证失败时不应进入覆盖恢复');
            },
            onClearPreparedRestoreFile: () => clearCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'wrong-password-1');
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      expect(find.text('无法恢复备份'), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(clearCalls, 0);
      expect(find.text('已选择备份文件 · 1 KB'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller
            ?.text,
        isEmpty,
      );

      await tester.enterText(find.byType(TextFormField), 'wrong-password-2');
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      expect(decryptCalls, 2);
      expect(clearCalls, 0);
    });

    testWidgets('非密码类认证错误仍清除所选文件会话', (WidgetTester tester) async {
      var clearCalls = 0;
      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            preparedFileSizeLabel: '1 KB',
            onDecryptPreview: (password) async {
              throw BackupFileRestoreDecryptPreviewException(
                BackupFileRestoreDecryptPreviewErrorType.invalidFileFormat,
                '备份文件格式不正确或已损坏。',
              );
            },
            onApplyRestore: (password) async {
              throw StateError('认证失败时不应进入覆盖恢复');
            },
            onClearPreparedRestoreFile: () => clearCalls++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'restore-password');
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      expect(clearCalls, 1);
      expect(find.text('已选择备份文件 · 1 KB'), findsNothing);
      expect(find.text('尚未选择备份文件'), findsOneWidget);
    });

    testWidgets('11. 验证预检成功后取消第一层 Dialog，不调用 apply 且仍在当前页', (
      WidgetTester tester,
    ) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      bool applyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              applyCalled = true;
              throw UnimplementedError();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 第一层预检 Dialog 弹出
      expect(find.text('备份密码验证通过'), findsOneWidget);

      // 点击取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 第一层 Dialog 消失
      expect(find.text('备份密码验证通过'), findsNothing);
      expect(applyCalled, isFalse);

      // 仍在当前密码页
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
    });

    testWidgets('12. 验证预检成功后继续恢复，再取消最终确认 Dialog，不调用 apply 且留在本页', (
      WidgetTester tester,
    ) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      bool applyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              applyCalled = true;
              throw UnimplementedError();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 第一层 Dialog
      await tester.tap(find.text('继续覆盖恢复'));
      await tester.pumpAndSettle();

      // 第二层确认 Dialog 出现
      expect(find.text('确认覆盖恢复？'), findsOneWidget);

      // 点击确认 Dialog 里的取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 二次确认框消失，未调用 apply，且未跳转
      expect(find.text('确认覆盖恢复？'), findsNothing);
      expect(applyCalled, isFalse);
      expect(find.text('恢复验证完成'), findsNothing);
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
    });

    testWidgets(
      '13. 验证 apply loading 期间按钮禁用与重复点击防护（Completer 挂起），成功后 pop 并校验敏感词',
      (WidgetTester tester) async {
        final mockPreview = BackupFileRestoreDecryptPreviewResult(
          sizeBytes: 1024,
          sizeLabel: '1 KB',
          readAt: 1718035200000,
          displaySource: '系统选择的文件',
          payloadVersion: 1,
          schemaVersion: 1,
          membersCount: 2,
          itemsCount: 3,
          itemFieldsCount: 6,
          appSettingsCount: 0,
        );

        final mockApply = BackupFileRestoreApplyResult(
          restoredMembersCount: 2,
          restoredItemsCount: 3,
          restoredItemFieldsCount: 6,
          restoredAppSettingsCount: 0,
          restoredAt: 1718035200000,
        );

        final completer = Completer<BackupFileRestoreApplyResult>();
        int applyCallCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (context) => wrapTest(
                            RestoreBackupPasswordPage(
                              onDecryptPreview: (password) async => mockPreview,
                              onApplyRestore: (password) async {
                                applyCallCount++;
                                return completer.future;
                              },
                            ),
                            runtime,
                            (child) => di.copyWith(child: child),
                          ),
                        ),
                      );
                    },
                    child: const Text('GoToRestore'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('GoToRestore'));
        await tester.pumpAndSettle();

        final passwordInput = find.byType(TextFormField);
        await tester.enterText(passwordInput, 'TEST-restore-123');
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        await tester.tap(find.text('继续恢复'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('继续覆盖恢复'));
        await tester.pumpAndSettle();

        // 点击确认覆盖恢复，触发 apply 并挂起
        await tester.tap(find.text('确认覆盖恢复'));
        await tester.pump(const Duration(milliseconds: 10));

        // 验证 loading 文案
        expect(find.text('正在覆盖恢复...'), findsOneWidget);
        expect(find.text('正在恢复备份'), findsOneWidget);
        expect(find.text('正在应用恢复内容，请保持应用在前台'), findsOneWidget);
        final loadingTextStyle = DefaultTextStyle.of(
          tester.element(find.text('正在恢复备份')),
        ).style;
        expect(loadingTextStyle.decoration, TextDecoration.none);
        expect(
          find.ancestor(
            of: find.text('正在恢复备份'),
            matching: find.byType(Material),
          ),
          findsWidgets,
        );
        expect(
          find.byKey(const ValueKey('restore_apply_loading_barrier')),
          findsOneWidget,
        );
        expect(tester.widget<TextFormField>(passwordInput).enabled, isFalse);
        final passwordEditable = tester.widget<EditableText>(
          find.descendant(
            of: passwordInput,
            matching: find.byType(EditableText),
          ),
        );
        expect(passwordEditable.focusNode.canRequestFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        // 获取继续恢复按钮并确认其 onPressed 处于禁用态 (null)
        final buttonFinder = find.widgetWithText(ElevatedButton, '正在覆盖恢复...');
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<ElevatedButton>(buttonFinder);
        expect(button.onPressed, isNull);

        // 在 apply Future 未完成期间，进行重复点击测试
        await tester.tap(buttonFinder, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 10));

        // 确认 apply 调用计数必须严格等于 1
        expect(applyCallCount, 1);

        // 完成异步 Future
        completer.complete(mockApply);
        await tester.pumpAndSettle();

        expect(find.text('正在恢复备份'), findsNothing);
        expect(
          find.byKey(const ValueKey('restore_apply_loading_barrier')),
          findsNothing,
        );

        // 验证最终弹出“恢复验证完成”成功弹窗
        expect(find.text('恢复验证完成'), findsOneWidget);
        expect(find.textContaining('备份已恢复。请返回首页核对资料。'), findsOneWidget);

        // ⚠️ 【安全红线】Dialog 敏感词扫描
        final dialogFinder = find.byType(AlertDialog);
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('TEST-restore-123'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('TEST-member-name'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('TEST-item-title'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('TEST-field-value'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('content://'),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: dialogFinder,
            matching: find.textContaining('/storage'),
          ),
          findsNothing,
        );

        // 点击我知道了 ➜ 自动 pop 返回前一页
        await tester.tap(find.text('我知道了'));
        await tester.pumpAndSettle();

        expect(find.byType(RestoreBackupPasswordPage), findsNothing);
      },
    );

    testWidgets('V2 恢复在确认前不执行 staging，通知栏短暂失焦不中断真实读取进度', (
      WidgetTester tester,
    ) async {
      final preview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1.0 KB',
        readAt: 1,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 1,
        itemsCount: 1,
        itemFieldsCount: 0,
        appSettingsCount: 0,
        requiresFullVerificationOnApply: true,
      );
      final applyCompleter = Completer<BackupFileRestoreApplyResult>();
      BackupRestoreProgressCallback? onProgress;
      var applyCalls = 0;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            preparedFileSizeLabel: '1.0 KB',
            onDecryptPreview: (_) async => preview,
            onApplyRestoreWithProgress: (_, progressCallback) {
              applyCalls++;
              onProgress = progressCallback;
              return applyCompleter.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      expect(find.textContaining('确认后会完整校验备份并准备附件'), findsOneWidget);
      expect(applyCalls, 0);

      await tester.tap(find.text('确认覆盖恢复'));
      await tester.pump();
      expect(applyCalls, 1);

      onProgress!(
        const BackupRestoreProgress(
          stage: BackupRestoreProgressStage.staging,
          readBytes: 512,
          totalBytes: 1024,
        ),
      );
      await tester.pump();
      expect(find.text('正在准备恢复附件'), findsOneWidget);
      expect(find.text('正在读取并校验备份文件，请保持应用在前台'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      // Android 下拉通知栏只产生 inactive -> resumed；恢复仍在前台可见，
      // 不能清空会话、关闭进度遮罩或弹出“安全保护已生效”。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        find.byKey(const ValueKey('restore_apply_loading_barrier')),
        findsOneWidget,
      );
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('安全保护已生效'), findsNothing);

      onProgress!(
        const BackupRestoreProgress(
          stage: BackupRestoreProgressStage.applying,
          readBytes: 0,
        ),
      );
      await tester.pump();
      expect(find.text('正在应用恢复内容，请保持应用在前台'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      applyCompleter.complete(
        BackupFileRestoreApplyResult(
          restoredMembersCount: 1,
          restoredItemsCount: 1,
          restoredItemFieldsCount: 0,
          restoredAppSettingsCount: 0,
          restoredAt: 1,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('恢复完成'), findsOneWidget);
    });

    testWidgets('14. 验证最终恢复失败弹出“恢复失败”Dialog，脱敏显示并留在当前页', (
      WidgetTester tester,
    ) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              throw BackupFileRestoreApplyException(
                BackupFileRestoreApplyErrorType.importTransactionFailed,
                '覆盖恢复事务写入数据库冲突',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续覆盖恢复'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认覆盖恢复'));
      await tester.pumpAndSettle();

      // 验证弹出失败 Dialog 并校验脱敏
      expect(find.text('恢复失败'), findsOneWidget);
      expect(find.textContaining('恢复过程中发生错误，当前数据不应被破坏。'), findsOneWidget);

      final dialogFinder = find.byType(AlertDialog);
      expect(
        find.descendant(
          of: dialogFinder,
          matching: find.textContaining('TEST-restore-123'),
        ),
        findsNothing,
      );
      expect(
        find.descendant(of: dialogFinder, matching: find.textContaining('冲突')),
        findsNothing,
      ); // 屏蔽底层原始 SQL 或错误细节

      // 关闭弹窗仍停留密码页
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      expect(find.text('恢复失败'), findsNothing);
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
    });

    testWidgets('直接恢复模式只输入一次密码，先核对清单再确认覆盖恢复', (WidgetTester tester) async {
      var decryptCalls = 0;
      var applyCalls = 0;
      String? decryptedPassword;
      String? appliedPassword;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            preparedFileSizeLabel: '1 KB',
            onDecryptPreview: (password) async {
              decryptCalls++;
              decryptedPassword = password;
              return BackupFileRestoreDecryptPreviewResult(
                sizeBytes: 1024,
                sizeLabel: '1 KB',
                readAt: 1718035200000,
                displaySource: '系统选择的文件',
                payloadVersion: 1,
                schemaVersion: 5,
                membersCount: 2,
                itemsCount: 3,
                itemFieldsCount: 6,
                appSettingsCount: 0,
              );
            },
            onApplyRestore: (password) async {
              applyCalls++;
              appliedPassword = password;
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 2,
                restoredItemsCount: 3,
                restoredItemFieldsCount: 6,
                restoredAppSettingsCount: 0,
                restoredAt: 1718035200000,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('已选择备份文件 · 1 KB'), findsOneWidget);
      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('继续恢复'), findsNothing);

      await tester.enterText(find.byType(TextFormField), 'TEST-direct-restore');
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();

      expect(decryptCalls, 1);
      expect(applyCalls, 0);
      expect(decryptedPassword, 'TEST-direct-restore');
      expect(find.text('备份密码验证通过'), findsOneWidget);
      expect(find.text('确认覆盖恢复'), findsOneWidget);
      expect(find.text('确认覆盖恢复？'), findsNothing);

      await tester.tap(find.text('确认覆盖恢复'));
      await tester.pumpAndSettle();

      expect(applyCalls, 1);
      expect(appliedPassword, 'TEST-direct-restore');
      expect(find.text('恢复完成'), findsOneWidget);
    });

    testWidgets('直接恢复模式在页面内选择文件后才展示密码与恢复按钮', (WidgetTester tester) async {
      var selectCalls = 0;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            onSelectFile: () async {
              selectCalls++;
              return BackupFileRestorePreviewResult(
                sizeBytes: 2048,
                sizeLabel: '2 KB',
                readAt: 1718035200000,
                displaySource: '系统选择的文件',
                envelopeVersion: 1,
                payloadVersion: 1,
                kdfName: 'pbkdf2',
                cipherName: 'aes-gcm',
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('尚未选择备份文件'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('确定恢复'), findsNothing);

      await tester.tap(find.text('选择文件'));
      await tester.pumpAndSettle();

      expect(selectCalls, 1);
      expect(find.text('已选择备份文件 · 2 KB'), findsOneWidget);
      expect(find.text('重新选择'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('确定恢复'), findsOneWidget);
    });

    testWidgets('系统文件选择器往返不清除新选文件或弹出安全保护提示', (WidgetTester tester) async {
      final selection = Completer<BackupFileRestorePreviewResult>();

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            onSelectFile: () => selection.future,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择文件'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      selection.complete(
        BackupFileRestorePreviewResult(
          sizeBytes: 2048,
          sizeLabel: '2 KB',
          readAt: 1718035200000,
          displaySource: '系统选择的文件',
          envelopeVersion: 1,
          payloadVersion: 1,
          kdfName: 'pbkdf2',
          cipherName: 'aes-gcm',
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('已选择备份文件 · 2 KB'), findsOneWidget);
      expect(find.text('安全保护已生效'), findsNothing);
    });

    testWidgets('系统文件选择完成后，内层导航恢复页切后台必须关闭已认证清单', (WidgetTester tester) async {
      final selection = Completer<BackupFileRestorePreviewResult>();
      var applyCalls = 0;
      var decryptCalls = 0;
      final preview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 1,
        itemsCount: 1,
        itemFieldsCount: 0,
        appSettingsCount: 0,
      );

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            directRestore: true,
            onSelectFile: () => selection.future,
            onDecryptPreview: (_) async {
              decryptCalls++;
              return preview;
            },
            onApplyRestore: (_) async {
              applyCalls++;
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 1,
                restoredItemsCount: 1,
                restoredItemFieldsCount: 0,
                restoredAppSettingsCount: 0,
                restoredAt: DateTime.now().millisecondsSinceEpoch,
              );
            },
          ),
          nestedNavigator: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开恢复页'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('选择文件'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      selection.complete(
        BackupFileRestorePreviewResult(
          sizeBytes: 1024,
          sizeLabel: '1 KB',
          readAt: 1718035200000,
          displaySource: '系统选择的文件',
          envelopeVersion: 1,
          payloadVersion: 1,
          kdfName: 'pbkdf2-hmac-sha256',
          cipherName: 'aes-256-gcm',
        ),
      );
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField),
        List<String>.filled(8, 'x').join(),
      );
      await tester.tap(find.text('确定恢复'));
      await tester.pumpAndSettle();
      expect(decryptCalls, 1);
      expect(find.text('备份密码验证通过'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证通过'), findsNothing);
      expect(find.text('安全保护已生效'), findsOneWidget);
      expect(find.text('为保护备份内容，请重新选择备份文件并输入密码后再继续恢复。'), findsOneWidget);
      expect(applyCalls, 0);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
      expect(find.text('尚未选择备份文件'), findsOneWidget);
      expect(find.text('选择文件').hitTestable(), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets(
      '15. 恢复页 - 输入恢复密码并勾选确认后触发 AppLifecycleState.paused，回到前台后密码被清空，确认状态被重置，且不展示 TEST-pass-123，弹出 SnackBar 提示',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const RestoreBackupPasswordPage()),
        );
        await tester.pumpAndSettle();

        final passwordInput = find.byType(TextFormField);
        await tester.enterText(passwordInput, 'TEST-pass-123');
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextFormField>(passwordInput).controller?.text,
          'TEST-pass-123',
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);

        // 触发生命周期 paused ➜ resumed（符合规范的生命周期转换顺序）
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

        // 密码和 Checkbox 应该被重置，页面不展示密码文本
        expect(
          tester.widget<TextFormField>(passwordInput).controller?.text,
          '',
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
        expect(find.text('TEST-pass-123'), findsNothing);

        // 显示 SnackBar 提示
        expect(find.text('为保护备份密码，请重新输入后再继续恢复。'), findsOneWidget);
      },
    );

    testWidgets(
      '16. 恢复页 - 仅 AppLifecycleState.inactive 往返时保留输入与确认状态，且不弹出安全提示',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          buildTestApp(const RestoreBackupPasswordPage()),
        );
        await tester.pumpAndSettle();

        final passwordInput = find.byType(TextFormField);
        await tester.enterText(passwordInput, 'TEST-pass-123');
        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();

        expect(
          tester.widget<TextFormField>(passwordInput).controller?.text,
          'TEST-pass-123',
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
        expect(find.text('安全保护已生效'), findsNothing);
      },
    );

    testWidgets('17. 恢复页 - 切后台被清理后继续恢复，必须触发重新输入密码和重新勾选确认校验', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-pass-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));

      // Dismiss security dialog
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      // 点击继续恢复
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 应该首先被空密码拦截，并且勾选拦截也会触发
      expect(find.text('请输入备份密码'), findsOneWidget);
    });

    testWidgets('18. 恢复清单在后台时关闭并清除已认证内容，不能继续覆盖恢复', (WidgetTester tester) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      bool applyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              applyCalled = true;
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 2,
                restoredItemsCount: 3,
                restoredItemFieldsCount: 6,
                restoredAppSettingsCount: 0,
                restoredAt: DateTime.now().millisecondsSinceEpoch,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 点击继续恢复，弹出第一层 Dialog
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证通过'), findsOneWidget);

      // 切换生命周期（切后台）
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证通过'), findsNothing);
      expect(find.text('安全保护已生效'), findsOneWidget);
      expect(find.text('为保护备份内容，请重新选择备份文件并输入密码后再继续恢复。'), findsOneWidget);
      expect(find.text('确认覆盖恢复？'), findsNothing);
      expect(applyCalled, isFalse);
    });

    testWidgets('19. 内层导航的覆盖确认在后台关闭弹窗，保留恢复页且不能执行 apply', (
      WidgetTester tester,
    ) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      bool applyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              applyCalled = true;
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 2,
                restoredItemsCount: 3,
                restoredItemFieldsCount: 6,
                restoredAppSettingsCount: 0,
                restoredAt: DateTime.now().millisecondsSinceEpoch,
              );
            },
          ),
          nestedNavigator: true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('打开恢复页'));
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // 弹出第一层
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      // 弹出第二层
      await tester.tap(find.text('继续覆盖恢复'));
      await tester.pumpAndSettle();
      expect(find.text('确认覆盖恢复？'), findsOneWidget);

      // 切换生命周期（切后台）
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('确认覆盖恢复？'), findsNothing);
      expect(find.text('安全保护已生效'), findsOneWidget);
      expect(find.text('为保护备份内容，请重新选择备份文件并输入密码后再继续恢复。'), findsOneWidget);
      expect(applyCalled, isFalse);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();
      expect(find.byType(RestoreBackupPasswordPage), findsOneWidget);
    });

    testWidgets('20. 解密校验中进入后台时，异步结果不会展示恢复清单或继续覆盖', (
      WidgetTester tester,
    ) async {
      final completer = Completer<BackupFileRestoreDecryptPreviewResult>();
      var previewCalls = 0;
      var applyCalls = 0;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) {
              previewCalls++;
              return completer.future;
            },
            onApplyRestore: (password) async {
              applyCalls++;
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 2,
                restoredItemsCount: 3,
                restoredItemFieldsCount: 6,
                restoredAppSettingsCount: 0,
                restoredAt: DateTime.now().millisecondsSinceEpoch,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('继续恢复'));
      await tester.pump();
      expect(previewCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      completer.complete(
        BackupFileRestoreDecryptPreviewResult(
          sizeBytes: 1024,
          sizeLabel: '1 KB',
          readAt: 1718035200000,
          displaySource: '系统选择的文件',
          payloadVersion: 1,
          schemaVersion: 1,
          membersCount: 2,
          itemsCount: 3,
          itemFieldsCount: 6,
          appSettingsCount: 0,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('安全保护已生效'), findsOneWidget);
      expect(find.text('备份密码验证通过'), findsNothing);
      expect(find.text('确认覆盖恢复？'), findsNothing);
      expect(previewCalls, 1);
      expect(applyCalls, 0);
    });

    testWidgets('认证后的恢复清单切后台后要求重新选择，不能复用已认证内容', (WidgetTester tester) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 4,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );
      var previewCalls = 0;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async {
              previewCalls++;
              return mockPreview;
            },
            onApplyRestore: (password) async {
              return BackupFileRestoreApplyResult(
                restoredMembersCount: 2,
                restoredItemsCount: 3,
                restoredItemFieldsCount: 6,
                restoredAppSettingsCount: 0,
                restoredAt: DateTime.now().millisecondsSinceEpoch,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();
      expect(find.text('备份密码验证通过'), findsOneWidget);
      expect(previewCalls, 1);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('安全保护已生效'), findsOneWidget);
      await tester.tap(find.text('我知道了'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('备份密码验证通过'), findsOneWidget);
      expect(previewCalls, 2);
    });

    testWidgets('21. 恢复页 - 验证 loading 期间触发生命周期变化，不泄露密码且不重复调用，且异步结果被阻断', (
      WidgetTester tester,
    ) async {
      final mockPreview = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 1024,
        sizeLabel: '1 KB',
        readAt: 1718035200000,
        displaySource: '系统选择的文件',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 2,
        itemsCount: 3,
        itemFieldsCount: 6,
        appSettingsCount: 0,
      );

      final completer = Completer<BackupFileRestoreApplyResult>();
      bool applyCalled = false;

      await tester.pumpWidget(
        buildTestApp(
          RestoreBackupPasswordPage(
            onDecryptPreview: (password) async => mockPreview,
            onApplyRestore: (password) async {
              applyCalled = true;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final passwordInput = find.byType(TextFormField);
      await tester.enterText(passwordInput, 'TEST-restore-123');
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('继续覆盖恢复'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('确认覆盖恢复'));
      await tester.pump(); // 触发 onPressed 异步

      expect(find.text('正在覆盖恢复...'), findsOneWidget);
      expect(applyCalled, isTrue);

      // 在 loading 期间切换生命周期
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 300));

      // Dismiss first safety dialog popped up on resume
      await tester.tap(find.text('我知道了'));
      await tester.pump(const Duration(milliseconds: 300));

      // 密码应被清空
      expect(tester.widget<TextFormField>(passwordInput).controller?.text, '');

      // 完成 Future
      completer.complete(
        BackupFileRestoreApplyResult(
          restoredMembersCount: 2,
          restoredItemsCount: 3,
          restoredItemFieldsCount: 6,
          restoredAppSettingsCount: 0,
          restoredAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      await tester.pumpAndSettle();

      // 回前台并完成后，由于 _clearedByLifecycle == true，应该拦截成功 Dialog 的弹出，并在 SnackBar 提示
      expect(find.text('恢复验证完成'), findsNothing);
      expect(find.text('为保护备份密码，请重新输入后再继续恢复。'), findsOneWidget);
    });

    testWidgets('22. 恢复页 - dispose 时不抛异常', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp(const RestoreBackupPasswordPage()));
      await tester.pumpAndSettle();

      // 切换到其他页面（通过重新 pump 其他 Widget）来销毁当前页面
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      // 无异常抛出即代表通过
    });
  });

  group('RestoreBackupPasswordPage PrivacyShield 防窥信号测试', () {
    late PrivacyShieldController shieldController;
    late PrivacyShieldCoordinator coordinator;

    setUp(() {
      shieldController = PrivacyShieldController();
      coordinator = PrivacyShieldCoordinator(
        controller: shieldController,
        source: PrivacyShieldSource.backupRestore,
      );
    });

    Widget buildPrivacyTestWidget({
      PrivacyShieldCoordinator? shieldCoordinator,
      Future<BackupFileRestoreDecryptPreviewResult> Function(String)?
      onDecryptPreview,
      Future<BackupFileRestoreApplyResult> Function(String)? onApply,
    }) {
      return buildTestApp(
        RestoreBackupPasswordPage(
          privacyShieldCoordinator: shieldCoordinator,
          onDecryptPreview: onDecryptPreview,
          onApplyRestore: onApply,
        ),
      );
    }

    testWidgets('1. 未注入 coordinator 时，页面输入与 Dialog 交互行为正常且不崩溃', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildPrivacyTestWidget());
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'TEST-backup-pass');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.tap(find.text('继续恢复'));
      await tester.pumpAndSettle();

      expect(find.text('无法开始恢复'), findsOneWidget);
    });

    testWidgets('2. 前台输入恢复密码不显示遮罩，清空后状态保持清理', (WidgetTester tester) async {
      await tester.pumpWidget(
        buildPrivacyTestWidget(shieldCoordinator: coordinator),
      );
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);

      final textField = find.byType(TextFormField);

      // 输入密码
      await tester.enterText(textField, 'TEST-pwd123');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 清空密码
      await tester.enterText(textField, '');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);
    });

    testWidgets('3. 生命周期触发清理后，密码重置且 visible=false', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        buildPrivacyTestWidget(shieldCoordinator: coordinator),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, 'TEST-pwd123');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);

      // 模拟进入后台
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);
    });

    testWidgets('4. 前台恢复密码输入及覆盖确认 Dialog 不显示遮罩，取消后状态保持清理', (
      WidgetTester tester,
    ) async {
      final mockDecryptResult = BackupFileRestoreDecryptPreviewResult(
        sizeBytes: 10240,
        sizeLabel: '10KB',
        readAt: DateTime.now().millisecondsSinceEpoch,
        displaySource: 'Documents',
        payloadVersion: 1,
        schemaVersion: 1,
        membersCount: 1,
        itemsCount: 5,
        itemFieldsCount: 10,
        appSettingsCount: 2,
      );

      await tester.pumpWidget(
        buildPrivacyTestWidget(
          shieldCoordinator: coordinator,
          onDecryptPreview: (pwd) async => mockDecryptResult,
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextFormField);
      await tester.enterText(textField, 'TEST-pwd-1234');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 1. 点击“继续恢复”以调出第一层 Dialog
      final restoreBtn = find.text('继续恢复');
      await tester.ensureVisible(restoreBtn);
      await tester.tap(restoreBtn);
      await tester.pumpAndSettle();

      // 第一层 Dialog 出现
      expect(find.text('备份密码验证通过'), findsOneWidget);
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 2. 点击第一层 Dialog 的“继续覆盖恢复”以调出第二层 Dialog
      final continueBtn = find.text('继续覆盖恢复');
      await tester.ensureVisible(continueBtn);
      await tester.tap(continueBtn);
      await tester.pumpAndSettle();

      // 第二层 Dialog 出现
      expect(find.text('确认覆盖恢复？'), findsOneWidget);
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 3. 点击取消，返回密码输入页，前台遮罩仍保持清理。
      final cancelBtn = find.text('取消');
      await tester.ensureVisible(cancelBtn);
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      // 4. 清空密码，应恢复为 false
      await tester.enterText(textField, '');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);
    });

    testWidgets(
      '5. 页面销毁 dispose 时清理 backupRestore 与 restoreConfirming 来源，但不破坏其它来源',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          wrapTest(
            MaterialApp(
              routes: {
                '/': (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/restore'),
                    child: const Text('Go'),
                  ),
                ),
                '/restore': (context) => RestoreBackupPasswordPage(
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

        final textField = find.byType(TextFormField);
        await tester.enterText(textField, 'TEST-pwd');
        await tester.pump();
        expect(shieldController.activeSources, {
          PrivacyShieldSource.itemDetail,
        });

        // 返回退出
        final navigatorState = tester.state<NavigatorState>(
          find.byType(Navigator),
        );
        navigatorState.pop();
        await tester.pumpAndSettle();

        // 验证已被清理，且 itemDetail 独立保留
        expect(shieldController.isVisible, isTrue);
        expect(shieldController.activeSources, {
          PrivacyShieldSource.itemDetail,
        });
      },
    );
  });
}
