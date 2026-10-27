import 'package:anch/core/theme/anch_icons.dart';
import 'package:flutter/material.dart';
import 'anch_detail_field_row_layout.dart';

/// 安册普通信息展示行。
///
/// 适合低敏/中敏字段，提供左右标签与内容排列，并支持可选的复制按钮。
class AnchInfoFieldRow extends StatelessWidget {
  const AnchInfoFieldRow({
    super.key,
    required this.fieldId,
    required this.label,
    required this.value,
    this.fieldNote,
    this.copyable = false,
    this.onCopy,
    this.trailing,
    this.valueDisplayMode = AnchValueDisplayMode.normal,
    this.fieldKey,
    this.labelWidth = 100,
  });

  /// 字段 ID
  final String fieldId;

  /// 字段标签（例如 “姓名”）
  final String label;

  /// 字段值（例如 “张三”）
  final String value;

  /// 字段备注说明（可选）
  final String? fieldNote;

  /// 是否支持复制
  final bool copyable;

  /// 复制回调
  final void Function(String fieldId)? onCopy;

  /// 自定义尾部组件
  final Widget? trailing;

  /// 展示模式
  final AnchValueDisplayMode valueDisplayMode;

  /// 字段 Key（可选，用于生成稳定测试 Key）
  final String? fieldKey;

  /// 当前字段表共享的标签列宽。
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    Widget? trailingWidget = trailing;
    if (trailingWidget == null &&
        copyable &&
        value.trim().isNotEmpty &&
        onCopy != null) {
      trailingWidget = AnchCompactIconAction(
        icon: AnchIcons.copy,
        tooltip: '复制',
        semanticLabel: '复制$label',
        onPressed: () => onCopy?.call(fieldId),
      );
    }

    return AnchDetailFieldRowLayout(
      label: label,
      valueText: value,
      trailing: trailingWidget,
      valueDisplayMode: valueDisplayMode,
      fieldNote: fieldNote,
      fieldKey: fieldKey ?? fieldId,
      isSensitive: false,
      labelWidth: labelWidth,
    );
  }
}
