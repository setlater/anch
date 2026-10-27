import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 仅打开产品内固定声明过的 HTTPS 文档，不携带任何本机资料。
abstract final class AnchExternalDocuments {
  static const helpUrl = 'https://anch-docs.pages.dev/';
  static const privacyPolicyUrl = 'https://anch-docs.pages.dev/privacy/';
  static const host = 'anch-docs.pages.dev';

  static const _channel = MethodChannel('anch/external_url');

  static Future<void> openLatestHelp(BuildContext context) =>
      _open(context, url: helpUrl, failureMessage: '无法打开帮助网页，请稍后重试');

  static Future<void> openPrivacyPolicy(BuildContext context) =>
      _open(context, url: privacyPolicyUrl, failureMessage: '无法打开隐私政策网页，请稍后重试');

  static Future<void> _open(
    BuildContext context, {
    required String url,
    required String failureMessage,
  }) async {
    try {
      final opened = await _channel.invokeMethod<bool>(
        'openExternalUrl',
        <String, Object>{'url': url},
      );
      if (opened == true || !context.mounted) return;
    } on PlatformException {
      if (!context.mounted) return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
