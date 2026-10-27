import 'dart:async';

import 'package:anch/app/app_session_restart_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('并发重建请求只执行一次，完成后允许下一次重建', () async {
    final firstRestart = Completer<void>();
    var restartCalls = 0;
    final controller = AppSessionRestartController(
      restartSessionCallback: () {
        restartCalls++;
        return firstRestart.future;
      },
    );

    final first = controller.restart();
    final duplicate = controller.restart();
    expect(restartCalls, 1);

    firstRestart.complete();
    await Future.wait([first, duplicate]);

    await controller.restart();
    expect(restartCalls, 2);
  });
}
