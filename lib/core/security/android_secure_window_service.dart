import 'package:flutter/services.dart';

abstract interface class SecureWindowService {
  Future<void> setSecureWindowEnabled(bool enabled);
}

/// Android 窗口安全（FLAG_SECURE）控制服务原型。
///
/// 用于在 Android 平台上开启或清除 WindowManager.LayoutParams.FLAG_SECURE，
/// 以实现防截屏、防录屏和最近任务列表卡片遮挡。
///
/// **严格边界限制**：
/// - 默认不启用，默认启动路径绝不调用。
/// - PlatformException 必须脱敏处理，过滤可能的内存泄漏和敏感日志。
class AndroidSecureWindowService implements SecureWindowService {
  const AndroidSecureWindowService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('anch/secure_window');

  final MethodChannel _channel;

  /// 设置安全窗口状态。
  ///
  /// [enabled] 为 true 代表启用安全防窥防护；
  /// [enabled] 为 false 代表清除该防护。
  ///
  /// 调用发生 PlatformException 时，会抓取、脱敏并重新抛出一个安全的 [PlatformException]。
  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setSecureWindowEnabled', {
        'enabled': enabled,
      });
    } on PlatformException catch (e) {
      // 抛出完全脱敏后的异常，保护内部 PIN/databaseKey/salt/verifier 堆栈
      throw PlatformException(
        code: 'SECURE_WINDOW_ERROR',
        message: '更新窗口安全状态失败',
        details: 'Native error code: ${e.code}',
      );
    } catch (e) {
      throw PlatformException(
        code: 'SECURE_WINDOW_UNKNOWN_ERROR',
        message: '更新窗口安全状态遇到未知异常',
      );
    }
  }
}
