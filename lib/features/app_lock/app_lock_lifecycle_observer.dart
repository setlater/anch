import 'package:flutter/widgets.dart';
import '../../core/security/app_lock_lifecycle_controller.dart';

/// 全局生命周期监听组件原型。
///
/// 职责：
/// 1. 挂载在 Widget 树中，混入 [WidgetsBindingObserver] 监听全局生命周期事件。
/// 2. 只负责将 Flutter [AppLifecycleState] 生命周期转给 [AppLockLifecycleController]。
///
/// 严格边界：
/// 1. 不在该组件内读取 Secure Storage。
/// 2. 不在该组件内创建 [AppLockController]。
/// 3. 不在该组件内调用 bootstrap。
/// 4. 不在默认路径使用该组件。
class AppLockLifecycleObserver extends StatefulWidget {
  const AppLockLifecycleObserver({
    required this.lifecycleController,
    required this.child,
    super.key,
  });

  final AppLockLifecycleController lifecycleController;
  final Widget child;

  @override
  State<AppLockLifecycleObserver> createState() =>
      _AppLockLifecycleObserverState();
}

class _AppLockLifecycleObserverState extends State<AppLockLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.lifecycleController.handleLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.lifecycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
