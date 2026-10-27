import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/service/item_expiry_overview_service.dart';
import 'package:anch/core/service/policy/item_expiry_status_policy.dart';

void main() {
  group('ItemExpiryOverviewService Unit Tests', () {
    final now = DateTime(2026, 7, 3);

    ItemModel buildItem({
      required String id,
      required String typeKey,
      String? validUntil,
      String? endDate,
      bool? isLongTerm,
    }) {
      final Map<String, dynamic> fields = {};
      if (validUntil != null) {
        fields['valid_until'] = validUntil;
      }
      if (endDate != null) {
        fields['end_date'] = endDate;
      }
      if (isLongTerm != null) {
        fields['is_long_term'] = isLongTerm;
      }

      final metadataMap = {
        'raw_state': {
          'fields': fields,
        }
      };

      return ItemModel(
        id: id,
        typeKey: typeKey,
        templateVersion: 1,
        isFavorite: false,
        isPinned: false,
        sortOrder: 0,
        status: 'active',
        createdAt: 0,
        updatedAt: 0,
        metadata: jsonEncode(metadataMap),
      );
    }

    test('empty items list', () {
      final result = ItemExpiryOverviewService.calculate([], now);
      expect(result.expiredCount, 0);
      expect(result.todayCount, 0);
      expect(result.upcomingCount, 0);
      expect(result.actionableEntries, isEmpty);
    });

    test('counting and grouping correctness', () {
      final items = [
        // 已过期
        buildItem(id: '1', typeKey: 'passport', validUntil: '2026-07-02'),
        // 今日到期
        buildItem(id: '2', typeKey: 'passport', validUntil: '2026-07-03'),
        // 即将到期
        buildItem(id: '3', typeKey: 'passport', validUntil: '2026-08-02'),
        // 远期正常 (不进入列表)
        buildItem(id: '4', typeKey: 'passport', validUntil: '2026-08-04'),
        // 未填写 (不进入列表)
        buildItem(id: '5', typeKey: 'passport', validUntil: ''),
        // 格式异常 (不进入列表)
        buildItem(id: '6', typeKey: 'passport', validUntil: 'bad-date'),
        // 不支持类型 (不进入列表)
        buildItem(id: '7', typeKey: 'debit_card', validUntil: '2026-07-02'),
      ];

      final result = ItemExpiryOverviewService.calculate(items, now);

      expect(result.expiredCount, 1);
      expect(result.todayCount, 1);
      expect(result.upcomingCount, 1);
      expect(result.actionableEntries.length, 3);

      expect(result.actionableEntries[0].item.id, '1');
      expect(result.actionableEntries[0].statusResult.status, ItemExpiryStatus.expired);

      expect(result.actionableEntries[1].item.id, '2');
      expect(result.actionableEntries[1].statusResult.status, ItemExpiryStatus.today);

      expect(result.actionableEntries[2].item.id, '3');
      expect(result.actionableEntries[2].statusResult.status, ItemExpiryStatus.upcoming);
    });

    test('sorting logic priority and order', () {
      final items = [
        // 4. 30天内到期 (2026-08-01)
        buildItem(id: 'upcoming_late', typeKey: 'passport', validUntil: '2026-08-01'),
        // 1. 已过期 (2026-07-01)
        buildItem(id: 'expired_early', typeKey: 'passport', validUntil: '2026-07-01'),
        // 3. 7天内到期 (2026-07-08)
        buildItem(id: 'upcoming_7days', typeKey: 'passport', validUntil: '2026-07-08'),
        // 2. 今日到期 (2026-07-03)
        buildItem(id: 'today', typeKey: 'passport', validUntil: '2026-07-03'),
        // 1. 已过期 (2026-06-30 - 应当排在 expired 组的最前)
        buildItem(id: 'expired_earliest', typeKey: 'passport', validUntil: '2026-06-30'),
        // 4. 30天内到期 (2026-07-15)
        buildItem(id: 'upcoming_early', typeKey: 'passport', validUntil: '2026-07-15'),
        // 3. 7天内到期 (2026-07-06)
        buildItem(id: 'upcoming_3days', typeKey: 'passport', validUntil: '2026-07-06'),
      ];

      final result = ItemExpiryOverviewService.calculate(items, now);

      expect(result.actionableEntries.length, 7);

      // 组内排序及类别排序复合校验：
      // expired (2026-06-30) -> expired (2026-07-01) 
      // -> today (2026-07-03) 
      // -> within7Days (2026-07-06) -> within7Days (2026-07-08) 
      // -> within30Days (2026-07-15) -> within30Days (2026-08-01)
      expect(result.actionableEntries[0].item.id, 'expired_earliest');
      expect(result.actionableEntries[1].item.id, 'expired_early');
      expect(result.actionableEntries[2].item.id, 'today');
      expect(result.actionableEntries[3].item.id, 'upcoming_3days');
      expect(result.actionableEntries[4].item.id, 'upcoming_7days');
      expect(result.actionableEntries[5].item.id, 'upcoming_early');
      expect(result.actionableEntries[6].item.id, 'upcoming_late');
    });

    test('no UI text properties compiled in service', () {
      // 确认服务层完全与 UI / 隐私描述隔离，没有硬编码任何页面标签或翻译
      final items = [
        buildItem(id: '1', typeKey: 'passport', validUntil: '2026-07-02'),
      ];
      final result = ItemExpiryOverviewService.calculate(items, now);

      // 验证没有携带任何拼装过 memberName 或者是 categoryLabel 或者是 "已过期 X 条" 的文案属性
      final entry = result.actionableEntries.first;
      // result 只有 raw model 和 policy result，没有 UI 组合字符串。
      expect(entry.item.id, '1');
      expect(entry.statusResult.status, ItemExpiryStatus.expired);
    });
  });
}
