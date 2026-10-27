import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'dart:math' as math;

import 'anch_adaptive_layout.dart';

/// 安册统一页面脚手架。
///
/// 职责：
/// - 统一主题背景色
/// - 统一 SafeArea
/// - 支持底部导航和滚动内容
/// - 不写入任何业务保存逻辑
class AnchAppScaffold extends StatelessWidget {
  const AnchAppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.maxContentWidth = AnchLayoutBreakpoints.maxContentWidth,
  });

  /// 页面标题栏（可选）
  final PreferredSizeWidget? appBar;

  /// 页面主体内容
  final Widget body;
  final double maxContentWidth;

  /// 底部导航栏（可选）
  final Widget? bottomNavigationBar;

  /// 浮动按钮（可选）
  final Widget? floatingActionButton;

  /// 是否随键盘弹出调整高度
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final widthClass = AnchLayoutBreakpoints.forWindowWidth(
      mediaQuery.size.width,
    );
    final availableHeight = math
        .max(
          0.0,
          mediaQuery.size.height -
              mediaQuery.padding.vertical -
              mediaQuery.viewInsets.bottom,
        )
        .toDouble();
    final heightClass = availableHeight > 0
        ? AnchLayoutBreakpoints.forWindowHeight(availableHeight)
        : AnchWindowHeightClass.medium;

    return AnchLayoutScope(
      widthClass: widthClass,
      heightClass: heightClass,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: isDark
                  ? Brightness.light
                  : Brightness.dark,
              statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            ),
        child: Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: appBar,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final contentWidth = math.min(
                  constraints.maxWidth,
                  maxContentWidth,
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: contentWidth,
                    height: constraints.maxHeight.isFinite
                        ? constraints.maxHeight
                        : null,
                    child: body,
                  ),
                );
              },
            ),
          ),
          bottomNavigationBar: bottomNavigationBar,
          floatingActionButton: floatingActionButton,
        ),
      ),
    );
  }
}
