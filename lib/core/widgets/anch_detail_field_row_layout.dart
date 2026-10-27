import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';

/// 详情页面字段的值展示模式
enum AnchValueDisplayMode {
  /// 短文本，如姓名、性别、日期、民族、签发机关
  normal,

  /// 结构化长值，如身份证号、银行卡号、证书号、VIN、保单号
  singleLineScrollable,

  /// 自然语言长文本，如地址、备注
  multiline,
}

/// 详情页面字段行的轻量布局底座组件
class AnchDetailFieldRowLayout extends StatelessWidget {
  const AnchDetailFieldRowLayout({
    super.key,
    required this.label,
    this.valueText,
    this.valueWidget,
    this.trailing,
    this.valueDisplayMode = AnchValueDisplayMode.normal,
    this.labelWidth = 100,
    this.minHeight,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 10),
    this.fieldNote,
    this.fieldKey,
    this.isSensitive = false,
  });

  /// 字段标签
  final String label;

  /// 字段值文本
  final String? valueText;

  /// 字段值自定义 Widget
  final Widget? valueWidget;

  /// 右侧操作栏 Widget
  final Widget? trailing;

  /// 展示模式
  final AnchValueDisplayMode valueDisplayMode;

  /// 标签区域宽度
  final double labelWidth;

  /// 最小高度
  final double? minHeight;

  /// 内边距
  final EdgeInsetsGeometry contentPadding;

  /// 字段备注说明
  final String? fieldNote;

  /// 字段唯一标识 Key (用于生成 stable 测试 Key)
  final String? fieldKey;

  /// 是否是敏感字段
  final bool isSensitive;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final displayValue = (valueText ?? '').trim().isEmpty ? '—' : valueText!;
    final keySuffix = fieldKey ?? label;

    final scrollKey = Key('field_scroll_val_$keySuffix');
    final multilineKey = Key('field_multiline_val_$keySuffix');
    final normalKey = Key('field_normal_val_$keySuffix');
    final trailingKey = Key('field_trailing_actions_$keySuffix');
    final labelKey = Key('field_label_$keySuffix');

    final isMultiline = valueDisplayMode == AnchValueDisplayMode.multiline;
    final resolvedMinHeight = minHeight ?? 48.0;

    // Resolve directional padding and split into outer horizontal and inner vertical
    final resolvedPadding = contentPadding.resolve(
      Directionality.maybeOf(context),
    );
    final outerPadding = EdgeInsets.only(
      left: isMultiline ? resolvedPadding.left : 0.0,
      right: isMultiline ? resolvedPadding.right : 0.0,
    );
    final innerVerticalPadding = isMultiline
        ? EdgeInsets.only(
            top: resolvedPadding.top,
            bottom: resolvedPadding.bottom,
          )
        : EdgeInsets.zero;

    Widget valWidget;
    if (valueWidget != null) {
      valWidget = valueWidget!;
    } else {
      switch (valueDisplayMode) {
        case AnchValueDisplayMode.singleLineScrollable:
          valWidget = SingleChildScrollView(
            key: scrollKey,
            scrollDirection: Axis.horizontal,
            child: Text(
              displayValue,
              key: normalKey,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 16,
                color: colors.textPrimary,
                fontWeight: FontWeight.w500,
                height: 1.3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          );
          break;
        case AnchValueDisplayMode.multiline:
          valWidget = Text(
            displayValue,
            key: multilineKey,
            style: TextStyle(
              fontSize: 16,
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          );
          break;
        case AnchValueDisplayMode.normal:
          valWidget = Text(
            displayValue,
            key: normalKey,
            style: TextStyle(
              fontSize: 16,
              color: colors.textPrimary,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          );
          break;
      }
    }

    if (isSensitive) {
      valWidget = KeyedSubtree(
        key: Key('sensitive_value_zone_$keySuffix'),
        child: valWidget,
      );
    }

    // Wrap label in SizedBox and ConstrainedBox and Align for vertical centering/topLeft alignment
    final labelWidget = SizedBox(
      width: labelWidth,
      key: labelKey,
      child: ConstrainedBox(
        key: Key('field_label_slot_$keySuffix'),
        constraints: BoxConstraints(minHeight: resolvedMinHeight),
        child: Padding(
          padding: innerVerticalPadding,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: colors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap value in ConstrainedBox and Align for vertical centering/topLeft alignment
    final valueContainer = ConstrainedBox(
      key: Key('field_value_slot_$keySuffix'),
      constraints: BoxConstraints(minHeight: resolvedMinHeight),
      child: Padding(
        padding: innerVerticalPadding,
        child: Align(alignment: Alignment.centerLeft, child: valWidget),
      ),
    );

    // Wrap trailing in SizedBox of resolvedMinHeight when multiline, and Align for centering
    Widget? trailingWidget;
    if (trailing != null) {
      trailingWidget = SizedBox(
        height: isMultiline ? resolvedMinHeight : null,
        child: ConstrainedBox(
          key: Key('field_action_slot_$keySuffix'),
          constraints: BoxConstraints(minHeight: resolvedMinHeight),
          child: Align(alignment: Alignment.center, child: trailing!),
        ),
      );
    }

    final rowWidget = LayoutBuilder(
      builder: (context, constraints) {
        final stacked =
            constraints.maxWidth < 280 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        if (stacked) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  label,
                  key: labelKey,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: valueContainer),
                    if (trailingWidget != null)
                      KeyedSubtree(key: trailingKey, child: trailingWidget),
                  ],
                ),
              ],
            ),
          );
        }
        return Container(
          constraints: BoxConstraints(minHeight: resolvedMinHeight),
          padding: outerPadding,
          child: Row(
            crossAxisAlignment: isMultiline
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              labelWidget,
              const SizedBox(width: 8),
              Expanded(child: valueContainer),
              if (trailingWidget != null) ...[
                const SizedBox(width: 12),
                KeyedSubtree(key: trailingKey, child: trailingWidget),
              ],
            ],
          ),
        );
      },
    );

    if (fieldNote != null && fieldNote!.trim().isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          rowWidget,
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              fieldNote!.trim(),
              style: TextStyle(
                fontSize: 12,
                color: colors.textMuted,
                height: 1.3,
              ),
            ),
          ),
        ],
      );
    }

    return rowWidget;
  }
}

/// 详情页面中紧凑的可点图标。
class AnchCompactIconAction extends StatelessWidget {
  const AnchCompactIconAction({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.tooltip,
    this.semanticLabel,
  });

  /// 图标数据
  final AnchIconData icon;

  /// 点击事件
  final VoidCallback onPressed;

  /// 图标颜色
  final Color? color;

  /// 提示文本
  final String? tooltip;

  /// 无障碍标签
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final widget = Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: AnchIcon(icon, size: 18, color: color ?? colors.textMuted),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: widget);
    }
    return widget;
  }
}
