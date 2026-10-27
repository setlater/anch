import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_spacing.dart';
import '../theme/anch_radius.dart';

/// 安册字段分组卡片。
///
/// 功能：包裹一个字段分组，提供分组标题与说明，采用统一的圆角、阴影与内边距。
/// 支持子字段之间自动插入细分割线。
class AnchFieldGroupCard extends StatelessWidget {
  const AnchFieldGroupCard({
    super.key,
    required this.title,
    this.description,
    required this.children,
  });

  /// 分组标题（例如 “基本信息”）
  final String title;

  /// 分组说明（例如 “包含您的核心证件资料”）（可选）
  final String? description;

  /// 字段行小部件列表
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final List<Widget> itemsWithDividers = [];
    for (int i = 0; i < children.length; i++) {
      itemsWithDividers.add(children[i]);
      if (i < children.length - 1) {
        itemsWithDividers.add(
          Divider(height: 1, thickness: 1, color: colors.divider),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AnchSpacing.sm),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                ),
              ),
              if (description != null && description!.isNotEmpty)
                Text(
                  description!,
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(AnchRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: itemsWithDividers,
          ),
        ),
      ],
    );
  }
}
