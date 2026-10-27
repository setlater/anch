import 'package:flutter/widgets.dart';
import 'app_lock_controller.dart';
import 'app_lock_preferences_manager.dart';

/// App 生命周期锁定控制器原型。
///
/// 职责：
/// 将 Flutter [AppLifecycleState] 事件转换为 [AppLockController] 的
/// [AppLockController.markBackgrounded] / [AppLockController.markForegrounded] 调用，
/// 实现「每次回到安册时」的自动锁定。
///
/// **使用方式**：
/// 实例化后调用 [handleLifecycleState] 传入生命周期状态。
/// 若需要接入 Flutter 生命周期，搭配 [WidgetsBindingObserver] 使用。
///
/// **严格边界**：
/// - 本控制器不注册到 `main.dart` 或 MainShell。
/// - 本控制器不启用正式 App 锁。
/// - 本控制器不处理最近任务遮罩、FLAG_SECURE。
/// - 本控制器不执行任何数据清除操作。
/// - 本阶段禁止录入真实敏感资料。
class AppLockLifecycleController {
  AppLockLifecycleController({
    required this._appLockController,
    this.autoLockMode = AppLockAutoLockMode.everyForeground,
    this.shouldLockOnForeground = true,
    int Function()? nowMillis,
  }) : _nowMillis = nowMillis ?? (() => DateTime.now().millisecondsSinceEpoch);

  final AppLockController _appLockController;

  /// 返回前台时的自动锁定模式。
  AppLockAutoLockMode autoLockMode;

  void updateAutoLockMode(AppLockAutoLockMode value) {
    autoLockMode = value;
  }

  /// 是否在前台重新锁定。
  /// 对于 unlockedForPrototype 等用户未开启应用锁决策，置为 false 以防止被生命周期事件误锁。
  bool shouldLockOnForeground;

  void updateShouldLockOnForeground(bool value) {
    shouldLockOnForeground = value;
  }

  /// 当前时间戳提供函数，默认使用系统时间，测试时可注入固定值。
  final int Function() _nowMillis;

  AppLifecycleState? _lastState;
  bool _isWakingUp = false;
  int _systemUiLockSuppressionCount = 0;

  Future<T> runWhileSystemUiLockSuppressed<T>(
    Future<T> Function() action,
  ) async {
    _systemUiLockSuppressionCount++;
    try {
      return await action();
    } finally {
      _systemUiLockSuppressionCount--;
      if (_systemUiLockSuppressionCount == 0) {
        _isWakingUp = false;
        _lastState = AppLifecycleState.resumed;
        _appLockController.markForegrounded(
          _nowMillis(),
          timeoutMillis: 999999999999,
        );
      }
    }
  }

  /// 处理生命周期状态变化。
  ///
  /// 状态映射规则：
  /// - [AppLifecycleState.inactive]：仅代表短暂失焦（如通知栏展开），不记录后台。
  /// - [AppLifecycleState.hidden]／[AppLifecycleState.paused]：App 不再可见，记录后台。
  /// - [AppLifecycleState.resumed]：仅「每次回到安册时」模式触发锁定。
  /// - [AppLifecycleState.detached]：本批不特殊处理，后续评估是否需要清理资源。
  void handleLifecycleState(AppLifecycleState state) {
    if (_appLockController.isSystemAuthenticationInProgress) return;
    if (_systemUiLockSuppressionCount > 0) {
      _lastState = state;
      if (state == AppLifecycleState.resumed) _isWakingUp = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _isWakingUp = false;
    } else if (_lastState == AppLifecycleState.paused &&
        state != AppLifecycleState.paused) {
      _isWakingUp = true;
    }
    _lastState = state;

    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // 记录进入后台的时间点。如果是从后台唤醒过程中 (hidden/inactive 过渡)，则不触发覆盖，防止重置时间差
        if (!_isWakingUp) {
          _appLockController.markBackgrounded(_nowMillis());
        }
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.resumed:
        // 通知栏、系统弹窗等只会经过 inactive，不会触发锁定。
        _appLockController.markForegrounded(
          _nowMillis(),
          timeoutMillis:
              shouldLockOnForeground &&
                  autoLockMode == AppLockAutoLockMode.everyForeground
              ? 0
              : 999999999999,
        );
      case AppLifecycleState.detached:
        // 本批不特殊处理 detached，后续评估是否需要清理资源。
        break;
    }
  }

  /// 释放资源。
  ///
  /// 本控制器本身不持有 listener，[dispose] 提供给外部调用统一生命周期管理。
  /// 若搭配 [WidgetsBindingObserver] 使用，应在此处调用
  /// `WidgetsBinding.instance.removeObserver(observer)`。
  void dispose() {
    // 本批纯控制器无需额外清理，外部 observer 由调用方负责移除。
  }
}
