import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// 纯 SQL 数据源（不含业务逻辑、打分与别名）
class ItemQueryDataSource {
  final AppDatabase db;

  ItemQueryDataSource(this.db);

  /// 模糊查询活跃的资料记录
  Future<List<Item>> queryRawItemsByKeyword(String keyword) async {
    final pattern = '%$keyword%';
    return (db.select(db.items)..where(
          (tbl) =>
              tbl.status.equals('active') &
              (tbl.title.like(pattern) |
                  tbl.summaryText.like(pattern) |
                  tbl.searchText.like(pattern)),
        ))
        .get();
  }

  /// 在数据库内匹配银行卡尾号，只将资料 ID 带出加密数据库。
  Future<Set<String>> queryBankCardItemIdsBySuffix(String suffix) async {
    if (!RegExp(r'^\d{3,4}$').hasMatch(suffix)) return const {};
    final rows = await db
        .customSelect(
          '''
      SELECT DISTINCT f.item_id FROM item_fields f
      JOIN items i ON i.id = f.item_id
      WHERE i.status = 'active'
        AND (f.field_key IN ('card_number', 'bank_card_number')
             OR f.value_type = 'bank_card_number')
        AND (substr(trim(f.value_text), -?) = ?
             OR substr(trim(f.normalized_value), -?) = ?)
      ''',
          variables: [
            Variable<int>(suffix.length),
            Variable<String>(suffix),
            Variable<int>(suffix.length),
            Variable<String>(suffix),
          ],
          readsFrom: {db.items, db.itemFields},
        )
        .get();
    return {for (final row in rows) row.read<String>('item_id')};
  }
}
