import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/anch_icons.dart';

/// 统一渲染本地 Solar 图标，并继承 Flutter 的 [IconTheme]。
class AnchIcon extends StatelessWidget {
  const AnchIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.semanticLabel,
  });

  final AnchIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 24;
    final resolvedColor = color ?? iconTheme.color ?? Colors.black;

    return SvgPicture.asset(
      icon.assetPath,
      width: resolvedSize,
      height: resolvedSize,
      fit: BoxFit.contain,
      theme: SvgTheme(currentColor: resolvedColor.withValues(alpha: 1)),
      // 半透明颜色仍整体合成，避免双色图标的重叠部分改变透明度。
      colorFilter: resolvedColor.a < 1
          ? ColorFilter.mode(resolvedColor, BlendMode.srcIn)
          : null,
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}
