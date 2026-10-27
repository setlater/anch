@Tags(['platform', 'security'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/main.dart';
import 'package:anch/core/security/android_secure_window_service.dart';
import 'package:anch/core/security/app_startup_failure.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('安全窗口显式验证启动测试', () {
    const channel = MethodChannel('anch/secure_window');
    final List<MethodCall> log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
            log.add(methodCall);
            if (methodCall.method == 'setSecureWindowEnabled') {
              final enabled = methodCall.arguments['enabled'];
              if (enabled == null) {
                throw PlatformException(code: 'INVALID_ARGUMENT');
              }
              if (methodCall.arguments['trigger_error'] == true) {
                throw PlatformException(
                  code: 'CRITICAL_LEAK',
                  message:
                      'databaseKey=0x123, PIN=9999, salt=xyz, verifier=abc',
                );
              }
              return null;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('平台窗口初始化失败时上报脱敏启动阻断，禁止继续打开资料', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            throw PlatformException(code: 'simulated_failure');
          });
      await expectLater(
        initializeSecureWindowForPrototype(
          enableSecureWindow: true,
          service: const AndroidSecureWindowService(),
        ),
        throwsA(isA<AppStartupException>()),
      );
    });

    testWidgets('启动保护失败时不访问安全存储，重试通过后才创建资料会话', (tester) async {
      var failWindow = true;
      var storageReads = 0;
      const storageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            if (failWindow) throw PlatformException(code: 'simulated_failure');
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(storageChannel, (_) async {
            storageReads++;
            throw PlatformException(code: 'simulated_storage_failure');
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(storageChannel, null),
      );
      await tester.pumpWidget(
        const AnchBootstrapRoot(
          config: AnchSecurityRuntimeConfig(
            mode: AnchSecurityMode.formal,
            useEncryptedDatabase: true,
            enableSecureWindow: true,
            enablePrivacyShieldOverlay: true,
            enableAppLockGate: true,
            isFormalBlocked: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(storageReads, 0);
      expect(find.text('无法启用屏幕保护'), findsOneWidget);
      failWindow = false;
      await tester.ensureVisible(find.text('重试屏幕保护'));
      await tester.tap(find.text('重试屏幕保护'));
      await tester.pumpAndSettle();
      expect(storageReads, greaterThan(0));
      expect(find.text('无法启用屏幕保护'), findsNothing);
      expect(find.text('无法打开本机资料'), findsOneWidget);
    });

    test(
      '验证 1. enableSecureWindow = false 时，不发起 MethodChannel 原生窗口设置调用',
      () async {
        final service = const AndroidSecureWindowService();
        await initializeSecureWindowForPrototype(
          enableSecureWindow: false,
          service: service,
        );

        expect(log.isEmpty, isTrue);
      },
    );

    test(
      '验证 2. enableSecureWindow = true 时，发起 MethodChannel 调用并传入启用参数',
      () async {
        final service = const AndroidSecureWindowService();
        await initializeSecureWindowForPrototype(
          enableSecureWindow: true,
          service: service,
        );

        expect(log.length, 1);
        expect(log.first.method, 'setSecureWindowEnabled');
        expect(log.first.arguments, {'enabled': true});
      },
    );

    test('验证 3. 原生异常仅上报脱敏启动错误且不输出日志', () async {
      final errorChannel = const MethodChannel('anch/secure_window_error_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errorChannel, (
            MethodCall methodCall,
          ) async {
            throw PlatformException(
              code: 'CRITICAL_LEAK',
              message:
                  '泄漏堆栈: databaseKey=0xABC, PIN=8888, salt=foo, verifier=bar',
            );
          });

      final service = AndroidSecureWindowService(channel: errorChannel);

      final printedLogs = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) printedLogs.add(message);
      };
      try {
        await expectLater(
          initializeSecureWindowForPrototype(
            enableSecureWindow: true,
            service: service,
          ),
          throwsA(
            isA<AppStartupException>()
                .having(
                  (error) => error.type,
                  'type',
                  AppStartupFailureType.screenProtectionUnavailable,
                )
                .having(
                  (error) => error.toString(),
                  'sanitized error',
                  isNot(
                    anyOf(
                      contains('0xABC'),
                      contains('8888'),
                      contains('CRITICAL_LEAK'),
                    ),
                  ),
                ),
          ),
        );
        expect(printedLogs, isEmpty);
      } finally {
        debugPrint = originalDebugPrint;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(errorChannel, null);
      }
    });

    testWidgets('验证 4. 无论开关如何，均不影响主界面渲染，且不含“正式安全模式”等误导性文案', (
      WidgetTester tester,
    ) async {
      // 模拟启动
      final mainApp = MaterialApp(home: Scaffold(body: const Text('安册启动验证页')));

      await tester.pumpWidget(mainApp);
      expect(find.text('安册启动验证页'), findsOneWidget);

      final allTextWidgets = find.byType(Text);
      final elements = allTextWidgets.evaluate();

      for (final element in elements) {
        final widget = element.widget as Text;
        final textData = widget.data ?? '';
        expect(textData.contains('已正式安全准入'), isFalse);
        expect(textData.contains('正式安全模式已启用'), isFalse);
      }
    });
  });
}
