@Tags(['security'])
library;

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import '../support/anch_icon_finder.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_key_manager.dart';
import 'package:anch/core/security/app_pin_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_attempt_manager.dart';
import 'package:anch/core/security/app_biometric_authenticator.dart';
import 'package:anch/features/app_lock/app_lock_page.dart';
import 'package:anch/features/privacy/privacy_shield_controller.dart';
import 'package:anch/features/privacy/privacy_shield_coordinator.dart';
import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_theme.dart';

void main() {
  testWidgets('持久化冷却到期后无需重启即可输入 PIN，失败计数保持', (tester) async {
    final until = DateTime.now().millisecondsSinceEpoch + 30000;
    final attempts = AppLockAttemptManager(MemorySecureKeyValueStore());
    await attempts.save(
      AppLockAttemptState(failedAttempts: 5, lockedUntilMillis: until),
    );
    final controller = _CooldownClockController(
      until: until,
      attempts: attempts,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: AppLockPage(controller: controller)),
    );
    await tester.pump(const Duration(seconds: 29));
    await tester.tap(find.byKey(const Key('pin_digit_1')));
    await tester.pump();
    expect(_filledPinDotCount(tester), 0);
    expect(controller.value.status, AppLockStatus.temporarilyLocked);

    controller.nowMillis = until;
    await tester.pump(const Duration(seconds: 1));
    expect(controller.value.status, AppLockStatus.locked);
    expect(find.text('尝试次数过多，请稍后再试'), findsNothing);
    expect(controller.value.failedAttempts, 5);
    expect((await attempts.load()).failedAttempts, 5);
    await tester.tap(find.byKey(const Key('pin_digit_1')));
    await tester.pump();
    expect(_filledPinDotCount(tester), 1);
    await tester.pumpWidget(const SizedBox());
  });

  group('AppLockPage Widget 测试 — Prototype 模式', () {
    testWidgets('验证 1. 锁屏界面文案与初态展示', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      // 验证核心文案
      expect(find.text('安册已锁定'), findsOneWidget);
      expect(find.text('输入安册 PIN，或使用已启用的生物识别'), findsOneWidget);

      // 禁止的文案
      expect(find.text('正式安全模式已启用'), findsNothing);
      expect(find.text('可以录入真实敏感资料'), findsNothing);
      expect(find.text('生物识别已启用'), findsNothing);
      expect(find.text('PIN 已安全保存'), findsNothing);

      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const Key('pin_digit_1')), findsOneWidget);
      expect(_filledPinDotCount(tester), 0);
      final digitInk = tester.widget<InkWell>(
        find.descendant(
          of: find.byKey(const Key('pin_digit_1')),
          matching: find.byType(InkWell),
        ),
      );
      expect(digitInk.customBorder, isNull);
      expect(digitInk.splashFactory, NoSplash.splashFactory);
    });

    testWidgets('锁定主状态与忘记 PIN 操作消费主题语义色', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AnchTheme.light,
          home: AppLockPage(controller: controller, onForgotPin: () {}),
        ),
      );

      final colors = tester.element(find.byType(AppLockPage)).anchColors;
      expect(
        tester.widget<AnchIcon>(findAnchIcon(AnchIcons.lock)).color,
        colors.accent,
      );
      expect(
        tester.widget<Text>(find.text('忘记 PIN？')).style?.color,
        colors.danger,
      );
      expect(
        tester.getSize(find.byKey(const Key('pin_digit_1'))).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('验证 2. 模拟校验错误密码与正确密码', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      await _tapPin(tester, '111111');
      await tester.pumpAndSettle();

      // 验证提示错误
      expect(find.text('PIN 不正确'), findsOneWidget);
      expect(controller.value.status, AppLockStatus.locked);

      await _tapPin(tester, '123456');
      await tester.pumpAndSettle();

      // 解锁成功，错误提示消失
      expect(find.text('PIN 不正确'), findsNothing);
      expect(controller.value.status, AppLockStatus.unlocked);
    });

    testWidgets('验证 3. 超过最大尝试次数显示锁定提示', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
        maxFailedAttempts: 3,
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      // 输错 3 次
      for (var i = 0; i < 3; i++) {
        await _tapPin(tester, List.filled(6, '${i + 1}').join());
        await tester.pumpAndSettle();
      }

      // 验证提示次数过多
      expect(find.text('尝试次数过多，请稍后再试'), findsOneWidget);
      expect(controller.value.status, AppLockStatus.temporarilyLocked);

      await tester.tap(find.byKey(const Key('pin_digit_1')));
      await tester.pump();
      expect(_filledPinDotCount(tester), 0);
    });

    testWidgets('验证 4. onForgotPin 传入与点击回调', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );

      // A. 当 onForgotPin 为 null 时，默认不展示 “忘记 PIN？”
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(controller: controller, onForgotPin: null),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('忘记 PIN？'), findsNothing);

      // B. 当 onForgotPin 不为 null 时，展示 “忘记 PIN？”，点击能触发回调
      var forgotPinCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(
            controller: controller,
            onForgotPin: () {
              forgotPinCalled = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('忘记 PIN？'), findsOneWidget);

      await tester.tap(find.text('忘记 PIN？'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除本机资料'));
      await tester.pumpAndSettle();
      expect(forgotPinCalled, isTrue);
    });
  });

  group('AppLockPage Widget 测试 — 真实 AppPinManager 模式', () {
    late MemorySecureKeyValueStore store;
    late SecureStorageAppPinManager pinManager;

    setUp(() async {
      store = MemorySecureKeyValueStore();
      pinManager = SecureStorageAppPinManager(store: store, iterations: 10);
      await pinManager.setPin('123456');
    });

    testWidgets('验证 4. 真实 PIN 解锁成功', (tester) async {
      final fakePinManager = FakeDelayPinManager('123456', autoComplete: false);
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: fakePinManager,
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      await _tapPin(tester, '123456');

      // 因为 verifyPin 是异步操作，此处需要 pump 并等待 Future 完成
      await tester.pump(); // 开始验证，进入 Loading/正在验证...
      expect(find.text('正在验证…'), findsOneWidget);

      fakePinManager.completeVerify(true);
      await tester.pumpAndSettle(); // 验证完成

      expect(controller.value.status, AppLockStatus.unlocked);
      expect(find.text('PIN 不正确'), findsNothing);

      // 校验界面绝对不包含密码/salt/verifier 等明文或误导文案
      expect(find.text('123456'), findsNothing);
      expect(find.text('anch.app_pin.salt.v1'), findsNothing);
      expect(find.text('正式安全模式已启用'), findsNothing);
      expect(find.text('可以录入真实敏感资料'), findsNothing);
    });

    testWidgets('验证 5. 真实 PIN 校验失败并显示报错', (tester) async {
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: pinManager,
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      await _tapPin(tester, '111111');
      await tester.pumpAndSettle();

      expect(find.text('PIN 不正确'), findsOneWidget);
      expect(controller.value.status, AppLockStatus.locked);
    });

    testWidgets('验证 6. 异步校验防重复点击', (tester) async {
      final fakePinManager = FakeDelayPinManager('123456', autoComplete: false);

      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        appPinManager: fakePinManager,
      );

      await tester.pumpWidget(
        MaterialApp(home: AppLockPage(controller: controller)),
      );

      await _tapPin(tester, '123456');
      await tester.pump(); // 进入 _isUnlocking = true 状态

      expect(find.text('正在验证…'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pin_digit_1')));
      await tester.pump();
      expect(_filledPinDotCount(tester), 6);

      fakePinManager.completeVerify(true);
      await tester.pumpAndSettle(); // 等待异步完成
      expect(controller.value.status, AppLockStatus.unlocked);
    });

    testWidgets('熄屏中断未返回的生物认证后恢复 PIN，且忽略迟到成功结果', (tester) async {
      final authenticator = _ControllableBiometricAuthenticator();
      final controller = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AppLockPage(
            controller: controller,
            biometricAuthenticator: authenticator,
            biometricEnabled: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('正在验证…'), findsOneWidget);
      expect(controller.value.status, AppLockStatus.unlocking);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(authenticator.cancelCount, 1);
      expect(controller.value.status, AppLockStatus.locked);
      expect(find.text('正在验证…'), findsNothing);

      await tester.tap(find.byKey(const Key('pin_digit_1')));
      await tester.pump();
      expect(_filledPinDotCount(tester), 1);

      authenticator.complete(AppBiometricResult.success);
      await tester.pump();
      expect(controller.value.status, AppLockStatus.locked);
      expect(_filledPinDotCount(tester), 1);
    });
  });

  group('AppLockPage PrivacyShield 防窥信号测试', () {
    late AppLockController lockController;
    late PrivacyShieldController shieldController;
    late PrivacyShieldCoordinator coordinator;

    setUp(() {
      lockController = AppLockController(
        initialState: const AppLockState(status: AppLockStatus.locked),
        prototypePin: '123456',
      );
      shieldController = PrivacyShieldController();
      coordinator = PrivacyShieldCoordinator(
        controller: shieldController,
        source: PrivacyShieldSource.appLockInput,
      );
    });

    Widget buildTestWidget({PrivacyShieldCoordinator? shieldCoordinator}) {
      return MaterialApp(
        home: AppLockPage(
          controller: lockController,
          privacyShieldCoordinator: shieldCoordinator,
        ),
      );
    }

    testWidgets('1. 未注入 coordinator 时，AppLockPage 正常解锁且不崩溃', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('安册已锁定'), findsOneWidget);

      await _tapPin(tester, '123456');
      await tester.pumpAndSettle();

      // 解锁成功，输入清空且没有发生崩溃
      expect(lockController.value.status, AppLockStatus.unlocked);
    });

    testWidgets('2. 前台输入 PIN 不触发全屏遮罩', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(shieldCoordinator: coordinator));
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);

      await _tapPin(tester, '123');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('pin_backspace')));
        await tester.pump();
      }
      expect(_filledPinDotCount(tester), 0);
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);
    });

    testWidgets('3. 进入后台时清空 PIN 输入', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(shieldCoordinator: coordinator));
      await tester.pumpAndSettle();

      await _tapPin(tester, '123');
      await tester.pump();
      expect(_filledPinDotCount(tester), 3);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();

      expect(_filledPinDotCount(tester), 0);
      expect(shieldController.isVisible, isFalse);
      expect(shieldController.activeSources, isEmpty);
    });

    testWidgets('4. 输入正确 PIN 并解锁成功后不残留页面级遮罩', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestWidget(shieldCoordinator: coordinator));
      await tester.pumpAndSettle();

      expect(shieldController.isVisible, isFalse);

      await _tapPin(tester, '123456');
      await tester.pump();
      expect(shieldController.isVisible, isFalse);
      await tester.pumpAndSettle();

      // 解锁成功后，密码框清空，isVisible 变为 false
      expect(lockController.value.status, AppLockStatus.unlocked);
      expect(shieldController.isVisible, isFalse);
    });

    testWidgets('5. 暂时锁定 temporarilyLocked 后自动清空输入', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(shieldCoordinator: coordinator));
      await tester.pumpAndSettle();

      // 错误密码解锁 5 次以触发暂时锁定
      for (int i = 0; i < 5; i++) {
        await _tapPin(tester, '111111');
        await tester.pump();
        expect(shieldController.isVisible, isFalse);
        await tester.pumpAndSettle();
      }

      // 暂时锁定后输入框被禁用清空，isVisible应自动恢复为 false
      expect(lockController.value.status, AppLockStatus.temporarilyLocked);
      expect(shieldController.isVisible, isFalse);
    });

    testWidgets('6. 页面销毁不清除其它页面的遮罩来源', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/': (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/lock'),
                child: const Text('Go'),
              ),
            ),
            '/lock': (context) => AppLockPage(
              controller: lockController,
              privacyShieldCoordinator: coordinator,
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // 手动触发其它活跃来源
      shieldController.show(PrivacyShieldSource.itemDetail);

      // 前往锁定页
      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      await _tapPin(tester, '123');
      await tester.pump();
      expect(shieldController.activeSources, {PrivacyShieldSource.itemDetail});

      // 返回以 dispose
      final navigatorState = tester.state<NavigatorState>(
        find.byType(Navigator),
      );
      navigatorState.pop();
      await tester.pumpAndSettle();

      // 验证销毁后只清了 appLockInput 来源，itemDetail 仍在
      expect(shieldController.isVisible, isTrue);
      expect(shieldController.activeSources, {PrivacyShieldSource.itemDetail});
    });
  });
}

