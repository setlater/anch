import 'package:drift/drift.dart';

import 'item_events.dart';

/// 资料事件的低敏结构化变更明细。
@TableIndex(
  name: 'idx_item_event_changes_event_sort',
  columns: {#eventId, #sortOrder},
)
class ItemEventChanges extends Table {
  TextColumn get id => text()();

  TextColumn get eventId =>
      text().references(ItemEvents, #id, onDelete: KeyAction.cascade)();

  TextColumn get changeKind => text().check(
    const CustomExpression<bool>(
      "change_kind IN ('value_changed', 'field_changed', 'attachment_count_changed')",
    ),
  )();

  TextColumn get subjectKey => text()();

  TextColumn get subjectLabel => text()();

  TextColumn get oldValue => text().nullable()();

  TextColumn get newValue => text().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (length(subject_key) > 0 AND length(subject_label) > 0)',
    "CHECK ((change_kind = 'field_changed' AND old_value IS NULL AND new_value IS NULL) "
        "OR (change_kind IN ('value_changed', 'attachment_count_changed') "
        'AND old_value IS NOT NULL AND new_value IS NOT NULL))',
  ];
}
