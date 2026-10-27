@Tags(['platform'])
library;

import 'package:anch/core/attachment/android_saf_attachment_file_read_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('anch/attachment_file_read');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('附件 SAF 读取只返回字节、文件名和 MIME 类型', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'openAttachmentDocumentAndRead');
          return <String, dynamic>{
            'bytes': Uint8List.fromList([1, 2, 3]),
            'originalName': 'attachment.pdf',
            'mimeType': 'application/pdf',
          };
        });

    final result = await AndroidSafAttachmentFileReadService(
      channel: channel,
    ).readFile();

    expect(result, isNotNull);
    expect(result!.bytes, Uint8List.fromList([1, 2, 3]));
    expect(result.originalName, 'attachment.pdf');
    expect(result.mimeType, 'application/pdf');
  });

  test('用户取消 SAF 选择时不返回附件', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'userCancelled');
        });

    final result = await AndroidSafAttachmentFileReadService(
      channel: channel,
    ).readFile();

    expect(result, isNull);
  });

  test('附件选择会话结束时通知 Android 清除目录引用', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'clearAttachmentPickerLocation');
          return null;
        });

    await AndroidSafAttachmentFileReadService(
      channel: channel,
    ).clearSessionPickerLocation();
  });
}
