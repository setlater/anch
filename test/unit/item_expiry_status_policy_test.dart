import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/service/policy/item_expiry_status_policy.dart';

void main() {
  group('ItemExpiryStatusPolicy Unit Tests', () {
    final now = DateTime(2026, 7, 3); // 基准日期 2026-07-03

    test('unsupported template type', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'debit_card', // 储蓄卡无有效期字段
        rawState: {
          'fields': {'valid_until': '2026-07-04'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.unsupported);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });

    test('其他资料 v2 不支持已移除的有效期提醒', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'generic',
        templateVersion: 2,
        rawState: {
          'fields': {'custom_field_value_1': '虚构值'},
        },
        now: now,
      );

      expect(result.status, ItemExpiryStatus.unsupported);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });

    test('missing expiry field value', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': ''},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.missing);
      expect(result.detailMessage, '请先填写有效期');
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isTrue);
    });

    test('invalid expiry field value (malformed)', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': 'invalid-date-format'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.invalid);
      expect(result.detailMessage, '有效期格式异常，请检查');
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isTrue);
    });

    test('normal status (more than 30 days)', () {
      // 2026-08-04 到 2026-07-03 是 32 天
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-08-04'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });

    test('upcoming status boundary: 30 days (inclusive)', () {
      // 2026-08-02 到 2026-07-03 是 30 天
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-08-02'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.upcoming);
      expect(result.badgeText, '即将到期');
      expect(result.detailMessage, '即将到期，剩余 30 天');
      expect(result.shouldShowListBadge, isTrue);
      expect(result.shouldShowDetailBanner, isTrue);
    });

    test('upcoming status boundary: <= 7 days (e.g. 2 days left)', () {
      // 2026-07-05 到 2026-07-03 是 2 天
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-07-05'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.upcoming);
      expect(result.badgeText, '剩余 2 天');
      expect(result.detailMessage, '即将到期，剩余 2 天');
      expect(result.shouldShowListBadge, isTrue);
    });

    test('upcoming status boundary: > 7 days (e.g. 20 days left)', () {
      // 2026-07-23 到 2026-07-03 是 20 天
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-07-23'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.upcoming);
      expect(result.badgeText, '即将到期');
      expect(result.detailMessage, '即将到期，剩余 20 天');
      expect(result.shouldShowListBadge, isTrue);
    });

    test('upcoming status boundary: 31 days (normal)', () {
      // 2026-08-03 到 2026-07-03 是 31 天
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-08-03'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });

    test('today status', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-07-03'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.today);
      expect(result.badgeText, '今日到期');
      expect(result.detailMessage, '今日到期');
      expect(result.shouldShowListBadge, isTrue);
      expect(result.shouldShowDetailBanner, isTrue);
    });

    test('expired status', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'passport',
        rawState: {
          'fields': {'valid_until': '2026-07-02'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.expired);
      expect(result.badgeText, '已过期');
      expect(result.detailMessage, '已过期，请更新有效期');
      expect(result.shouldShowListBadge, isTrue);
      expect(result.shouldShowDetailBanner, isTrue);
    });

    test('id_card long term: is_long_term = true (bool)', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'id_card',
        rawState: {
          'fields': {
            'valid_until': '2026-07-02', // 即使日期已过期，长期有效也应判定为 normal
            'is_long_term': true,
          },
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });

    test('id_card long term: is_long_term = "true" (string)', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'id_card',
        rawState: {
          'fields': {'valid_until': '', 'is_long_term': 'true'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
      expect(result.shouldShowListBadge, isFalse);
    });

    test('id_card long term: is_long_term = "1" (string)', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'id_card',
        rawState: {
          'fields': {'valid_until': '', 'is_long_term': '1'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
    });

    test('id_card long term: is_long_term = 1 (int)', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'id_card',
        rawState: {
          'fields': {'valid_until': '', 'is_long_term': 1},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
    });

    test('id_card long term: valid_until = "长期"', () {
      final result = ItemExpiryStatusPolicy.calculate(
        typeKey: 'id_card',
        rawState: {
          'fields': {'valid_until': '长期'},
        },
        now: now,
      );
      expect(result.status, ItemExpiryStatus.normal);
      expect(result.shouldShowListBadge, isFalse);
      expect(result.shouldShowDetailBanner, isFalse);
    });


  });
}