Future<void> _tapPin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.byKey(Key('pin_digit_$digit')));
    await tester.pump();
  }
}

int _filledPinDotCount(WidgetTester tester) {
  var count = 0;
  for (var index = 0; index < 6; index++) {
    final dot = tester.widget<Container>(find.byKey(Key('pin_dot_$index')));
    final decoration = dot.decoration! as BoxDecoration;
    if (decoration.color != Colors.transparent) count++;
  }
  return count;
}

class _CooldownClockController extends AppLockController {
  _CooldownClockController({
    required int until,
    required AppLockAttemptManager attempts,
  }) : nowMillis = until - 30000,
       super(
         initialState: AppLockState(
           status: AppLockStatus.temporarilyLocked,
           failedAttempts: 5,
           lockedUntilMillis: until,
         ),
         attemptManager: attempts,
       );

  int nowMillis;

  @override
  void checkTemporaryLockExpiry([int? ignored]) {
    super.checkTemporaryLockExpiry(nowMillis);
  }
}

class FakeDelayPinManager implements AppPinManager {
  final String correctPin;
  final bool autoComplete;
  Completer<bool>? _verifyCompleter;

  FakeDelayPinManager(this.correctPin, {this.autoComplete = true});

  @override
  Future<bool> hasPin() async => true;

  @override
  Future<void> setPin(String pin) async {}

  @override
  Future<bool> verifyPin(String pin) {
    _verifyCompleter = Completer<bool>();
    if (autoComplete) {
      _verifyCompleter!.complete(pin == correctPin);
    }
    return _verifyCompleter!.future;
  }

  @override
  Future<void> clearPin() async {}

  void completeVerify(bool result) {
    if (_verifyCompleter != null && !_verifyCompleter!.isCompleted) {
      _verifyCompleter!.complete(result);
    }
  }
}

class _ControllableBiometricAuthenticator implements AppBiometricAuthenticator {
  final Completer<AppBiometricResult> _result = Completer();
  int cancelCount = 0;

  @override
  Future<AppBiometricResult> authenticate() => _result.future;

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  Future<AppBiometricAvailability> getAvailability() async =>
      AppBiometricAvailability.available;

  void complete(AppBiometricResult result) => _result.complete(result);
}
