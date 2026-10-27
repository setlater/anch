import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 仅打开固定的 HTTPS 版本发布页，不携带任何本机资料。
abstract final class AnchExternalDocuments {
  static const latestReleaseUrl =
      'https://github.com/setlater/anch/releases/latest';

  static const _channel = MethodChannel('anch/external_url');

  static Future<void> openLatestRelease(BuildContext context) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openExternalUrl',
        <String, Object>{'url': latestReleaseUrl},
      );
      if (opened == true || !context.mounted) return;
    } on PlatformException {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('无法打开版本发布页，请稍后重试')));
  }
}
