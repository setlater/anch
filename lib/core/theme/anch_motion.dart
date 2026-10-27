import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 安册的非必要动效策略。
///
/// 普通 Android 路由继续采用 Flutter 的预测返回实现；系统要求减少
/// 动态效果时，页面与底部弹层立即切换，避免用装饰性动效延迟操作。
abstract final class AnchMotion {
  AnchMotion._();

  static const PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: _AnchAndroidPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: ZoomPageTransitionsBuilder(),
      TargetPlatform.linux: ZoomPageTransitionsBuilder(),
    },
  );

  /// 供所有模态底部弹层复用的系统无障碍动画设置。
  static AnimationStyle? bottomSheetAnimationStyle(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null;
}

class _AnchAndroidPageTransitionsBuilder extends PageTransitionsBuilder {
  const _AnchAndroidPageTransitionsBuilder();

  static const _platformBuilder = PredictiveBackPageTransitionsBuilder();

  @override
  Duration get transitionDuration => _platformBuilder.transitionDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return _platformBuilder.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
