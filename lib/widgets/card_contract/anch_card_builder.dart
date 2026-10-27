import '../../core/repository/models/item_model.dart';
import '../../core/template/template_registry.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/service/policy/item_expiry_status_policy.dart';
import 'anch_card_model.dart';

/// 由页面持有的低敏摘要直接构建资料卡片；不保留输入或展示缓存。
class AnchCardBuilder {
  const AnchCardBuilder._();

  static AnchCardModel item(
    ItemModel source, {
    required String memberName,
    required DateTime now,
  }) {
    final item = source.toListSummary();
    final typeDef = item.typeKey != null
        ? TemplateRegistry.getTemplate(item.typeKey!, item.templateVersion)
        : null;
    final typeLabel = typeDef?.label ?? item.typeKey ?? '未知类型';

    final catDef = item.categoryKey != null
        ? TemplateRegistry.getCategories().firstWhere(
            (c) => c.categoryKey == item.categoryKey,
            orElse: () => TemplateRegistry.getCategories().first,
          )
        : null;
    final categoryLabel = catDef?.label ?? '其他资料';

    final displayTitle = (item.title == null || item.title!.trim().isEmpty)
        ? '未命名资料'
        : item.title!;

    // 去重 summaryText（与 title/member/type 相同时忽略）
    final rawSummary = item.summaryText;
    String? cleanSummary;
    if (rawSummary != null && rawSummary.trim().isNotEmpty) {
      final titleLower = displayTitle.toLowerCase().trim();
      final memberLower = memberName.toLowerCase().trim();
      final typeLower = typeLabel.toLowerCase().trim();
      final catLower = categoryLabel.toLowerCase().trim();

      final parts = rawSummary.split(' | ');
      final cleanParts = <String>[];
      for (final part in parts) {
        final kv = part.split(': ');
        final val = kv.length == 2
            ? kv[1].trim().toLowerCase()
            : part.trim().toLowerCase();
        if (val == titleLower ||
            val == memberLower ||
            val == typeLower ||
            val == catLower) {
          continue;
        }
        cleanParts.add(part);
      }
      cleanSummary = cleanParts.isEmpty ? null : cleanParts.join(' | ');
    }

    final isCreditCard = item.typeKey == 'credit_card';
    final isBankCard = isCreditCard || item.typeKey == 'debit_card';
    final isClosed = ItemExpiryStatusPolicy.isBankCardClosed(
      typeKey: item.typeKey,
      rawState: item.rawState,
      primaryText: item.primaryText,
    );
    final title = isBankCard ? _bankCardTitle(item) : displayTitle;
    final description = isBankCard
        ? _bankCardDescription(
            item: item,
            memberName: memberName,
            displayTitle: title,
          )
        : '$memberName · $typeLabel${cleanSummary == null ? '' : ' · $cleanSummary'}';
    final expiryResult = ItemExpiryStatusPolicy.calculate(
      typeKey: item.typeKey,
      templateVersion: item.templateVersion,
      rawState: item.rawState,
      primaryText: item.primaryText,
      now: now,
    );
    final String? expiryBadgeText = expiryResult.shouldShowListBadge
        ? expiryResult.badgeText
        : null;
    final ItemExpiryStatus? expiryStatus = expiryResult.shouldShowListBadge
        ? expiryResult.status
        : null;
    final int? daysUntilExpiry = expiryResult.shouldShowListBadge
        ? expiryResult.daysUntilExpiry
        : null;

    String? repaymentDayBadge;
    if (isCreditCard &&
        !isClosed &&
        item.repaymentDay != null &&
        item.repaymentDay!.isNotEmpty) {
      repaymentDayBadge = '还款 ${item.repaymentDay}日';
    }

    String? billDayBadge;
    if (isCreditCard &&
        !isClosed &&
        item.billDay != null &&
        item.billDay!.isNotEmpty) {
      billDayBadge = '账单 ${item.billDay}日';
    }

    return AnchCardModel(
      title: title,
      description: description,
      icon: item.typeKey == null
          ? AnchIcons.forCategoryKey(item.categoryKey)
          : AnchIcons.forTypeKey(item.typeKey),
      tag: item.isPinned ? '置顶' : null,
      statusLabel: isClosed ? '已注销' : null,
      repaymentDayBadge: repaymentDayBadge,
      billDayBadge: billDayBadge,
      expiryBadgeText: expiryBadgeText,
      expiryStatus: expiryStatus,
      daysUntilExpiry: daysUntilExpiry,
    );
  }

  static String _bankCardTitle(ItemModel item) {
    final title = (item.title == null || item.title!.trim().isEmpty)
        ? '未命名资料'
        : item.title!.trim();
    if (RegExp(r'（\d{4}）$').hasMatch(title)) return title;

    final primaryParts = item.primaryText
        ?.split(' · ')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    if (primaryParts != null) {
      for (final part in primaryParts) {
        final match = RegExp(r'^尾号\s*(\d{4})$').firstMatch(part);
        if (match != null) return '$title（${match.group(1)}）';
      }
    }
    return title;
  }

  static String _bankCardDescription({
    required ItemModel item,
    required String memberName,
    required String displayTitle,
  }) {
    final titleWithoutTail = displayTitle.replaceFirst(RegExp(r'（\d{4}）$'), '');
    final bankName = item.fieldValues['bank_name']?.trim();
    final legacyParts = item.primaryText
        ?.split(' · ')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              !RegExp(r'^尾号\s*\d{4}$').hasMatch(part) &&
              part != displayTitle &&
              part != titleWithoutTail &&
              part != '已注销',
        );
    final parts = <String>[
      if (memberName.isNotEmpty) memberName,
      if (item.fieldValues.containsKey('bank_name')) ...[
        if (bankName != null && bankName.isNotEmpty) bankName,
      ] else
        ...?legacyParts?.take(1),
    ];
    return parts.join(' · ');
  }
}
