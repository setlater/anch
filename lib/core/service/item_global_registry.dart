import 'package:flutter/foundation.dart';

enum ItemEventType { saved, deleted, restored }

class ItemEvent {
  final ItemEventType type;
  final String itemId;

  const ItemEvent({required this.type, required this.itemId});
}

/// Runtime item event bus.
///
/// This class intentionally stores no item state. Pages may only listen for
/// events and reload their single source of truth from repository/usecase data.
class ItemGlobalRegistry extends ChangeNotifier {
  static final ItemGlobalRegistry instance = ItemGlobalRegistry._();
  ItemGlobalRegistry._();

  void emit(ItemEvent event) {
    notifyListeners();
  }

  void clear() {}
}
