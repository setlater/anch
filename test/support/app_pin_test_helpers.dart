import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> tapAppPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_digit_$digit')));
    await tester.pump();
  }
}
