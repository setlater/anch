import 'package:flutter_test/flutter_test.dart';
import 'item_ui_contract.dart';

class ContractTestRunner {
  static void verify(
    ItemUIContract contract, {
    String? expectedTitle,
    String? expectedSubtitle,
    bool? expectedHasBadges,
    bool? expectedHasHighlight,
    bool? expectedHasEmptyState,
    String? expectedEmptyStateType,
  }) {
    if (expectedTitle != null) {
      expect(contract.title, equals(expectedTitle));
    }
    if (expectedSubtitle != null) {
      expect(contract.subtitle, equals(expectedSubtitle));
    }
    if (expectedHasBadges != null) {
      expect(contract.hasBadges, equals(expectedHasBadges));
    }
    if (expectedHasHighlight != null) {
      expect(contract.hasHighlight, equals(expectedHasHighlight));
    }
    if (expectedHasEmptyState != null) {
      expect(contract.hasEmptyState, equals(expectedHasEmptyState));
    }
    if (expectedEmptyStateType != null) {
      expect(contract.emptyStateType, equals(expectedEmptyStateType));
    }
  }
}
