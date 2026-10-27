import 'package:flutter/material.dart';
import 'runtime_context.dart';

/// 运行时上下文在组件树上的 Scope 注入器。
class RuntimeScope extends InheritedWidget {
  final RuntimeContext runtime;

  const RuntimeScope({super.key, required this.runtime, required super.child});

  /// 获取上下文中的 RuntimeContext，若不存在则抛出异常以保证严格调用契约。
  static RuntimeContext of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RuntimeScope>();
    assert(scope != null, 'No RuntimeScope found in context');
    return scope!.runtime;
  }

  @override
  bool updateShouldNotify(RuntimeScope oldWidget) {
    return runtime != oldWidget.runtime;
  }
}
