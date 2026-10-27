enum ItemExpiryStatus {
  unsupported,
  missing,
  invalid,
  normal,
  upcoming,
  today,
  expired,
}

class ItemExpiryStatusResult {
  final ItemExpiryStatus status;
  final String? fieldKey;
  final DateTime? expiryDate;
  final int? daysUntilExpiry;
  final String? badgeText;
  final String? detailTitle;
  final String? detailMessage;
  final bool shouldShowListBadge;
  final bool shouldShowDetailBanner;

  const ItemExpiryStatusResult({
    required this.status,
    this.fieldKey,
    this.expiryDate,
    this.daysUntilExpiry,
    this.badgeText,
    this.detailTitle,
    this.detailMessage,
    required this.shouldShowListBadge,
    required this.shouldShowDetailBanner,
  });
}

class ItemExpiryStatusPolicy {
  static bool isBankCardClosed({
    required String? typeKey,
    required Map<String, dynamic>? rawState,
    String? primaryText,
  }) {
    if (typeKey != 'credit_card' && typeKey != 'debit_card') return false;
    final fields = rawState?['fields'];
    if (fields is Map && fields.containsKey('is_closed')) {
      final value = fields['is_closed']?.toString().trim().toLowerCase();
      return value == 'true' || value == '1';
    }
    return primaryText?.split(' · ').contains('已注销') ?? false;
  }

  /// 获取特定类型对应的到期字段 Key
  static String? getExpiryFieldKey(String? typeKey, {int? templateVersion}) {
    if (typeKey == null) return null;
    switch (typeKey) {
      case 'id_card':
      case 'credit_card':
      case 'passport':
      case 'hk_macao_pass':
      case 'driver_license':
      case 'generic':
        if (templateVersion != null && templateVersion >= 2) return null;
        return 'valid_until';
      case 'insurance':
        return 'end_date';
      default:
        return null;
    }
  }

  /// 判断特定类型是否支持到期提醒
  static bool supportsType(String? typeKey, {int? templateVersion}) {
    return getExpiryFieldKey(typeKey, templateVersion: templateVersion) != null;
  }

  /// 获取特定类型对应的到期字段 Key
  static String? expiryFieldKeyFor(String? typeKey, {int? templateVersion}) {
    return getExpiryFieldKey(typeKey, templateVersion: templateVersion);
  }

  /// 判定身份证是否为长期有效
  static bool isIdCardLongTerm(Map<String, dynamic> fields) {
    final isLongTermVal = fields['is_long_term'];
    if (isLongTermVal == null) return false;
    if (isLongTermVal is bool) return isLongTermVal;
    if (isLongTermVal is int) return isLongTermVal == 1;
    final strVal = isLongTermVal.toString().trim().toLowerCase();
    return strVal == 'true' || strVal == '1';
  }

  /// 根据模板类型、属性字段集合（rawState 中的 fields Map）和当前日期计算到期状态
  static ItemExpiryStatusResult calculate({
    required String? typeKey,
    int? templateVersion,
    required Map<String, dynamic>? rawState,
    required DateTime now,
    String? primaryText,
  }) {
    final fieldKey = getExpiryFieldKey(
      typeKey,
      templateVersion: templateVersion,
    );

    // 1. 如果不支持该类型的到期提醒
    if (fieldKey == null ||
        isBankCardClosed(
          typeKey: typeKey,
          rawState: rawState,
          primaryText: primaryText,
        )) {
      return const ItemExpiryStatusResult(
        status: ItemExpiryStatus.unsupported,
        shouldShowListBadge: false,
        shouldShowDetailBanner: false,
      );
    }

    final fields = (rawState != null && rawState['fields'] is Map)
        ? Map<String, dynamic>.from(rawState['fields'] as Map)
        : const <String, dynamic>{};

    // 2. 身份证长期有效规则判定
    if (typeKey == 'id_card' && isIdCardLongTerm(fields)) {
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.normal,
        fieldKey: fieldKey,
        shouldShowListBadge: false,
        shouldShowDetailBanner: false,
      );
    }

    final rawValue = fields[fieldKey];
    final String valStr = rawValue != null ? rawValue.toString().trim() : '';

    // 3. 空值/未填写判定
    if (valStr.isEmpty) {
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.missing,
        fieldKey: fieldKey,
        detailTitle: '未填写有效期',
        detailMessage: '请先填写有效期',
        shouldShowListBadge: false,
        shouldShowDetailBanner: true,
      );
    }

    // 身份证特别处理：如果用户在 valid_until 输入了“长期”字样，也要视为长期有效（normal）
    if (typeKey == 'id_card' && (valStr == '长期' || valStr == '长期有效')) {
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.normal,
        fieldKey: fieldKey,
        shouldShowListBadge: false,
        shouldShowDetailBanner: false,
      );
    }

    // 4. 日期解析判定
    final parsedDate = DateTime.tryParse(valStr);
    if (parsedDate == null) {
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.invalid,
        fieldKey: fieldKey,
        detailTitle: '有效期格式异常',
        detailMessage: '有效期格式异常，请检查',
        shouldShowListBadge: false,
        shouldShowDetailBanner: true,
      );
    }

    // 统一转换为纯日期（忽略时分秒）
    final today = DateTime(now.year, now.month, now.day);
    final expiryDate = DateTime(
      parsedDate.year,
      parsedDate.month,
      parsedDate.day,
    );

    final difference = expiryDate.difference(today);
    final daysUntilExpiry = difference.inDays;

    if (daysUntilExpiry < 0) {
      // 5. 已过期
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.expired,
        fieldKey: fieldKey,
        expiryDate: expiryDate,
        daysUntilExpiry: daysUntilExpiry,
        badgeText: '已过期',
        detailTitle: '已过期',
        detailMessage: '已过期，请更新有效期',
        shouldShowListBadge: true,
        shouldShowDetailBanner: true,
      );
    } else if (daysUntilExpiry == 0) {
      // 6. 今日到期
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.today,
        fieldKey: fieldKey,
        expiryDate: expiryDate,
        daysUntilExpiry: 0,
        badgeText: '今日到期',
        detailTitle: '今日到期',
        detailMessage: '今日到期',
        shouldShowListBadge: true,
        shouldShowDetailBanner: true,
      );
    } else if (daysUntilExpiry <= 30) {
      // 7. 即将到期（30 天内）
      final String badgeStr = daysUntilExpiry <= 7
          ? '剩余 $daysUntilExpiry 天'
          : '即将到期';
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.upcoming,
        fieldKey: fieldKey,
        expiryDate: expiryDate,
        daysUntilExpiry: daysUntilExpiry,
        badgeText: badgeStr,
        detailTitle: '即将到期',
        detailMessage: '即将到期，剩余 $daysUntilExpiry 天',
        shouldShowListBadge: true,
        shouldShowDetailBanner: true,
      );
    } else {
      // 8. 正常
      return ItemExpiryStatusResult(
        status: ItemExpiryStatus.normal,
        fieldKey: fieldKey,
        expiryDate: expiryDate,
        daysUntilExpiry: daysUntilExpiry,
        shouldShowListBadge: false,
        shouldShowDetailBanner: false,
      );
    }
  }
}
