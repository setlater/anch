import '../repository/item_repository.dart';
import '../repository/models/item_model.dart';
import '../search/alias_registry.dart';
import '../runtime/runtime_context.dart';

class ItemSearchService {
  final RuntimeContext runtime;
  final ItemRepository itemRepo;

  ItemSearchService(this.runtime, {required this.itemRepo});

  /// 每次查询读取当前摘要，不缓存完整字段或截断待筛选候选。
  Future<List<ItemModel>> searchItems(String keyword) async {
    var query = keyword.trim().toLowerCase();
    if (query.isEmpty || isLikelyHighSensitiveIdentifier(query)) return [];
    if (RegExp(r'^\d{12,19}$').hasMatch(query)) {
      query = query.substring(query.length - 4);
    }

    final suffixIds = RegExp(r'^\d{3,4}$').hasMatch(query)
        ? await itemRepo.getBankCardItemIdsBySuffix(query)
        : null;
    final aliasTargets = <String>{
      for (final rule in AliasRegistry.rules)
        if (rule.key == query ||
            rule.targets.any((target) => target.toLowerCase() == query))
          ...rule.targets.map((target) => target.toLowerCase()),
    };
    final candidates = <_ScoredCandidate>[];
    for (final source in await itemRepo.getActiveItems()) {
      final item = source.toListSummary();
      if (suffixIds != null) {
        if (suffixIds.contains(item.id)) {
          candidates.add(_ScoredCandidate(item, 100));
        }
        continue;
      }
      final aliasText = '${item.title ?? ''} ${item.searchText ?? ''}'
          .toLowerCase();
      if (aliasTargets.any(aliasText.contains)) {
        candidates.add(_ScoredCandidate(item, 95));
      } else if ([
        item.title,
        item.summaryText,
        item.searchText,
      ].any((text) => text?.toLowerCase().contains(query) ?? false)) {
        candidates.add(_ScoredCandidate(item, 60));
      }
    }
    candidates.sort((a, b) {
      final scoreDiff = b.score.compareTo(a.score);
      if (scoreDiff != 0) return scoreDiff;
      final timeDiff = b.item.updatedAt.compareTo(a.item.updatedAt);
      return timeDiff != 0 ? timeDiff : a.item.id.compareTo(b.item.id);
    });
    return candidates.map((candidate) => candidate.item).toList();
  }

  static bool _isValidDate(int year, int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;

    final daysInMonth = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];

    bool isLeap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
    int maxDay = daysInMonth[month - 1];
    if (month == 2 && isLeap) {
      maxDay = 29;
    }

    return day <= maxDay;
  }

  static bool isLikelyIdNumber(String query) {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), '');

    // 18-digit ID
    if (RegExp(
      r'^\d{6}(18|19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]$',
    ).hasMatch(clean)) {
      final year = int.tryParse(clean.substring(6, 10)) ?? 0;
      final month = int.tryParse(clean.substring(10, 12)) ?? 0;
      final day = int.tryParse(clean.substring(12, 14)) ?? 0;
      return _isValidDate(year, month, day);
    }

    // 15-digit ID
    if (RegExp(
      r'^\d{6}\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}$',
    ).hasMatch(clean)) {
      final year = 1900 + (int.tryParse(clean.substring(6, 8)) ?? 0);
      final month = int.tryParse(clean.substring(8, 10)) ?? 0;
      final day = int.tryParse(clean.substring(10, 12)) ?? 0;
      return _isValidDate(year, month, day);
    }

    return false;
  }

  static bool isLikelyHighSensitiveIdentifier(String query) {
    final clean = query.trim().replaceAll(RegExp(r'\s+'), '');

    if (isLikelyIdNumber(clean)) return true;

    // VIN
    if (clean.length == 17 &&
        RegExp(r'^[a-hj-npr-zA-HJ-NPR-Z0-9]{17}$').hasMatch(clean) &&
        RegExp(r'[a-zA-Z]').hasMatch(clean)) {
      return true;
    }

    // Passport
    if (RegExp(r'^[a-zA-Z]{1,2}\d{6,9}$').hasMatch(clean)) {
      return true;
    }

    return false;
  }
}

class _ScoredCandidate {
  final ItemModel item;
  final int score;
  _ScoredCandidate(this.item, this.score);
}
