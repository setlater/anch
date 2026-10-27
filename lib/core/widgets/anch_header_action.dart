import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_icons.dart';
import 'anch_icon.dart';

/// 页面标题区的平面操作控件。
///
/// 统一新增、编辑、回首页和关闭等标题操作的图标尺寸与触控范围。
class AnchHeaderAction extends StatelessWidget {
  const AnchHeaderAction({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
    this.color,
    this.label,
  });

  final AnchIconData icon;
  final String semanticLabel;
  final VoidCallback? onTap;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    if (label != null) {
      return Semantics(
        container: true,
        label: semanticLabel,
        button: true,
        enabled: enabled,
        onTap: onTap,
        excludeSemantics: true,
        child: TextButton.icon(
          onPressed: onTap,
          icon: AnchIcon(icon, size: 20),
          label: Text(label!),
          style: TextButton.styleFrom(
            foregroundColor: context.anchColors.accent,
            backgroundColor: context.anchColors.accentSoft,
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            textStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 48,
      height: 48,
      child: Semantics(
        label: semanticLabel,
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.38,
              child: AnchIcon(
                icon,
                size: 20,
                color: color ?? context.anchColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
