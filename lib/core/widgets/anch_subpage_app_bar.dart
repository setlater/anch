import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'anch_route_back.dart';

/// 普通子页面统一标题栏。
///
/// 只收口返回按钮、标题和操作区的几何结构；详情、录入和媒体流程仍可按各自
/// 语义使用定制标题栏。
class AnchSubpageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AnchSubpageAppBar({
    super.key,
    required this.title,
    required this.onBack,
    this.actions,
    this.backgroundColor,
    this.foregroundColor,
    this.surfaceTintColor,
    this.systemOverlayStyle,
  });

  final String title;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? surfaceTintColor;
  final SystemUiOverlayStyle? systemOverlayStyle;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 48,
      titleSpacing: 0,
      elevation: 0,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      surfaceTintColor: surfaceTintColor,
      systemOverlayStyle: systemOverlayStyle,
      leading: AnchRouteBack(color: foregroundColor, onBack: onBack),
      title: Text(title),
      actions: actions,
    );
  }
}
