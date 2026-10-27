import 'package:flutter/material.dart';
import '../app/dependency_provider.dart';
import '../core/repository/models/item_model.dart';
import '../features/item_detail/item_detail_page.dart';
import 'anch_unified_data_card.dart';
import 'card_contract/anch_card_builder.dart';
import 'card_contract/anch_search_highlighter.dart';

/// 各列表共用摘要、搜索高亮与详情入口；查询和筛选留在页面。
class ItemSummaryCard extends StatelessWidget {
  const ItemSummaryCard({
    super.key,
    required this.item,
    required this.memberName,
    this.onTap,
    this.onLongPress,
    this.onDetailClosed,
    this.keyword = '',
    this.grouped = false,
  });

  final ItemModel item;
  final String memberName;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDetailClosed;
  final String keyword;
  final bool grouped;

  static Future<void> openDetail(BuildContext context, String itemId) =>
      Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (context) => ItemDetailPage(
            itemId: itemId,
            privacyShieldCoordinator: DependencyProvider.maybeOf(
              context,
            )?.privacyShieldBundle?.coordinator,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final model = AnchCardBuilder.item(
      item,
      memberName: memberName,
      now: DependencyProvider.of(context).timeDomainSource.now(),
    );
    final theme = Theme.of(context);
    InlineSpan? highlight(String value, TextStyle style) => keyword.isEmpty
        ? null
        : AnchSearchHighlighter.buildHighlightSpan(
            value,
            keyword,
            style,
            style.copyWith(
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.2),
            ),
          );
    return AnchUnifiedDataCard(
      model: model,
      grouped: grouped,
      titleSpan: highlight(
        model.title,
        theme.textTheme.titleMedium ?? const TextStyle(),
      ),
      descriptionSpan: highlight(
        model.description,
        theme.textTheme.bodyMedium?.copyWith(fontSize: 14) ??
            const TextStyle(fontSize: 14),
      ),
      onTap:
          onTap ??
          () async {
            await openDetail(context, item.id);
            onDetailClosed?.call();
          },
      onLongPress: onLongPress,
    );
  }
}
