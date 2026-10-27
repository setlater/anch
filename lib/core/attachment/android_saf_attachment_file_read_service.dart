import 'package:flutter/services.dart';

class AttachmentFileReadResult {
  const AttachmentFileReadResult({
    required this.bytes,
    required this.originalName,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String originalName;
  final String mimeType;
}

abstract interface class AttachmentFileReadService {
  Future<AttachmentFileReadResult?> readFile();

  Future<void> clearSessionPickerLocation();
}

/// 通过 Android SAF 读取一次性附件字节；不向 Dart 暴露 Uri 或完整路径。
class AndroidSafAttachmentFileReadService implements AttachmentFileReadService {
  AndroidSafAttachmentFileReadService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const _channelName = 'anch/attachment_file_read';

  final MethodChannel _channel;

  @override
  Future<AttachmentFileReadResult?> readFile() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'openAttachmentDocumentAndRead',
      );
      if (result == null) return null;
      final bytes = result['bytes'];
      final originalName = result['originalName'];
      final mimeType = result['mimeType'];
      if (bytes is! Uint8List ||
          originalName is! String ||
          originalName.isEmpty ||
          mimeType is! String ||
          mimeType.isEmpty) {
        throw const AttachmentFileReadException('系统文件返回数据无效。');
      }
      return AttachmentFileReadResult(
        bytes: bytes,
        originalName: originalName,
        mimeType: mimeType,
      );
    } on PlatformException catch (error) {
      if (error.code == 'userCancelled') return null;
      throw AttachmentFileReadException(error.message ?? '无法读取所选附件。');
    }
  }

  @override
  Future<void> clearSessionPickerLocation() async {
    try {
      await _channel.invokeMethod<void>('clearAttachmentPickerLocation');
    } on MissingPluginException {
      // 非 Android 平台没有该短暂目录引用，无需处理。
    } on PlatformException {
      // 清理仅用于体验优化，不影响附件读取或安全清理主流程。
    }
  }
}

class AttachmentFileReadException implements Exception {
  const AttachmentFileReadException(this.message);

  final String message;
}
