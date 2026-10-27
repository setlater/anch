import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/widgets/anch_empty_state.dart';
import 'package:anch/widgets/anch_unified_data_card.dart';
import 'item_ui_contract.dart';

class ContractExtractor {
  static ItemUIContract fromListItem(WidgetTester tester, {Finder? finder}) {
    final emptyStates = find.byType(AnchEmptyState).evaluate();
    if (emptyStates.isNotEmpty) {
      return ItemUIContract(
        title: '',
        subtitle: '',
        hasBadges: false,
        hasHighlight: false,
        hasEmptyState: true,
        emptyStateType: (emptyStates.first.widget as AnchEmptyState).title,
      );
    }
    final cards = (finder ?? find.byType(AnchUnifiedDataCard)).evaluate();
    if (cards.isNotEmpty) {
      final card = cards.first.widget as AnchUnifiedDataCard;
      final model = card.model;
      return ItemUIContract(
        title: model.title,
        subtitle: model.description,
        hasBadges:
            model.tag != null ||
            model.expiryBadgeText != null ||
            model.billDayBadge != null ||
            model.repaymentDayBadge != null,
        hasHighlight: card.hasHighlight,
        hasEmptyState: false,
        emptyStateType: '',
      );
    }
    return const ItemUIContract(
      title: '',
      subtitle: '',
      hasBadges: false,
      hasHighlight: false,
      hasEmptyState: false,
      emptyStateType: '',
    );
  }
}
