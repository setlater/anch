import 'package:anch/core/security/android_secure_window_service.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/screen_protection_controller.dart';
import 'package:anch/core/security/screen_protection_settings_manager.dart';
import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:anch/features/privacy/screen_protection_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecureWindowService implements SecureWindowService {
  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {}
}

void main() {
  testWidgets('三档设置可见，不限制需确认且取消不会改变选择', (tester) async {
    final controller = ScreenProtectionController(
      settingsManager: SecureStorageScreenProtectionSettingsManager(
        store: MemorySecureKeyValueStore(),
      ),
      secureWindowService: _FakeSecureWindowService(),
    );
    await controller.initialize();

    await tester.pumpWidget(
      MaterialApp(home: ScreenProtectionSettingsPage(controller: controller)),
    );

    expect(find.text('仅保护敏感页面'), findsOneWidget);
    expect(find.text('保护所有页面'), findsOneWidget);
    expect(find.text('不限制'), findsOneWidget);
    expect(
      find.byKey(const Key('screen_protection_selected_sensitiveOnly')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is AnchIcon && widget.icon == AnchIcons.radioUnchecked,
      ),
      findsNothing,
    );
    expect(find.textContaining('后台'), findsNothing);
    expect(find.textContaining('最近任务'), findsNothing);

    await tester.tap(find.text('不限制'));
    await tester.pumpAndSettle();
    expect(find.text('允许截屏和录屏？'), findsOneWidget);
    expect(find.textContaining('最近任务'), findsNothing);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(controller.mode, ScreenProtectionMode.sensitiveOnly);

    await tester.tap(find.text('不限制'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍然允许'));
    await tester.pumpAndSettle();
    expect(controller.mode, ScreenProtectionMode.unrestricted);
    expect(
      find.byKey(const Key('screen_protection_selected_unrestricted')),
      findsOneWidget,
    );

    await tester.tap(find.text('保护所有页面'));
    await tester.pumpAndSettle();
    expect(controller.mode, ScreenProtectionMode.always);
  });
}
