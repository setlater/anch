import 'package:flutter/material.dart';

/// Centralized Key Registry for widget tests.
/// Production UI code can use inline Key() but all keys used in /test MUST come from here.
class KeyRegistry {
  // Pattern: {domain}_{entity}_{action}
  static const Key flowButtonNext = Key('flow_button_next');
  static const Key flowButtonPrev = Key('flow_button_prev');
  static const Key flowButtonSave = Key('flow_button_save');
  static const Key typeCardIdCard = Key('type_card_id_card');
  static const Key typeCardDebitCard = Key('type_card_debit_card');
  static const Key ownerCardFamily = Key('owner_card_family');
  static const Key homeButtonAdd = Key('home_button_add');
}
