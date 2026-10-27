import 'package:flutter/foundation.dart';

class MainShellController extends ValueNotifier<int> {
  MainShellController() : super(homeIndex);

  static const int homeIndex = 0;

  void selectTab(int index) {
    if (value == index) return;
    value = index;
  }

  void goHome() => selectTab(homeIndex);
}
