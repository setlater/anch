import 'package:anch/app/dependency_provider.dart';
import 'package:anch/core/runtime/runtime_context.dart';
import 'package:anch/core/runtime/runtime_provider.dart';
import 'package:anch/core/security/anch_security_runtime_config.dart';
import 'package:anch/core/security/android_secure_window_service.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/screen_protection_controller.dart';
import 'package:anch/core/security/screen_protection_dependency_bundle.dart';
import 'package:anch/core/security/screen_protection_settings_manager.dart';
import 'package:anch/core/theme/anch_spacing.dart';
import 'package:anch/features/mine/mine_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_bootstrap.dart';

class _FakeSecureWindowService implements SecureWindowService {
  @override
  Future<void> setSecureWindowEnabled(bool enabled) async {}
}

void main() {
  testWidgets('安全设置分隔线唯一，状态按可用宽度重排且不挤窄标题', (tester) async {
    final RuntimeContext runtime = RuntimeProvider.create(
      const AnchSecurityRuntimeConfig(
        mode: AnchSecurityMode.dev,
        useEncryptedDatabase: false,
        enableSecureWindow: false,
        enablePrivacyShieldOverlay: false,
        enableAppLockGate: false,
        isFormalBlocked: false,
      ),
    );
    final settingsManager = SecureStorageScreenProtectionSettingsManager(
      store: MemorySecureKeyValueStore(),
    );
    final controller = ScreenProtectionController(
      settingsManager: settingsManager,
      secureWindowService: _FakeSecureWindowService(),
    );
    await controller.initialize();
    final dependencies = DependencyProvider.create(
      runtime: runtime,
      screenProtectionBundle: ScreenProtectionDependencyBundle(
        controller: controller,
        settingsManager: settingsManager,
      ),
      child: const SizedBox.shrink(),
    );
    addTearDown(dependencies.db.close);

    await tester.pumpWidget(
      wrapTest(
        const MaterialApp(home: MinePage()),
        runtime,
        (child) => dependencies.copyWith(child: child),
      ),
    );
    await tester.pumpAndSettle();

    final group = find.byKey(const ValueKey('mine_security_settings_group'));
    expect(group, findsOneWidget);
    expect(
      find.descendant(of: group, matching: find.byType(Divider)),
      findsOneWidget,
    );
    expect(find.text('限制敏感页面截图和录屏'), findsOneWidget);

    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in <double>[320, 600, 1000]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 1200);
        await tester.pumpWidget(
          wrapTest(
            MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const MinePage(),
            ),
            runtime,
            (child) => dependencies.copyWith(child: child),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('屏幕内容保护'), -100);
        final title = tester.renderObject<RenderParagraph>(find.text('屏幕内容保护'));
        final titleLayout = TextPainter(
          text: title.text,
          textDirection: title.textDirection,
          textScaler: title.textScaler,
        )..layout();
        expect(title.size.height, closeTo(titleLayout.height, 0.01));
        titleLayout.dispose();
        if (width == 320 && scale == 2) {
          expect(
            tester.getRect(find.text('仅敏感页面')).top,
            greaterThan(tester.getRect(find.text('限制敏感页面截图和录屏')).bottom),
          );
        }
        await tester.scrollUntilVisible(find.text('应用锁'), 100);
        final row = find.byKey(
          const ValueKey('mine_security_settings_app_lock'),
        );
        final badge = find.descendant(of: row, matching: find.text('未启用'));
        expect(
          tester.getRect(row).right - tester.getRect(badge).right,
          closeTo(AnchSpacing.sm, 0.01),
        );
        expect(tester.takeException(), isNull);
      }
    }
  });
}
