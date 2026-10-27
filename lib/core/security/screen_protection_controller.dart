import 'dart:async';

import 'package:flutter/widgets.dart';

import 'android_secure_window_service.dart';
import 'screen_protection_settings_manager.dart';

class ScreenProtectionController extends ChangeNotifier {
  factory ScreenProtectionController({
    required ScreenProtectionSettingsManager settingsManager,
    required SecureWindowService secureWindowService,
  }) => ScreenProtectionController._(settingsManager, secureWindowService);

  ScreenProtectionController._(
    this._settingsManager,
    this._secureWindowService,
  );

  final ScreenProtectionSettingsManager _settingsManager;
  final SecureWindowService _secureWindowService;
  final Map<Object, bool> _contentSources = <Object, bool>{};

  ScreenProtectionMode _mode = ScreenProtectionMode.sensitiveOnly;
  bool _isBackgrounded = false;
  bool? _lastAppliedProtection;
  Future<void> _pendingApply = Future<void>.value();
  bool _hasProtectionFailure = false;
  bool _applyingProtection = false;
  bool _notificationPending = false;
  bool _disposed = false;

  ScreenProtectionMode get mode => _mode;
  bool get hasProtectionFailure => _hasProtectionFailure;
  bool get isForegroundProtected =>
      !_hasProtectionFailure &&
      !_applyingProtection &&
      _lastAppliedProtection == true;

  bool requiresProtection(bool sensitive) =>
      _mode == ScreenProtectionMode.always ||
      (_mode == ScreenProtectionMode.sensitiveOnly && sensitive);

  /// 当前窗口前台内容是否需要禁止截图和录屏。
  ///
  /// 后台最近任务快照由 Android 原生生命周期立即保护，不能等待
  /// Flutter 生命周期异步回调再切换窗口标志。
  bool get _shouldProtectForeground =>
      _mode == ScreenProtectionMode.always ||
      (_mode == ScreenProtectionMode.sensitiveOnly &&
          _contentSources.isNotEmpty &&
          _contentSources.values.last);

  /// 当前状态下是否应受保护，包含由原生负责的后台任务快照保护。
  bool get shouldProtect => _isBackgrounded || _shouldProtectForeground;

  Future<void> initialize() async {
    _mode = await _settingsManager.loadMode();
    _notifyStateChanged();
    await _applyProtection();
  }

  Future<void> setMode(ScreenProtectionMode mode) async {
    if (_mode == mode || _hasProtectionFailure) return;
    await _settingsManager.saveMode(mode);
    _mode = mode;
    _notifyStateChanged();
    await _applyProtection();
  }

  Future<void> setContentSensitivity(Object source, bool? sensitive) async {
    if (sensitive == null) {
      if (_contentSources.remove(source) == null) return;
    } else {
      if (_contentSources[source] == sensitive &&
          _contentSources.keys.last == source) {
        return;
      }
      _contentSources.remove(source);
      _contentSources[source] = sensitive;
    }
    await _applyProtection();
  }

  Future<void> handleLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.inactive) return;
    final backgrounded = switch (state) {
      AppLifecycleState.resumed => false,
      AppLifecycleState.hidden ||
      AppLifecycleState.paused ||
      AppLifecycleState.detached => true,
      AppLifecycleState.inactive => _isBackgrounded,
    };
    if (_isBackgrounded == backgrounded) return;
    _isBackgrounded = backgrounded;
    await _applyProtection();
  }

  Future<void> retryProtection() => _applyProtection(retry: true);

  Future<void> _applyProtection({bool retry = false}) async {
    final next = _shouldProtectForeground;
    _notifyStateChanged();
    _pendingApply = _pendingApply.then((_) async {
      if (_disposed || (_hasProtectionFailure && !retry)) return;
      if (next != _shouldProtectForeground) return;
      if (!_hasProtectionFailure && _lastAppliedProtection == next) return;
      _applyingProtection = true;
      _notifyStateChanged();
      try {
        await _secureWindowService.setSecureWindowEnabled(next);
        _lastAppliedProtection = next;
        _hasProtectionFailure = false;
      } catch (_) {
        _lastAppliedProtection = null;
        _hasProtectionFailure = true;
      } finally {
        _applyingProtection = false;
      }
      _notifyStateChanged();
    });
    await _pendingApply;
  }

  void _notifyStateChanged() {
    if (_disposed || _notificationPending) return;
    _notificationPending = true;
    scheduleMicrotask(() {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
