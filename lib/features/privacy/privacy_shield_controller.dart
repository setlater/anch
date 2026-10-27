import 'package:flutter/foundation.dart';

/// 防窥遮罩状态来源枚举。
enum PrivacyShieldSource {
  /// 应用生命周期（切后台）
  lifecycle,

  /// 详情页敏感字段展开
  itemDetail,

  /// 锁屏 PIN 输入
  appLockInput,

  /// PIN 码设置
  appPinSetup,

  /// 备份导出密码输入
  backupExport,

  /// 备份恢复密码输入
  backupRestore,

  /// 覆盖恢复确认流程
  restoreConfirming,

  /// 手动/其它原型场景
  manual,
}

/// Flutter 后台防窥遮罩控制器。
///
/// 升级为基于多来源 [PrivacyShieldSource] 控制的模型。
/// 只要任一来源处于活跃 (active)，遮罩可见性即为 true；
/// 只有当所有活跃来源都被清空后，遮罩可见性才恢复为 false。
class PrivacyShieldController extends ValueNotifier<bool> {
  PrivacyShieldController({bool initialVisible = false})
    : _activeSources = initialVisible
          ? {PrivacyShieldSource.manual}
          : <PrivacyShieldSource>{},
      super(initialVisible);

  final Set<PrivacyShieldSource> _activeSources;
  int _lifecycleShieldSuppressionCount = 0;

  /// 当前是否处于遮罩展示状态
  bool get isVisible => value;

  /// 当前活跃的防窥来源集合
  Set<PrivacyShieldSource> get activeSources =>
      Set.unmodifiable(_activeSources);

  /// 当前是否正处于受控系统选择器往返中。
  bool get isLifecycleShieldSuppressed => _lifecycleShieldSuppressionCount > 0;

  /// 系统生命周期进入后台时请求展示遮罩。
  ///
  /// 受控系统选择器覆盖应用时，应用内容并未重新暴露，因此避免在返回首帧闪出遮罩。
  void showForLifecycle() {
    if (isLifecycleShieldSuppressed) return;
    show(PrivacyShieldSource.lifecycle);
  }

  /// 在受控系统选择器往返期间暂时抑制生命周期遮罩。
  ///
  /// 仅用于系统文件／媒体选择器；不会影响安全窗口、AppLock 或其它遮罩来源。
  Future<T> runWhileLifecycleShieldSuppressed<T>(
    Future<T> Function() action,
  ) async {
    _lifecycleShieldSuppressionCount++;
    clearSource(PrivacyShieldSource.lifecycle);
    try {
      return await action();
    } finally {
      _lifecycleShieldSuppressionCount--;
    }
  }

  /// 展现遮罩，可指定具体的防窥来源，默认是 manual
  void show([PrivacyShieldSource source = PrivacyShieldSource.manual]) {
    _activeSources.add(source);
    _syncVisible();
  }

  /// 隐藏遮罩，可指定具体的防窥来源，默认是 manual
  void hide([PrivacyShieldSource source = PrivacyShieldSource.manual]) {
    _activeSources.remove(source);
    _syncVisible();
  }

  /// 清除指定来源的防窥状态
  void clearSource(PrivacyShieldSource source) {
    _activeSources.remove(source);
    _syncVisible();
  }

  /// 清除所有来源的防窥状态
  void clearAll() {
    _activeSources.clear();
    _syncVisible();
  }

  /// 保持向后兼容的 clear 别名，重定向至 clearAll
  void clear() => clearAll();

  /// 根据当前活跃来源集合同步 value 值
  void _syncVisible() {
    final nextVisible = _activeSources.isNotEmpty;
    if (value != nextVisible) {
      value = nextVisible;
    }
  }

  @override
  String toString() {
    return 'PrivacyShieldController(isVisible: $isVisible, activeSources: ${_activeSources.map((e) => e.name).toList()})';
  }
}
