import 'package:flutter/material.dart';
import '../theme/anch_spacing.dart';
import '../theme/anch_colors.dart';

/// 安册区块标题。
///
/// 用途：首页各区块、录入页分组、详情页字段分组的标题行。
///
/// 参数：
/// - [title]：区块名称
/// - [trailingText]：右侧轻量文字，如"查看全部"
/// - [action]：右侧操作回调
class AnchSectionHeader extends StatelessWidget {
  const AnchSectionHeader({
    super.key,
    required this.title,
    this.trailingText,
    this.action,
    this.padding,
    this.trailing,
  });

  /// 区块标题文字
  final String title;

  final Widget? trailing;

  /// 右侧轻量文字（可选）
  final String? trailingText;

  /// 右侧文字点击回调（可选）
  final VoidCallback? action;

  /// 自定义外边距（可选）
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = context.anchColors;

    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            AnchSpacing.page,
            AnchSpacing.xs,
            AnchSpacing.page,
            AnchSpacing.xs,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 区块标题
          Expanded(
            child: Text(
              title,
              style: textTheme.titleSmall?.copyWith(
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),

          if (trailing != null) Flexible(child: trailing!),

          // 右侧文字操作
          if (trailingText != null)
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: TextButton(
                onPressed: action,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AnchSpacing.sm,
                  ),
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  trailingText!,
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.accentDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
