import '../repository/models/item_model.dart';
import 'policy/item_expiry_status_policy.dart';

class ItemExpiryEntry {
  final ItemModel item;
  final ItemExpiryStatusResult statusResult;

  const ItemExpiryEntry({required this.item, required this.statusResult});
}

class ItemExpiryOverviewResult {
  final int expiredCount;
  final int todayCount;
  final int upcomingCount;
  final List<ItemExpiryEntry> actionableEntries;

  const ItemExpiryOverviewResult({
    required this.expiredCount,
    required this.todayCount,
    required this.upcomingCount,
    required this.actionableEntries,
  });
}

class ItemExpiryOverviewService {
  static ItemExpiryOverviewResult calculate(
    List<ItemModel> items,
    DateTime now,
  ) {
    int expiredCount = 0;
    int todayCount = 0;
    int upcomingCount = 0;

    final List<ItemExpiryEntry> entries = [];

    for (final item in items) {
      final policyResult = ItemExpiryStatusPolicy.calculate(
        typeKey: item.typeKey,
        templateVersion: item.templateVersion,
        rawState: item.rawState,
        primaryText: item.primaryText,
        now: now,
      );

      switch (policyResult.status) {
        case ItemExpiryStatus.expired:
          expiredCount++;
          entries.add(ItemExpiryEntry(item: item, statusResult: policyResult));
          break;
        case ItemExpiryStatus.today:
          todayCount++;
          entries.add(ItemExpiryEntry(item: item, statusResult: policyResult));
          break;
        case ItemExpiryStatus.upcoming:
          upcomingCount++;
          entries.add(ItemExpiryEntry(item: item, statusResult: policyResult));
          break;
        default:
          break;
      }
    }

    // 排序逻辑：
    // 1. 已过期 (expired) -> 今日到期 (today) -> 7 天内到期 (within7Days) -> 30 天内到期 (within30Days)
    // 2. 同组内按到期日期 (expiryDate) 升序
    entries.sort((a, b) {
      final orderA = _getDetailedGroupOrder(a.statusResult);
      final orderB = _getDetailedGroupOrder(b.statusResult);

      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }

      final dateA = a.statusResult.expiryDate;
      final dateB = b.statusResult.expiryDate;

      if (dateA != null && dateB != null) {
        return dateA.compareTo(dateB);
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      return 0;
    });

    return ItemExpiryOverviewResult(
      expiredCount: expiredCount,
      todayCount: todayCount,
      upcomingCount: upcomingCount,
      actionableEntries: entries,
    );
  }

  static int _getDetailedGroupOrder(ItemExpiryStatusResult res) {
    switch (res.status) {
      case ItemExpiryStatus.expired:
        return 0;
      case ItemExpiryStatus.today:
        return 1;
      case ItemExpiryStatus.upcoming:
        if (res.daysUntilExpiry != null && res.daysUntilExpiry! <= 7) {
          return 2;
        }
        return 3;
      default:
        return 99;
    }
  }
}
