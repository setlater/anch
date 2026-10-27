import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../theme/anch_assets.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';

/// 安册空状态组件。
///
/// 用途：首页空资料、成员下无资料、类型下无资料、搜索无结果等场景。
///
/// 设计原则：
/// - 克制说明，不使用廉价插画
/// - 用低调几何图形作为空状态图示
/// - 提供明确行动按钮
/// - 不使用"暂无数据"裸文案
class AnchEmptyState extends StatelessWidget {
  const AnchEmptyState({
    super.key,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.padding,
  });

  /// 首次加载失败与刷新失败不冒充空数据；调用方保留已有内容。
  static Widget loadError({
    required VoidCallback onRetry,
    bool hasContent = false,
  }) {
    if (hasContent) {
      return MaterialBanner(
        content: const Text('刷新失败，仍显示上次内容'),
        actions: [TextButton(onPressed: onRetry, child: const Text('重新加载'))],
      );
    }
    return AnchEmptyState(
      title: '加载资料失败',
      description: '请重新加载，已有资料不会被修改',
      actionLabel: '重新加载',
      onAction: onRetry,
      icon: AnchIcons.error,
    );
  }

  /// 空状态标题，如"还没有任何资料"
  final String title;

  /// 说明文字（可选），如"从首页新增第一份重要资料"
  final String? description;

  /// 行动按钮文字（可选），如"新增资料"
  final String? actionLabel;

  /// 行动按钮回调（可选）
  final VoidCallback? onAction;

  /// 自定义图标（可选），不传则使用默认图示
  final AnchIconData? icon;

  /// 自定义内边距（可选）
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.anchColors;

    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding:
            padding ??
            const EdgeInsets.symmetric(
              horizontal: AnchSpacing.page,
              vertical: AnchSpacing.xxl,
            ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 空状态图示
            _EmptyIllustration(icon: icon),

            const SizedBox(height: AnchSpacing.xl),

            // 标题
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),

            // 说明
            if (description != null) ...[
              const SizedBox(height: AnchSpacing.sm),
              Text(
                description!,
                style: textTheme.bodySmall?.copyWith(
                  height: 1.6,
                  color: colors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],

            // 行动按钮
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AnchSpacing.xxl),
              _EmptyActionButton(label: actionLabel!, onTap: onAction!),
            ],
          ],
        ),
      ),
    );
  }
}

/// 空状态几何图示，低调轻量
class _EmptyIllustration extends StatelessWidget {
  const _EmptyIllustration({this.icon});

  final AnchIconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: colors.accentSoft,
        borderRadius: BorderRadius.circular(AnchRadius.xl),
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Center(
        child: AnchIcon(
          icon ?? AnchAssets.empty,
          size: 32,
          color: colors.accent,
        ),
      ),
    );
  }
}

/// 空状态行动按钮，低调轮廓风格
class _EmptyActionButton extends StatelessWidget {
  const _EmptyActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AnchRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AnchSpacing.xl,
            vertical: AnchSpacing.md,
          ),
          decoration: BoxDecoration(
            color: colors.accentSoft,
            borderRadius: BorderRadius.circular(AnchRadius.md),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnchIcon(AnchIcons.add, size: 16, color: colors.accent),
              const SizedBox(width: AnchSpacing.xs),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
