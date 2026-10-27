import 'package:drift/drift.dart';

import 'items.dart';

/// 资料生命周期的低敏事件。
@TableIndex(
  name: 'idx_item_events_item_occurred',
  columns: {#itemId, #occurredAt},
)
class ItemEvents extends Table {
  TextColumn get id => text()();

  TextColumn get itemId =>
      text().references(Items, #id, onDelete: KeyAction.cascade)();

  TextColumn get eventType => text().check(
    const CustomExpression<bool>(
      "event_type IN ('created', 'updated', 'archived', 'unarchived', 'moved_to_trash', 'restored', 'imported')",
    ),
  )();

  IntColumn get occurredAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
