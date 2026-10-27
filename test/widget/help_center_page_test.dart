import '../support/test_bootstrap.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/app/third_party_licenses.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/features/help/about_page.dart';
import 'package:anch/features/mine/mine_page.dart';
import 'package:anch/features/help/help_center_page.dart';
import 'package:flutter/foundation.dart';

void main() {
  group('帮助手册入口与既有离线说明文案红线安全测试', () {
    testWidgets('0. MinePage 优先展示设置入口，离线说明位于页尾', (tester) async {
      final runtime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      await tester.pumpWidget(
        wrapTest(const MaterialApp(home: MinePage()), runtime),
      );
      await tester.pumpAndSettle();

      expect(find.text('安全设置'), findsOneWidget);
      expect(find.text('安全说明'), findsNothing);
      expect(find.text('联网能力'), findsNothing);
      expect(find.text('账号登录'), findsNothing);
      expect(find.text('敏感字段'), findsNothing);
      expect(find.text('开发验证模式说明'), findsNothing);

      expect(find.text('应用锁'), findsOneWidget);
      expect(find.text('指纹或 PIN 保护本机资料'), findsOneWidget);
      expect(find.text('未启用'), findsOneWidget);
      expect(find.text('备份、恢复或删除本机资料'), findsOneWidget);
      expect(find.text('帮助手册'), findsOneWidget);
      expect(find.text('离线查看使用、安全与备份说明'), findsOneWidget);
      expect(find.text('管理'), findsNothing);
      expect(find.text('查看说明'), findsNothing);

      await tester.dragUntilVisible(
        find.byKey(const ValueKey('mine_privacy_policy_entry')),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.text('隐私政策'), findsOneWidget);
      expect(find.text('在系统浏览器中查看数据处理说明'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('关于安册'), 100);
      expect(find.text('关于安册'), findsOneWidget);
      final storageNote = find.text('资料仅保存在本机，不联网，无云同步。');
      await tester.scrollUntilVisible(storageNote, 100);
      expect(
        tester.getTopLeft(find.text('关于安册')).dy,
        lessThan(tester.getTopLeft(storageNote).dy),
      );
    });

    testWidgets('安全设置入口沿用统一的设置行样式', (tester) async {
      final runtime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      await tester.pumpWidget(
        wrapTest(const MaterialApp(home: MinePage()), runtime),
      );
      await tester.pumpAndSettle();

      final appLock = find.byKey(
        const ValueKey('mine_security_settings_app_lock'),
      );
      final appLockIcon = tester.widget<AnchIcon>(
        find.descendant(of: appLock, matching: find.byType(AnchIcon)),
      );
      expect(appLockIcon.size, 22);
      expect(tester.getSize(appLock).height, greaterThanOrEqualTo(64));

      final appLockTitle = find.text('应用锁');
      final appLockDescription = find.text('指纹或 PIN 保护本机资料');
      expect(
        tester.getTopLeft(appLockDescription).dy -
            tester.getBottomRight(appLockTitle).dy,
        2,
      );
      expect(tester.widget<Text>(appLockTitle).style?.fontSize, 14);
      expect(
        tester.widget<Text>(appLockTitle).style?.fontWeight,
        FontWeight.w500,
      );
      expect(tester.widget<Text>(appLockDescription).style?.fontSize, 12);
      expect(tester.widget<Text>(find.text('未启用')).style?.fontSize, 12);
    });

    testWidgets('1. 设置页帮助手册入口打开应用内离线页面', (WidgetTester tester) async {
      final runtime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      await tester.pumpWidget(
        wrapTest(const MaterialApp(home: MinePage()), runtime),
      );
      await tester.pumpAndSettle();

      // 按实际布局滚动到帮助入口。
      final helpEntry = find.text('帮助手册');
      await tester.dragUntilVisible(
        helpEntry,
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // 验证入口标题与描述
      expect(helpEntry, findsOneWidget);
      expect(find.text('离线查看使用、安全与备份说明'), findsOneWidget);

      // 点击后进入应用内页面，不依赖浏览器或网络。
      await tester.tap(helpEntry);
      await tester.pumpAndSettle();

      expect(find.byType(HelpCenterPage), findsOneWidget);
      expect(find.text('卸载安册或清除应用数据会删除本机资料，请先导出备份。'), findsOneWidget);
    });

    testWidgets('2. 验证 HelpCenterPage 必须包含核心离线说明与边界模块', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      final List<String> allTexts = [];
      for (int i = 0; i < 6; i++) {
        final currentTexts = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        for (final text in currentTexts) {
          if (!allTexts.contains(text)) {
            allTexts.add(text);
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      // 验证核心说明模块内容存在于收集到的文本中
      final requiredKeywords = [
        '本地与安全',
        '不需要联网',
        '备份与恢复',
        '应用锁',
        '不应保存的信息',
        '系统通知栏',
      ];

      for (final keyword in requiredKeywords) {
        final found = allTexts.any((text) => text.contains(keyword));
        expect(found, isTrue, reason: '未在页面文本中找到包含 "$keyword" 的内容');
      }
    });

    testWidgets('3. 验证 HelpCenterPage 绝无任何夸大宣传或误导用户的安全文案', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      // 滚动并收集渲染出的所有文本
      final List<String> allTexts = [];
      for (int i = 0; i < 4; i++) {
        final currentTexts = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        for (final text in currentTexts) {
          if (!allTexts.contains(text)) {
            allTexts.add(text);
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      final forbiddenClaims = [
        '正式安全模式已启用',
        '银行级',
        '绝对安全',
        '永不泄露',
        '无法破解',
        '放心录入真实敏感',
      ];

      for (final text in allTexts) {
        for (final claim in forbiddenClaims) {
          expect(
            text.contains(claim),
            isFalse,
            reason: '页面文案中包含了不合规的误导承诺: "$claim" 在段落 "$text" 中',
          );
        }
      }
    });

    testWidgets('4. 验证 HelpCenterPage 绝对不暴露任何底层技术敏感词', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      final List<String> allTexts = [];
      for (int i = 0; i < 4; i++) {
        final currentTexts = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        for (final text in currentTexts) {
          if (!allTexts.contains(text)) {
            allTexts.add(text);
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }

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
        for (final term in forbiddenTechTerms) {
          expect(
            text.toLowerCase().contains(term.toLowerCase()),
            isFalse,
            reason: '页面文案中暴露了底层敏感技术名词: "$term" 在段落 "$text" 中',
          );
        }
      }
    });

    testWidgets('5. 验证 HelpCenterPage 明确列出了禁止录入的 forbidden 信息清单', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      final List<String> allTexts = [];
      for (int i = 0; i < 6; i++) {
        final currentTexts = find
            .byType(Text)
            .evaluate()
            .map((e) => (e.widget as Text).data ?? '')
            .toList();
        for (final text in currentTexts) {
          if (!allTexts.contains(text)) {
            allTexts.add(text);
          }
        }
        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pumpAndSettle();
      }

      final forbiddenFields = ['支付密码', '银行卡登录密码', '动态验证码', 'CVV', '私钥', '助记词'];

      for (final field in forbiddenFields) {
        final found = allTexts.any((text) => text.contains(field));
        expect(found, isTrue, reason: '页面中未包含禁止录入的项目声明: $field');
      }
    });

    testWidgets('6. 最新帮助明确说明外部浏览器与隐私边界，并仅传递固定 HTTPS 地址', (
      WidgetTester tester,
    ) async {
      const channel = MethodChannel('anch/external_url');
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      final latestHelp = find.byKey(const ValueKey('help_online_latest'));
      await tester.dragUntilVisible(
        latestHelp,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();

      expect(find.text('查看最新帮助'), findsOneWidget);
      expect(
        find.text('将在系统浏览器中打开 anch-docs.pages.dev；安册不会上传本机资料'),
        findsOneWidget,
      );

      await tester.tap(latestHelp);
      await tester.pumpAndSettle();

      expect(receivedCall?.method, 'openExternalUrl');
      expect(receivedCall?.arguments, const <String, Object>{
        'url': 'https://anch-docs.pages.dev/',
      });
    });

    testWidgets('6.1 隐私政策通过系统浏览器打开固定 HTTPS 地址', (WidgetTester tester) async {
      const channel = MethodChannel('anch/external_url');
      MethodCall? receivedCall;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            receivedCall = call;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final runtime = RuntimeProvider.create(
        const AnchSecurityRuntimeConfig(
          mode: AnchSecurityMode.dev,
          useEncryptedDatabase: false,
          enableSecureWindow: false,
          enablePrivacyShieldOverlay: false,
          enableAppLockGate: false,
          isFormalBlocked: false,
        ),
      );
      await tester.pumpWidget(
        wrapTest(const MaterialApp(home: MinePage()), runtime),
      );
      await tester.pumpAndSettle();

      final privacyEntry = find.byKey(
        const ValueKey('mine_privacy_policy_entry'),
      );
      await tester.dragUntilVisible(
        privacyEntry,
        find.byType(ListView),
        const Offset(0, -200),
      );
      await tester.ensureVisible(privacyEntry);
      await tester.pumpAndSettle();
      await tester.tap(privacyEntry);
      await tester.pumpAndSettle();

      expect(receivedCall?.method, 'openExternalUrl');
      expect(receivedCall?.arguments, const <String, Object>{
        'url': 'https://anch-docs.pages.dev/privacy/',
      });
    });

    testWidgets('6.2 系统无法打开网页时显示可理解反馈', (tester) async {
      const channel = MethodChannel('anch/external_url');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw PlatformException(code: 'noBrowserAvailable');
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await tester.pumpWidget(const MaterialApp(home: HelpCenterPage()));
      await tester.pumpAndSettle();

      final latestHelp = find.byKey(const ValueKey('help_online_latest'));
      await tester.dragUntilVisible(
        latestHelp,
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await tester.tap(latestHelp);
      await tester.pumpAndSettle();

      expect(find.text('无法打开帮助网页，请稍后重试'), findsOneWidget);
    });

    testWidgets('7. 关于页展示当前版本与准确的离线产品边界', (tester) async {
      registerAnchThirdPartyLicenses();
      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('关于安册'), 100);
      expect(find.text('关于安册'), findsOneWidget);
      expect(find.text('版本 1.0.0（1）'), findsOneWidget);
      expect(find.text('重要资料，整理成册'), findsOneWidget);
      expect(
        find.text('用于在当前设备上按成员整理和查找重要资料。资料管理无需账号或网络，不会自动上传或同步。'),
        findsOneWidget,
      );
      expect(find.text('离线的个人及家庭重要资料管理工具'), findsNothing);
      expect(find.text('无账号、无云同步，日常使用不联网'), findsNothing);
      expect(find.text('第三方许可'), findsOneWidget);
      expect(find.text('查看组件与图标的版权和许可'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('about_open_source_licenses')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
      expect(find.text('1.0.0（1）'), findsOneWidget);
    });

    test('8. Solar 图标许可包含作者、来源、许可和适配说明', () async {
      registerAnchThirdPartyLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      final solarEntry = entries.singleWhere(
        (entry) => entry.packages.contains('Solar Icons 1.2.5'),
      );
      final licenseText = solarEntry.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');

      expect(licenseText, contains('480 Design'));
      expect(licenseText, contains('Solar-Icon-Set'));
      expect(licenseText, contains('CC BY 4.0'));
      expect(licenseText, contains('creativecommons.org/licenses/by/4.0'));
      expect(licenseText, contains('适配说明'));
    });
  });
}
