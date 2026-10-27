@Tags(['security'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/repository/models/item_model.dart';
import 'package:anch/core/service/policy/item_expiry_status_policy.dart';
import 'package:anch/core/service/item_expiry_overview_service.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/widgets/card_contract/anch_card_builder.dart';

ItemModel item({
  String? type = 'id_card',
  String? title = '测试资料',
  String? summary,
  String? primary,
  String? note,
  String? repaymentDay,
  String? billDay,
  Map<String, String?> fields = const {},
  bool pinned = false,
}) => ItemModel(
  id: 'mock-item',
  templateVersion: 1,
  typeKey: type,
  categoryKey: 'certificate',
  title: title,
  summaryText: summary,
  primaryText: primary,
  note: note,
  isFavorite: false,
  isPinned: pinned,
  sortOrder: 0,
  status: 'active',
  createdAt: 0,
  updatedAt: 0,
  fieldValues: fields,
  repaymentDay: repaymentDay,
  billDay: billDay,
);

void main() {
  final now = DateTime(2026, 7, 3);
  test('注销卡不进入到期概览，也不展示到期或账单还款提醒，正式状态优先', () {
    for (final fields in <Map<String, String?>>[
      {'is_closed': 'true', 'valid_until': '2020-01-01'},
      {'is_closed': '1', 'valid_until': '2026-07-03'},
      {'valid_until': '2026-07-08'},
    ]) {
      final source = item(
        type: 'credit_card',
        primary: '测试银行 · 已注销',
        fields: fields,
        repaymentDay: '20',
        billDay: '10',
      );
      final model = AnchCardBuilder.item(source, memberName: '家庭', now: now);
      expect(model.statusLabel, '已注销');
      expect(model.expiryBadgeText, isNull);
      expect(model.repaymentDayBadge, isNull);
      expect(model.billDayBadge, isNull);
      final overview = ItemExpiryOverviewService.calculate([source], now);
      expect(overview.actionableEntries, isEmpty);
      expect(
        overview.expiredCount + overview.todayCount + overview.upcomingCount,
        0,
      );
    }
    final reopened = item(
      type: 'credit_card',
      primary: '测试银行 · 已注销',
      fields: {'is_closed': 'false', 'valid_until': '2020-01-01'},
      repaymentDay: '20',
    );
    final model = AnchCardBuilder.item(reopened, memberName: '家庭', now: now);
    expect(model.statusLabel, isNull);
    expect(model.expiryBadgeText, '已过期');
    expect(model.repaymentDayBadge, '还款 20日');
    expect(
      ItemExpiryOverviewService.calculate([reopened], now).expiredCount,
      1,
    );
  });
  test('具体类型图标优先，缺失类型使用大类图标', () {
    for (final entry in {
      'id_card': AnchIcons.idCard,
      'household_book': AnchIcons.householdBook,
    }.entries) {
      expect(
        AnchCardBuilder.item(
          item(type: entry.key),
          memberName: '家庭',
          now: now,
        ).icon,
        same(entry.value),
      );
    }
    expect(
      AnchCardBuilder.item(item(type: null), memberName: '家庭', now: now).icon,
      same(AnchIcons.generic),
    );
  });
  test('摘要移除重复标题、归属、类型，保留独有内容及置顶标记', () {
    final model = AnchCardBuilder.item(
      item(
        title: '测试资料',
        summary: '标题: 测试资料 | 成员: 家庭 | 类型: 身份证 | 城市: 测试市',
        pinned: true,
      ),
      memberName: '家庭',
      now: now,
    );
    expect(model.description, '家庭 · 身份证 · 城市: 测试市');
    expect(model.tag, '置顶');
  });
  test('银行卡尾号只进入标题一次，账单还款日仅信用卡显示', () {
    final source = item(
      type: 'credit_card',
      title: '测试卡',
      primary: '测试卡 · 测试银行 · 尾号 1234',
      repaymentDay: '20',
      billDay: '10',
    );
    final model = AnchCardBuilder.item(source, memberName: '家庭', now: now);
    expect(model.title, '测试卡（1234）');
    expect(model.description, '家庭 · 测试银行');
    expect(model.repaymentDayBadge, '还款 20日');
    expect(model.billDayBadge, '账单 10日');
    final debit = AnchCardBuilder.item(
      item(
        type: 'debit_card',
        title: '测试卡（1234）',
        primary: '尾号 1234',
        repaymentDay: '20',
      ),
      memberName: '家庭',
      now: now,
    );
    expect(debit.title, '测试卡（1234）');
    expect(debit.repaymentDayBadge, isNull);
  });
  test('银行卡摘要仅展示归属与机构，不混入用途和注销文字', () {
    final model = AnchCardBuilder.item(
      item(
        type: 'debit_card',
        primary: '测试银行 · 尾号 1234 · 很长的虚构用途说明 · 已注销',
        fields: {'bank_name': '测试银行', 'is_closed': 'true'},
      ),
      memberName: '家庭',
      now: now,
    );
    expect(model.description, '家庭 · 测试银行');
    expect(model.title, '测试资料（1234）');
    expect(model.statusLabel, '已注销');
    final active = AnchCardBuilder.item(
      item(
        type: 'credit_card',
        primary: '旧银行 · 已注销',
        fields: {'bank_name': '新银行', 'is_closed': 'false'},
      ),
      memberName: '家庭',
      now: now,
    );
    expect(active.description, '家庭 · 新银行');
    expect(active.statusLabel, isNull);
  });
  test('同一资料按传入时间重新计算到期状态，不留下跨调用缓存', () {
    final source = item(fields: {'valid_until': '2026-07-04'});
    expect(
      AnchCardBuilder.item(source, memberName: '家庭', now: now).expiryStatus,
      ItemExpiryStatus.upcoming,
    );
    expect(
      AnchCardBuilder.item(
        source,
        memberName: '家庭',
        now: DateTime(2026, 7, 5),
      ).expiryStatus,
      ItemExpiryStatus.expired,
    );
  });
  test('备注与完整高敏字段不会进入卡片或展示契约', () {
    final model = AnchCardBuilder.item(
      item(
        note: 'MOCK-secret-note',
        fields: {'id_number': 'MOCK-secret-number'},
      ),
      memberName: '家庭',
      now: now,
    );
    expect(model.description, '家庭 · 身份证');
    for (final text in [
      model.title,
      model.description,
      model.tag,
      model.billDayBadge,
      model.repaymentDayBadge,
      model.expiryBadgeText,
    ]) {
      expect(text ?? '', isNot(contains('MOCK-secret')));
    }
  });
  test('空标题使用明确占位，无关日期不显示到期徽标', () {
    final model = AnchCardBuilder.item(
      item(type: 'generic', title: '  '),
      memberName: '家庭',
      now: now,
    );
    expect(model.title, '未命名资料');
    expect(model.expiryBadgeText, isNull);
  });
}
