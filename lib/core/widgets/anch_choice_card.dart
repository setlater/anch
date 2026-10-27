import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';

/// 安册选择卡片。
///
/// 用途：成员选择、资料大类选择、模板选择。
///
/// 支持 normal / selected 两种状态；使用线条与选中标记建立层级，
/// 不为普通图标增加装饰底块。
/// 在页面的 Material 内使用，避免网格中逐卡片重复创建材质与文本动画。
class AnchChoiceCard extends StatelessWidget {
  const AnchChoiceCard({
    super.key,
    required this.title,
    this.description,
    this.leading,
    this.icon,
    this.iconLabel,
    this.tag,
    this.selected = false,
    this.compact = false,
    this.onTap,
  });

  /// 选项标题
  final String title;

  /// 选项描述（可选）
  final String? description;

  /// 自定义前导组件。成员选择等需要专属视觉时优先使用。
  final Widget? leading;

  /// 图标（可选）
  final AnchIconData? icon;

  /// 图标区显示的文字标签（可选，图标不存在时显示）
  final String? iconLabel;

  /// 小标签文字（可选），如"推荐"
  final String? tag;

  /// 是否选中
  final bool selected;

  /// 资料类型网格采用上图下文并收紧内容边距。
  final bool compact;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.anchColors;
    final iconArea =
        leading ??
        _IconArea(icon: icon, label: iconLabel, selected: compact && selected);
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (tag != null) ...[
              const SizedBox(width: AnchSpacing.sm),
              _TagLabel(label: tag!, selected: selected),
            ],
          ],
        ),
        if (description != null) ...[
          const SizedBox(height: 2),
          Text(
            description!,
            style: textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnchRadius.sm),
      child: AnimatedContainer(
        constraints: const BoxConstraints(minHeight: 56),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AnchSpacing.md : AnchSpacing.lg,
          vertical: AnchSpacing.md,
        ),
        decoration: BoxDecoration(
          color: selected ? colors.accentSoft : colors.surface,
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          border: Border.all(
            color: selected ? colors.accent : colors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [iconArea, const SizedBox(height: 4), textContent],
              )
            : Row(
                children: [
                  iconArea,
                  const SizedBox(width: AnchSpacing.md),
                  Expanded(child: textContent),
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: selected ? 1.0 : 0.0,
                    child: AnchIcon(
                      AnchIcons.check,
                      size: 20,
                      color: colors.accent,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _IconArea extends StatelessWidget {
  const _IconArea({this.icon, this.label, required this.selected});

  final AnchIconData? icon;
  final String? label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return SizedBox(
      width: 28,
      height: 28,
      child: Center(
        child: selected || icon != null
            ? AnchIcon(
                selected ? AnchIcons.check : icon!,
                size: 22,
                color: selected ? colors.accent : colors.documentIcon,
              )
            : Text(
                label ?? '册',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.documentIcon,
                ),
              ),
      ),
    );
  }
}

class _TagLabel extends StatelessWidget {
  const _TagLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: selected ? colors.accentDeep : colors.textMuted,
      ),
    );
  }
}
