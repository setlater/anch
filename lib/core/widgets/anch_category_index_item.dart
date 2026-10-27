import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_spacing.dart';

/// 石墨资料册的分类索引单元。
class AnchCategoryIndexItem extends StatelessWidget {
  const AnchCategoryIndexItem({
    super.key,
    required this.icon,
    required this.title,
    required this.itemCount,
    required this.onTap,
  });

  final AnchIconData icon;
  final String title;
  final int itemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(AnchSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnchIcon(
                      icon,
                      key: const Key('category_index_icon'),
                      size: 24,
                      color: colors.documentIcon,
                    ),
                    const SizedBox(width: AnchSpacing.sm),
                    Text(
                      '$itemCount 条',
                      key: const Key('category_index_count'),
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AnchSpacing.sm),
                Text(
                  title,
                  key: const Key('category_index_title'),
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
