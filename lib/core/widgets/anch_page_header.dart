import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_icons.dart';
import '../theme/anch_spacing.dart';
import 'anch_header_action.dart';
import 'anch_adaptive_layout.dart';
import 'anch_route_back.dart';

/// 安册统一页面标题区。
///
/// 用途：首页、录入页、详情页等页面顶部标题区域统一规范。
///
/// 风格：
/// - 大标题，字重偏高
/// - 柔和副标题
/// - 右侧可放平面图标操作
/// - 不做大 Banner，不放营销语
class AnchPageHeader extends StatelessWidget {
  const AnchPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.titleTrailingText,
    this.trailing,
    this.trailingFollowsTitle = false,
    this.onBack,
    this.padding,
    this.compactWhenKeyboardVisible = false,
    this.isKeyboardVisible,
  });

  /// 页面标题
  final String title;

  /// 副标题（可选）
  final String? subtitle;

  /// 标题后显示的紧凑辅助文本（如资料数量）。
  final String? titleTrailingText;

  /// 右侧操作区（可选），建议使用 [AnchHeaderAction]
  final Widget? trailing;

  /// 子页中让右侧操作紧跟标题，而非固定在页面右侧。
  final bool trailingFollowsTitle;

  /// 返回按钮回调（可选），有值时展示返回按钮
  final VoidCallback? onBack;

  /// 自定义外边距（可选）
  final EdgeInsetsGeometry? padding;

  /// 键盘弹出时是否开启紧凑模式
  final bool compactWhenKeyboardVisible;

  /// 显式传入的键盘可见状态（可选），用于覆盖默认 MediaQuery 检测
  final bool? isKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final view = View.maybeOf(context);
    final keyboardHeight = view != null
        ? (view.viewInsets.bottom / view.devicePixelRatio)
        : 0.0;
    final isKeyboard =
        keyboardHeight > 0 || MediaQuery.of(context).viewInsets.bottom > 0;
    final isKeyboardActive = isKeyboardVisible ?? isKeyboard;
    final isCompactHeight =
        AnchLayoutScope.heightOf(context) == AnchWindowHeightClass.compact;
    final isKeyboardVisibleEffective =
        compactWhenKeyboardVisible && (isKeyboardActive || isCompactHeight);
    final stackTrailing =
        trailing != null && MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final isSubpage = onBack != null;
    final useFloatingSubpageControls = isSubpage && !stackTrailing;
    final useTitleFollowingAction =
        useFloatingSubpageControls && trailing != null && trailingFollowsTitle;
    final effectiveSubtitle = isSubpage ? null : subtitle;
    final titleStyle = isSubpage
        ? textTheme.headlineMedium
        : textTheme.headlineLarge;
    final titleTrailing = titleTrailingText == null
        ? null
        : Text(
            titleTrailingText!,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.anchColors.textSecondary,
              height: 1.25,
            ),
          );
    final titleLine = titleTrailingText == null
        ? Text(title, style: titleStyle)
        : useTitleFollowingAction
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(title, style: titleStyle),
              const SizedBox(width: AnchSpacing.sm),
              titleTrailing!,
            ],
          )
        : Wrap(
            spacing: AnchSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(title, style: titleStyle),
              titleTrailing!,
            ],
          );
    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleLine,
        if (effectiveSubtitle != null && !isKeyboardVisibleEffective) ...[
          const SizedBox(height: AnchSpacing.xs),
          Text(effectiveSubtitle, style: textTheme.bodySmall),
        ],
      ],
    );

    final headerContent = useTitleFollowingAction
        ? Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 24 + AnchSpacing.sm,
            ),
            child: IntrinsicWidth(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 42),
                    child: titleBlock,
                  ),
                  PositionedDirectional(
                    end: 0,
                    top: -AnchSpacing.md,
                    child: trailing!,
                  ),
                ],
              ),
            ),
          )
        : useFloatingSubpageControls
        ? Padding(
            padding: EdgeInsetsDirectional.only(
              start: 24 + AnchSpacing.sm,
              end: trailing == null ? 0 : 48,
            ),
            child: titleBlock,
          )
        : stackTrailing
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: titleBlock)],
              ),
              const SizedBox(height: AnchSpacing.xs),
              Align(alignment: Alignment.centerRight, child: trailing!),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleBlock),
              if (trailing != null) ...[
                const SizedBox(width: AnchSpacing.sm),
                trailing!,
              ],
            ],
          );

    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            AnchSpacing.page,
            isKeyboardVisibleEffective
                ? AnchSpacing.sm
                : (isSubpage ? AnchSpacing.lg : AnchSpacing.md),
            AnchSpacing.page,
            isKeyboardVisibleEffective
                ? AnchSpacing.xs
                : (isSubpage ? AnchSpacing.md : AnchSpacing.sm),
          ),
      child: onBack == null
          ? headerContent
          : Stack(
              children: [
                if (!useFloatingSubpageControls)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: 24 + AnchSpacing.sm,
                    ),
                    child: headerContent,
                  )
                else
                  headerContent,
                PositionedDirectional(
                  start: -AnchSpacing.md,
                  top: -AnchSpacing.md,
                  child: AnchRouteBack(onBack: onBack),
                ),
                if (useFloatingSubpageControls &&
                    trailing != null &&
                    !useTitleFollowingAction)
                  PositionedDirectional(
                    end: -AnchSpacing.md,
                    top: -AnchSpacing.md,
                    child: trailing!,
                  ),
              ],
            ),
    );
  }
}

/// 紧凑工具栏模式页面标题区（opt-in，录入流程专用）。
///
/// 结构：左返回按钮 · 居中标题 · 右关闭按钮
/// 与 [AnchPageHeader] 默认模式完全隔离，不影响其他页面。
class AnchFlowHeader extends StatelessWidget {
  const AnchFlowHeader({
    super.key,
    required this.title,
    this.onBack,
    this.onClose,
  });

  final String title;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            if (onBack != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Transform.translate(
                  offset: const Offset(-AnchSpacing.md, 0),
                  child: AnchRouteBack(onBack: onBack),
                ),
              ),
            if (onClose != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AnchHeaderAction(
                  icon: AnchIcons.close,
                  semanticLabel: '关闭',
                  onTap: onClose,
                  color: colors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
