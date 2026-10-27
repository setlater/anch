import 'package:anch/core/theme/anch_icons.dart';
import 'package:flutter/material.dart';
import 'anch_detail_field_row_layout.dart';

/// 安册高敏感字段展示行。
///
/// 职责：只负责展示高敏字段的掩码、明文显隐控制、以及一键复制。
/// 注意：本组件属于纯 UI 组件，不包含任何“判断字段是否高敏”的业务规则。
class AnchSensitiveFieldRow extends StatelessWidget {
  const AnchSensitiveFieldRow({
    super.key,
    required this.fieldId,
    required this.label,
    required this.value,
    required this.maskedValue,
    required this.isRevealed,
    required this.onToggleReveal,
    this.fieldNote,
    this.copyable = false,
    this.onCopy,
    this.valueDisplayMode = AnchValueDisplayMode.normal,
    this.fieldKey,
    this.labelWidth = 100,
  });

  /// 字段 ID
  final String fieldId;

  /// 字段标签（例如 “身份证号”）
  final String label;

  /// 真实明文值
  final String value;

  /// 脱敏掩码值
  final String maskedValue;

  /// 是否显露明文值
  final bool isRevealed;

  /// 字段备注说明（可选）
  final String? fieldNote;

  /// 是否支持复制
  final bool copyable;

  /// 复制回调
  final void Function(String fieldId)? onCopy;

  /// 切换显隐的回调
  final ValueChanged<bool> onToggleReveal;

  /// 展示模式
  final AnchValueDisplayMode valueDisplayMode;

  /// 字段 Key（可选，用于生成稳定测试 Key）
  final String? fieldKey;

  /// 当前字段表共享的标签列宽。
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final hasValue = value.trim().isNotEmpty;
    final displayValue = !hasValue ? '—' : (isRevealed ? value : maskedValue);

    final resolvedDisplayMode = hasValue
        ? (valueDisplayMode == AnchValueDisplayMode.multiline
              ? AnchValueDisplayMode.multiline
              : AnchValueDisplayMode.singleLineScrollable)
        : AnchValueDisplayMode.normal;

    Widget? trailingWidget;
    if (hasValue) {
      trailingWidget = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnchCompactIconAction(
            icon: isRevealed ? AnchIcons.visibilityOff : AnchIcons.visibility,
            tooltip: isRevealed ? '隐藏' : '显示',
            semanticLabel: isRevealed ? '隐藏$label' : '显示$label',
            onPressed: () {
              onToggleReveal(!isRevealed);
            },
          ),
          if (copyable && onCopy != null) ...[
            const SizedBox(width: 4),
            AnchCompactIconAction(
              icon: AnchIcons.copy,
              tooltip: '复制',
              semanticLabel: '复制$label',
              onPressed: () => onCopy?.call(fieldId),
            ),
          ],
        ],
      );
    }

    return AnchDetailFieldRowLayout(
      key: ValueKey('detail_field_row_${fieldKey ?? fieldId}'),
      label: label,
      valueText: displayValue,
      trailing: trailingWidget,
      valueDisplayMode: resolvedDisplayMode,
      fieldNote: fieldNote,
      fieldKey: fieldKey ?? fieldId,
      isSensitive: true,
      labelWidth: labelWidth,
    );
  }
}
