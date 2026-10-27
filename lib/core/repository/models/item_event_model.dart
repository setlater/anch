enum ItemEventType {
  created('created'),
  updated('updated'),
  archived('archived'),
  unarchived('unarchived'),
  movedToTrash('moved_to_trash'),
  restored('restored'),
  imported('imported');

  const ItemEventType(this.key);

  final String key;

  static ItemEventType fromKey(String key) {
    return ItemEventType.values.firstWhere(
      (type) => type.key == key,
      orElse: () => throw StateError('不支持的资料事件类型'),
    );
  }
}

class ItemEventModel {
  const ItemEventModel({
    required this.id,
    required this.itemId,
    required this.eventType,
    required this.occurredAt,
    this.changes = const [],
  });

  final String id;
  final String itemId;
  final ItemEventType eventType;
  final int occurredAt;
  final List<ItemEventChangeModel> changes;
}

enum ItemEventChangeKind {
  valueChanged('value_changed'),
  fieldChanged('field_changed'),
  attachmentCountChanged('attachment_count_changed');

  const ItemEventChangeKind(this.key);

  final String key;

  static ItemEventChangeKind fromKey(String key) {
    return ItemEventChangeKind.values.firstWhere(
      (kind) => kind.key == key,
      orElse: () => throw StateError('不支持的资料事件变更类型'),
    );
  }
}

class ItemEventChangeModel {
  const ItemEventChangeModel({
    required this.id,
    required this.eventId,
    required this.changeKind,
    required this.subjectKey,
    required this.subjectLabel,
    required this.oldValue,
    required this.newValue,
    required this.sortOrder,
  });

  final String id;
  final String eventId;
  final ItemEventChangeKind changeKind;
  final String subjectKey;
  final String subjectLabel;
  final String? oldValue;
  final String? newValue;
  final int sortOrder;
}
