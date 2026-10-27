import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'models/item_event_model.dart';

class ItemEventRepository {
  const ItemEventRepository(this.db);

  final AppDatabase db;

  Future<List<ItemEventModel>> getForItem(String itemId) async {
    final query = db.select(db.itemEvents)
      ..where((event) => event.itemId.equals(itemId))
      ..orderBy([
        (event) =>
            OrderingTerm(expression: event.occurredAt, mode: OrderingMode.desc),
        (event) => OrderingTerm(expression: event.id, mode: OrderingMode.desc),
      ]);
    final events = await query.get();
    return _mapEventsWithChanges(events);
  }

  Future<List<ItemEventModel>> getAll() async {
    final events =
        await (db.select(db.itemEvents)..orderBy([
              (event) => OrderingTerm(expression: event.occurredAt),
              (event) => OrderingTerm(expression: event.id),
            ]))
            .get();
    return _mapEventsWithChanges(events);
  }

  Future<List<ItemEventModel>> _mapEventsWithChanges(
    List<ItemEvent> events,
  ) async {
    if (events.isEmpty) return const [];
    final eventIds = events.map((event) => event.id).toList(growable: false);
    final rows =
        await (db.select(db.itemEventChanges)
              ..where((change) => change.eventId.isIn(eventIds))
              ..orderBy([
                (change) => OrderingTerm(expression: change.sortOrder),
                (change) => OrderingTerm(expression: change.id),
              ]))
            .get();
    final changesByEvent = <String, List<ItemEventChangeModel>>{};
    for (final row in rows) {
      changesByEvent
          .putIfAbsent(row.eventId, () => [])
          .add(
            ItemEventChangeModel(
              id: row.id,
              eventId: row.eventId,
              changeKind: ItemEventChangeKind.fromKey(row.changeKind),
              subjectKey: row.subjectKey,
              subjectLabel: row.subjectLabel,
              oldValue: row.oldValue,
              newValue: row.newValue,
              sortOrder: row.sortOrder,
            ),
          );
    }
    return events
        .map((event) => _mapEvent(event, changesByEvent[event.id] ?? const []))
        .toList(growable: false);
  }

  ItemEventModel _mapEvent(
    ItemEvent event,
    List<ItemEventChangeModel> changes,
  ) {
    return ItemEventModel(
      id: event.id,
      itemId: event.itemId,
      eventType: ItemEventType.fromKey(event.eventType),
      occurredAt: event.occurredAt,
      changes: changes,
    );
  }
}
