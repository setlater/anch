import 'package:anch/core/theme/anch_icons.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';

/// 资料卡片的不可变展示数据。
class AnchCardModel {
  final String title;
  final String description;
  final AnchIconData icon;
  final String? tag;
  final String? statusLabel;
  final bool showArrow;

  final String? repaymentDayBadge;
  final String? billDayBadge;
  final String? expiryBadgeText;
  final ItemExpiryStatus? expiryStatus;
  final int? daysUntilExpiry;

  const AnchCardModel({
    required this.title,
    required this.description,
    required this.icon,
    this.tag,
    this.statusLabel,
    this.showArrow = true,
    this.repaymentDayBadge,
    this.billDayBadge,
    this.expiryBadgeText,
    this.expiryStatus,
    this.daysUntilExpiry,
  });
}
