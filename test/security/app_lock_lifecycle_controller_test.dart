@Tags(['security'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anch/core/security/app_lock_controller.dart';
import 'package:anch/core/security/app_lock_lifecycle_controller.dart';
import 'package:anch/core/security/app_lock_preferences_manager.dart';
import 'package:anch/core/security/app_lock_state.dart';

/// [AppLockLifecycleController] 单元测试。
///
/// 验证各种 App 状态下，生命周期事件是否正确触发锁定行为。
///
/// 测试策略：
/// - 注入 [nowMillis] 函数以控制时间，避免依赖系统时钟。
/// - 不读取 Secure Storage，不依赖 MainShell，不修改 main.dart。
void main() {
  // ----------------------------------------------------------------
  // 辅助方法
  // ----------------------------------------------------------------

  /// 创建处于指定状态的控制器。
  AppLockController makeController(AppLockStatus status) {
    return AppLockController(
      initialState: AppLockState(status: status),
      prototypePin: 'TEST-1234',
    );
  }

  /// 创建生命周期控制器，允许注入固定时间戳列表（按顺序返回）。
  AppLockLifecycleController makeLifecycleController({
    required AppLockController controller,
    required List<int> timestamps,
    AppLockAutoLockMode mode = AppLockAutoLockMode.everyForeground,
  }) {
    int callCount = 0;
    return AppLockLifecycleController(
      appLockController: controller,
      autoLockMode: mode,
      nowMillis: () {
        final t =
            timestamps[callCount < timestamps.length
                ? callCount
                : timestamps.length - 1];
        callCount++;
        return t;
      },
    );
  }

  // ----------------------------------------------------------------
  // 测试用例
  // ----------------------------------------------------------------

  group('AppLockLifecycleController 单元测试', () {
    // ----------------------------------------------------------------
    // 验证 unlocked 状态的两种自动锁定模式。
    // ----------------------------------------------------------------

    group('unlocked 状态生命周期验证', () {
      test('验证 1. 真实进入后台后回到安册时立即锁定，不等待时长', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 30999],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        expect(controller.value.status, AppLockStatus.unlocked);

        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);
      });

      test('验证 2. 真实进入后台后回到安册时保持锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 31000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        expect(controller.value.status, AppLockStatus.unlocked);

        lc.handleLifecycleState(AppLifecycleState.resumed);
        // diff = 31000 - 1000 = 30000 >= 30000，应锁定
        expect(controller.value.status, AppLockStatus.locked);
      });

      test('验证 2b. 后台停留更久后回到安册时保持锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 61000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);
      });

      test('受控系统文件选择器往返不锁定，后续普通后台仍会锁定', () async {
        final controller = makeController(AppLockStatus.unlocked);
        var now = 1000;
        final lc = AppLockLifecycleController(
          appLockController: controller,
          autoLockMode: AppLockAutoLockMode.everyForeground,
          nowMillis: () => now,
        );

        await lc.runWhileSystemUiLockSuppressed(() async {
          lc.handleLifecycleState(AppLifecycleState.inactive);
          lc.handleLifecycleState(AppLifecycleState.hidden);
          lc.handleLifecycleState(AppLifecycleState.paused);
          now = 61000;
          lc.handleLifecycleState(AppLifecycleState.hidden);
          lc.handleLifecycleState(AppLifecycleState.inactive);
          lc.handleLifecycleState(AppLifecycleState.resumed);
        });
        expect(controller.value.status, AppLockStatus.unlocked);

        now = 70000;
        lc.handleLifecycleState(AppLifecycleState.inactive);
        lc.handleLifecycleState(AppLifecycleState.hidden);
        lc.handleLifecycleState(AppLifecycleState.paused);
        now = 101000;
        lc.handleLifecycleState(AppLifecycleState.hidden);
        lc.handleLifecycleState(AppLifecycleState.inactive);
        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);
      });

      test('重新打开安册时模式在普通前后台往返中不锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 1001],
          mode: AppLockAutoLockMode.nextLaunch,
        );

        lc.handleLifecycleState(AppLifecycleState.hidden);
        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);

        expect(controller.value.status, AppLockStatus.unlocked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 3. disabledForDev 不被生命周期事件锁定
    // ----------------------------------------------------------------

    group('disabledForDev 状态生命周期验证', () {
      test('验证 3. disabledForDev 下 paused+resumed，仍保持 disabledForDev', () {
        final controller = makeController(AppLockStatus.disabledForDev);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 61000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);

        expect(controller.value.status, AppLockStatus.disabledForDev);
      });
    });

    // ----------------------------------------------------------------
    // 验证 4. locked 状态不被生命周期事件错误解锁
    // ----------------------------------------------------------------

    group('locked 状态生命周期验证', () {
      test('验证 4. locked 下 paused+resumed，保持 locked', () {
        final controller = makeController(AppLockStatus.locked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 61000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        expect(controller.value.status, AppLockStatus.locked);

        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 5. temporarilyLocked 状态不被生命周期事件解锁
    // ----------------------------------------------------------------

    group('temporarilyLocked 状态生命周期验证', () {
      test('验证 5. temporarilyLocked 下 paused+resumed，保持 temporarilyLocked', () {
        final controller = AppLockController(
          initialState: AppLockState(
            status: AppLockStatus.temporarilyLocked,
            failedAttempts: 5,
            lockedUntilMillis: 999999999,
          ),
        );
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 61000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        expect(controller.value.status, AppLockStatus.temporarilyLocked);

        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.temporarilyLocked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 6. 多次 paused：后一次后台时间覆盖前一次
    // ----------------------------------------------------------------

    group('多次 paused 行为验证', () {
      test('验证 6. 多次 paused 后回到安册仍会锁定', () {
        // 行为定义：markBackgrounded 总是以最新传入的 nowMillis 覆盖。
        // 因此多次 paused 时，以最后一次记录的后台时间为准。
        final controller = makeController(AppLockStatus.unlocked);
        // 时间序列：paused at 1000，再次 paused at 5000，resumed at 34999
        // 以最后一次 paused=5000 计算：diff=34999-5000=29999 < 30000，不锁定
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 5000, 34999],
        );

        lc.handleLifecycleState(AppLifecycleState.paused); // at 1000
        lc.handleLifecycleState(AppLifecycleState.paused); // at 5000（覆盖）
        lc.handleLifecycleState(AppLifecycleState.resumed); // at 34999

        expect(controller.value.status, AppLockStatus.locked);
      });

      test('验证 6b. 多次 paused 后回到安册时保持锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        // 时间序列：paused at 1000，再次 paused at 5000，resumed at 40000
        // 以最后一次 paused=5000 计算：diff=40000-5000=35000 >= 30000，锁定
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 5000, 40000],
        );

        lc.handleLifecycleState(AppLifecycleState.paused); // at 1000
        lc.handleLifecycleState(AppLifecycleState.paused); // at 5000（覆盖）
        lc.handleLifecycleState(AppLifecycleState.resumed); // at 40000

        expect(controller.value.status, AppLockStatus.locked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 7. inactive / hidden 事件也记录后台时间
    // ----------------------------------------------------------------

    group('inactive / hidden 事件验证', () {
      test('验证 7a. 通知栏等仅触发 inactive 的短暂失焦不会锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 32000],
        );

        lc.handleLifecycleState(AppLifecycleState.inactive); // at 1000
        lc.handleLifecycleState(AppLifecycleState.resumed); // at 32000

        expect(controller.value.status, AppLockStatus.unlocked);
      });

      test('验证 7b. hidden 事件表示真正后台，resumed 后锁定', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 31001],
        );

        lc.handleLifecycleState(AppLifecycleState.hidden); // at 1000
        lc.handleLifecycleState(AppLifecycleState.resumed); // at 31001

        // diff = 31001 - 1000 = 30001 >= 30000，锁定
        expect(controller.value.status, AppLockStatus.locked);
      });

      test('验证 7c. paused 事件记录后台时间（基准测试）', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000, 31001],
        );

        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);

        expect(controller.value.status, AppLockStatus.locked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 8. detached 不触发锁定/解锁（本批不特殊处理）
    // ----------------------------------------------------------------

    group('detached 事件验证', () {
      test('验证 8. detached 事件不改变 unlocked 状态', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = makeLifecycleController(
          controller: controller,
          timestamps: [1000],
        );

        lc.handleLifecycleState(AppLifecycleState.detached);
        // detached 本批不特殊处理，状态不变
        expect(controller.value.status, AppLockStatus.unlocked);
      });
    });

    // ----------------------------------------------------------------
    // 验证 dispose
    // ----------------------------------------------------------------

    group('dispose 验证', () {
      test('验证 dispose 可以安全调用（纯控制器模式无副作用）', () {
        final controller = makeController(AppLockStatus.unlocked);
        final lc = AppLockLifecycleController(
          appLockController: controller,
          autoLockMode: AppLockAutoLockMode.everyForeground,
        );

        // dispose 不应抛出异常
        expect(() => lc.dispose(), returnsNormally);
      });
    });

    // ----------------------------------------------------------------
    // 综合场景
    // ----------------------------------------------------------------

    group('综合场景验证', () {
      test('unlocked → paused → resumed → locked', () {
        final controller = makeController(AppLockStatus.unlocked);
        int callCount = 0;
        // 时间序列覆盖两次前后台往返。
        final timestamps = [100000, 120000, 200000, 240000];
        final lc = AppLockLifecycleController(
          appLockController: controller,
          autoLockMode: AppLockAutoLockMode.everyForeground,
          nowMillis: () => timestamps[callCount++],
        );

        // 第一次真实切后台再回来即锁定。
        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);

        // 已锁定后再次切后台仍保持锁定。
        lc.handleLifecycleState(AppLifecycleState.paused);
        lc.handleLifecycleState(AppLifecycleState.resumed);
        expect(controller.value.status, AppLockStatus.locked);
      });
    });
  });
}
