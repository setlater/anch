import 'package:flutter/foundation.dart';
import 'app_biometric_authenticator.dart';
import 'app_lock_attempt_manager.dart';
import 'app_lock_state.dart';
import 'app_pin_manager.dart';

class AppLockController extends ValueNotifier<AppLockState> {
  final String prototypePin;
  final AppPinManager? appPinManager;
  final AppLockAttemptManager? attemptManager;
  final int maxFailedAttempts;
  final int temporaryLockMillis;
  bool _isSystemAuthenticationInProgress = false;
  int _biometricUnlockGeneration = 0;
  AppLockState? _biometricUnlockPreviousState;
  bool _pinStorageUnavailable = false;
  bool biometricEnabled;
  bool appLockEnabled;

  AppLockController({
    AppLockState initialState = const AppLockState(
      status: AppLockStatus.disabledForDev,
    ),
    this.prototypePin = 'TEST-1234',
    this.appPinManager,
    this.attemptManager,
    this.maxFailedAttempts = 5,
    this.temporaryLockMillis = 30000,
    this.biometricEnabled = false,
    this.appLockEnabled = false,
  }) : super(initialState);

  bool get isSystemAuthenticationInProgress =>
      _isSystemAuthenticationInProgress;

  bool get pinStorageUnavailable => _pinStorageUnavailable;

  void updateBiometricEnabled(bool enabled) {
    biometricEnabled = enabled;
    notifyListeners();
  }

  void updateAppLockEnabled(bool enabled) {
    appLockEnabled = enabled;
    notifyListeners();
  }

  void lock() {
    if (value.status == AppLockStatus.unlocked) {
      value = AppLockState(
        status: AppLockStatus.locked,
        failedAttempts: value.failedAttempts,
        lockedUntilMillis: value.lockedUntilMillis,
        lastUnlockedAtMillis: value.lastUnlockedAtMillis,
        lastBackgroundAtMillis: value.lastBackgroundAtMillis,
      );
    }
  }

