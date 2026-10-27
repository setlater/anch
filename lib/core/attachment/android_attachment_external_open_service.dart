import 'package:flutter/services.dart';

class AttachmentExternalOpenException implements Exception {
  const AttachmentExternalOpenException(this.message);

  final String message;
}

/// 通过 Android 系统应用选择器临时打开附件，不写出明文副本。
class AndroidAttachmentExternalOpenService {
  static const _channel = MethodChannel('anch/attachment_external_open');

  Future<void> open({
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (bytes.isEmpty || mimeType.trim().isEmpty) {
      throw const AttachmentExternalOpenException('附件无效');
    }
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openAttachmentExternally',
        <String, Object>{'bytes': bytes, 'mimeType': mimeType},
      );
      if (opened != true) {
        throw const AttachmentExternalOpenException('无法打开其他应用');
      }
    } on PlatformException catch (error) {
      throw AttachmentExternalOpenException(_messageFor(error.code));
    }
  }

  String _messageFor(String code) {
    switch (code) {
      case 'noAppAvailable':
        return '本机没有可打开该附件的应用';
      default:
        return '无法使用其他应用打开附件';
    }
  }
}
