@Tags(['platform'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/android_secure_window_service.dart';

class MockGenericErrorChannel extends MethodChannel {
  const MockGenericErrorChannel() : super('anch/secure_window_generic_error_test');

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    throw Exception('Raw dart exception');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AndroidSecureWindowService 单元测试', () {
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
          return null;
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('验证 1. setSecureWindowEnabled(true) 正常调用并传递参数', () async {
      const service = AndroidSecureWindowService();
      await service.setSecureWindowEnabled(true);

      expect(log.length, 1);
      expect(log.first.method, 'setSecureWindowEnabled');
      expect(log.first.arguments, {'enabled': true});
    });

    test('验证 2. setSecureWindowEnabled(false) 正常调用并传递参数', () async {
      const service = AndroidSecureWindowService();
      await service.setSecureWindowEnabled(false);

      expect(log.length, 1);
      expect(log.first.method, 'setSecureWindowEnabled');
      expect(log.first.arguments, {'enabled': false});
    });

    test('验证 3. Native 发生 PlatformException 时，服务进行脱敏抛出，不泄露敏感名词', () async {
      const errorChannel = MethodChannel('anch/secure_window_error_test');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(errorChannel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NATIVE_CRASH',
          message: 'Sensitive databaseKey=0x999, PIN=8888, salt=xyz, verifier=abc was leaked',
          details: 'Leak details',
        );
      });

      final service = AndroidSecureWindowService(channel: errorChannel);

      try {
        await service.setSecureWindowEnabled(true);
        fail('Expected PlatformException to be thrown');
      } on PlatformException catch (e) {
        expect(e.code, 'SECURE_WINDOW_ERROR');
        expect(e.message, '更新窗口安全状态失败');
        
        final errStr = e.toString();
        expect(errStr.contains('databaseKey'), isFalse);
        expect(errStr.contains('PIN'), isFalse);
        expect(errStr.contains('salt'), isFalse);
        expect(errStr.contains('verifier'), isFalse);
        expect(errStr.contains('0x999'), isFalse);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(errorChannel, null);
      }
    });

    test('验证 4. Native 发生未知 Exception 时，服务进行安全脱敏抛出', () async {
      const genericErrorChannel = MockGenericErrorChannel();
      final service = AndroidSecureWindowService(channel: genericErrorChannel);

      try {
        await service.setSecureWindowEnabled(true);
        fail('Expected PlatformException to be thrown');
      } on PlatformException catch (e) {
        expect(e.code, 'SECURE_WINDOW_UNKNOWN_ERROR');
        expect(e.message, '更新窗口安全状态遇到未知异常');
      }
    });
  });
}