  bool unlockWithPrototypePin(String pin, [int? nowMillis]) {
    if (appPinManager != null) {
      // 真实 PIN 校验路径应调用异步方法 unlockWithPin
      return false;
    }

    final currentNow = nowMillis ?? DateTime.now().millisecondsSinceEpoch;

    // 检查是否在临时锁定期间
    if (value.status == AppLockStatus.temporarilyLocked) {
      if (value.lockedUntilMillis != null &&
          currentNow < value.lockedUntilMillis!) {
        // 仍在锁定期间，拒绝解锁
        return false;
      } else {
        // 锁定到期，先切回 locked 状态，重置失败次数，要求重新输入
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: attemptManager == null ? 0 : value.failedAttempts,
          lockedUntilMillis: null,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
        return false;
      }
    }

    if (value.status != AppLockStatus.locked &&
        value.status != AppLockStatus.unlocking) {
      return false;
    }

    // 切换为解锁中状态
    value = AppLockState(
      status: AppLockStatus.unlocking,
      failedAttempts: value.failedAttempts,
      lockedUntilMillis: value.lockedUntilMillis,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: value.lastBackgroundAtMillis,
    );

    if (pin == prototypePin) {
      value = AppLockState(
        status: AppLockStatus.unlocked,
        failedAttempts: 0,
        lockedUntilMillis: null,
        lastUnlockedAtMillis: currentNow,
        lastBackgroundAtMillis: value.lastBackgroundAtMillis,
      );
      return true;
    } else {
      final newFailed = value.failedAttempts + 1;
      if (newFailed >= maxFailedAttempts) {
        final lockedUntil = currentNow + temporaryLockMillis;
        value = AppLockState(
          status: AppLockStatus.temporarilyLocked,
          failedAttempts: newFailed,
          lockedUntilMillis: lockedUntil,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
      } else {
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: newFailed,
          lockedUntilMillis: null,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
      }
      return false;
    }
  }

  Future<bool> unlockWithPin(String pin, {int? nowMillis}) async {
    if (_pinStorageUnavailable || value.status == AppLockStatus.unlocking) {
      return false;
    }
    final currentNow = nowMillis ?? DateTime.now().millisecondsSinceEpoch;

    // 检查是否在临时锁定期间
    if (value.status == AppLockStatus.temporarilyLocked) {
      if (value.lockedUntilMillis != null &&
          currentNow < value.lockedUntilMillis!) {
        // 仍在锁定期间，拒绝解锁
        return false;
      } else {
        // 锁定到期，先切回 locked 状态，重置失败次数，要求重新输入
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: attemptManager == null ? 0 : value.failedAttempts,
          lockedUntilMillis: null,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
        return false;
      }
    }

    if (value.status != AppLockStatus.locked &&
        value.status != AppLockStatus.unlocking) {
      return false;
    }

    // 切换为解锁中状态
    value = AppLockState(
      status: AppLockStatus.unlocking,
      failedAttempts: value.failedAttempts,
      lockedUntilMillis: value.lockedUntilMillis,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: value.lastBackgroundAtMillis,
    );

    // 校验前先保留本次尝试，中断或重启不能抹去已经发起的 PIN 尝试。
    var newFailed = value.failedAttempts + 1;
    try {
      final persisted = await attemptManager?.load();
      final lockedUntil = persisted?.lockedUntilMillis;
      if (lockedUntil != null && lockedUntil > currentNow) {
        value = AppLockState(
          status: AppLockStatus.temporarilyLocked,
          failedAttempts: persisted!.failedAttempts,
          lockedUntilMillis: lockedUntil,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
        return false;
      }
      if (persisted != null && persisted.failedAttempts >= newFailed) {
        newFailed = persisted.failedAttempts + 1;
      }
      await attemptManager?.save(
        AppLockAttemptState(
          failedAttempts: newFailed,
          lockedUntilMillis: newFailed >= maxFailedAttempts
              ? currentNow + _cooldownMillis(newFailed)
              : null,
        ),
      );
    } catch (_) {
      _pinStorageUnavailable = true;
      value = AppLockState(
        status: AppLockStatus.locked,
        failedAttempts: value.failedAttempts,
        lockedUntilMillis: value.lockedUntilMillis,
        lastUnlockedAtMillis: value.lastUnlockedAtMillis,
        lastBackgroundAtMillis: value.lastBackgroundAtMillis,
      );
      return false;
    }

    bool isCorrect = false;
    try {
      if (appPinManager != null) {
        isCorrect = await appPinManager!.verifyPin(pin);
      } else {
        isCorrect = (pin == prototypePin);
      }
    } catch (_) {
      isCorrect = false;
    }

    if (isCorrect) {
      await _completeSuccessfulUnlock(currentNow);
      return true;
    } else {
      if (newFailed >= maxFailedAttempts) {
        final lockedUntil = currentNow + _cooldownMillis(newFailed);
        value = AppLockState(
          status: AppLockStatus.temporarilyLocked,
          failedAttempts: newFailed,
          lockedUntilMillis: lockedUntil,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
      } else {
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: newFailed,
          lockedUntilMillis: null,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
      }
      return false;
    }
  }

  Future<AppBiometricResult> unlockWithBiometric(
    AppBiometricAuthenticator authenticator, {
    int? nowMillis,
  }) async {
    if (_isSystemAuthenticationInProgress ||
        (value.status != AppLockStatus.locked &&
            value.status != AppLockStatus.temporarilyLocked)) {
      return AppBiometricResult.busy;
    }
    final previous = value;
    final generation = ++_biometricUnlockGeneration;
    _biometricUnlockPreviousState = previous;
    _isSystemAuthenticationInProgress = true;
    value = AppLockState(
      status: AppLockStatus.unlocking,
      failedAttempts: previous.failedAttempts,
      lockedUntilMillis: previous.lockedUntilMillis,
      lastUnlockedAtMillis: previous.lastUnlockedAtMillis,
      lastBackgroundAtMillis: previous.lastBackgroundAtMillis,
    );
    AppBiometricResult result;
    try {
      result = await authenticator.authenticate();
    } catch (_) {
      result = AppBiometricResult.unavailable;
    }
    if (generation != _biometricUnlockGeneration) {
      return AppBiometricResult.cancelled;
    }
    _isSystemAuthenticationInProgress = false;
    _biometricUnlockPreviousState = null;
    if (result == AppBiometricResult.success) {
      await _completeSuccessfulUnlock(
        nowMillis ?? DateTime.now().millisecondsSinceEpoch,
      );
    } else {
      value = previous;
    }
    return result;
  }

  Future<void> cancelBiometricUnlock(
    AppBiometricAuthenticator authenticator,
  ) async {
    final previous = _biometricUnlockPreviousState;
    if (!_isSystemAuthenticationInProgress || previous == null) return;

    _biometricUnlockGeneration++;
    _isSystemAuthenticationInProgress = false;
    _biometricUnlockPreviousState = null;
    if (value.status == AppLockStatus.unlocking) value = previous;
    try {
      await authenticator.cancel();
    } catch (_) {
      // 本地锁定状态已经恢复；平台取消异常不能再次阻断 PIN。
    }
  }

  Future<AppBiometricResult> reauthenticateWithBiometric(
    AppBiometricAuthenticator authenticator,
  ) async {
    if (_isSystemAuthenticationInProgress) return AppBiometricResult.busy;
    _isSystemAuthenticationInProgress = true;
    try {
      return await authenticator.authenticate();
    } catch (_) {
      return AppBiometricResult.unavailable;
    } finally {
      _isSystemAuthenticationInProgress = false;
    }
  }

  Future<void> _completeSuccessfulUnlock(int nowMillis) async {
    try {
      await attemptManager?.clear();
    } catch (_) {
      // 解锁凭据已经验证成功，清理失败不应把页面永久卡在 unlocking。
    }
    _pinStorageUnavailable = false;
    value = AppLockState(
      status: AppLockStatus.unlocked,
      failedAttempts: 0,
      lockedUntilMillis: null,
      lastUnlockedAtMillis: nowMillis,
      lastBackgroundAtMillis: value.lastBackgroundAtMillis,
    );
  }

  int _cooldownMillis(int failedAttempts) {
    if (attemptManager == null || failedAttempts == maxFailedAttempts) {
      return temporaryLockMillis;
    }
    if (failedAttempts == maxFailedAttempts + 1) return 120000;
    return 300000;
  }

  void checkTemporaryLockExpiry([int? nowMillis]) {
    if (value.status == AppLockStatus.temporarilyLocked) {
      final currentNow = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
      if (value.lockedUntilMillis != null &&
          currentNow >= value.lockedUntilMillis!) {
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: attemptManager == null ? 0 : value.failedAttempts,
          lockedUntilMillis: null,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: value.lastBackgroundAtMillis,
        );
      }
    }
  }

  void markBackgrounded(int nowMillis) {
    if (value.status == AppLockStatus.disabledForDev) return;
    value = AppLockState(
      status: value.status,
      failedAttempts: value.failedAttempts,
      lockedUntilMillis: value.lockedUntilMillis,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: nowMillis,
    );
  }

  void markForegrounded(int nowMillis, {int timeoutMillis = 30000}) {
    if (value.status == AppLockStatus.disabledForDev) {
      return;
    }
    if (value.status == AppLockStatus.locked ||
        value.status == AppLockStatus.temporarilyLocked) {
      // 保持当前状态，但重置后台时间戳
      value = AppLockState(
        status: value.status,
        failedAttempts: value.failedAttempts,
        lockedUntilMillis: value.lockedUntilMillis,
        lastUnlockedAtMillis: value.lastUnlockedAtMillis,
        lastBackgroundAtMillis: null,
      );
      return;
    }

    if (value.status == AppLockStatus.unlocked &&
        value.lastBackgroundAtMillis != null) {
      final diff = nowMillis - value.lastBackgroundAtMillis!;
      if (diff >= timeoutMillis) {
        value = AppLockState(
          status: AppLockStatus.locked,
          failedAttempts: value.failedAttempts,
          lockedUntilMillis: value.lockedUntilMillis,
          lastUnlockedAtMillis: value.lastUnlockedAtMillis,
          lastBackgroundAtMillis: null,
        );
        return;
      }
    }

    value = AppLockState(
      status: value.status,
      failedAttempts: value.failedAttempts,
      lockedUntilMillis: value.lockedUntilMillis,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: null,
    );
  }

  void resetFailures() {
    value = AppLockState(
      status: value.status == AppLockStatus.temporarilyLocked
          ? AppLockStatus.locked
          : value.status,
      failedAttempts: 0,
      lockedUntilMillis: null,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: value.lastBackgroundAtMillis,
    );
  }

  void markConfiguredAndLocked() {
    value = AppLockState(
      status: AppLockStatus.locked,
      failedAttempts: 0,
      lockedUntilMillis: null,
      lastUnlockedAtMillis: value.lastUnlockedAtMillis,
      lastBackgroundAtMillis: value.lastBackgroundAtMillis,
    );
  }

  void configurePrototypeLockForTest() {
    markConfiguredAndLocked();
  }
}
