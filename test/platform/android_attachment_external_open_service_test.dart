@Tags(['platform'])
library;

import 'package:anch/core/attachment/android_attachment_external_open_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anch/attachment_external_open');
  final service = AndroidAttachmentExternalOpenService();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final bytes =
              (call.arguments as Map<Object?, Object?>)['bytes'] as Uint8List;
          if (bytes.length == 2) {
            throw PlatformException(code: 'noAppAvailable');
          }
          return true;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('仅通过内存负荷和 MIME 类型请求系统应用选择器', () async {
    await service.open(
      bytes: Uint8List.fromList([1]),
      mimeType: 'application/pdf',
    );
  });

  test('没有可处理附件的应用时返回脱敏错误', () async {
    expect(
      () => service.open(
        bytes: Uint8List.fromList([1, 2]),
        mimeType: 'application/pdf',
      ),
      throwsA(
        isA<AttachmentExternalOpenException>().having(
          (error) => error.message,
          'message',
          '本机没有可打开该附件的应用',
        ),
      ),
    );
  });
}
