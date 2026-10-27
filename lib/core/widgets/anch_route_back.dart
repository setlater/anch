import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_icons.dart';
import 'anch_icon.dart';

/// 固定定位的路由返回控件。
///
/// 只呈现返回箭头，不使用 Material 按钮视觉；触控范围始终保持 48 逻辑像素。
class AnchRouteBack extends StatelessWidget {
  const AnchRouteBack({super.key, required this.onBack, this.color});

  final VoidCallback? onBack;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final enabled = onBack != null;
    final iconColor = color ?? context.anchColors.textPrimary;

    return SizedBox(
      width: 48,
      height: 48,
      child: Semantics(
        label: '返回',
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onBack,
          child: Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: AnchIcon(AnchIcons.back, size: 24, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}
