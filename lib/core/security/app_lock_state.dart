enum AppLockStatus {
  disabledForDev,
  unconfigured,
  locked,
  unlocking,
  unlocked,
  temporarilyLocked,
}

class AppLockState {
  const AppLockState({
    required this.status,
    this.failedAttempts = 0,
    this.lockedUntilMillis,
    this.lastUnlockedAtMillis,
    this.lastBackgroundAtMillis,
  });

  final AppLockStatus status;
  final int failedAttempts;
  final int? lockedUntilMillis;
  final int? lastUnlockedAtMillis;
  final int? lastBackgroundAtMillis;

  bool get isLockedLike =>
      status == AppLockStatus.locked ||
      status == AppLockStatus.unlocking ||
      status == AppLockStatus.temporarilyLocked ||
      status == AppLockStatus.unconfigured;

  bool get canShowProtectedContent =>
      status == AppLockStatus.unlocked ||
      status == AppLockStatus.disabledForDev;

  @override
  String toString() {
    return 'AppLockState(status: $status, failedAttempts: $failedAttempts, '
        'lockedUntilMillis: $lockedUntilMillis, lastUnlockedAtMillis: $lastUnlockedAtMillis, '
        'lastBackgroundAtMillis: $lastBackgroundAtMillis)';
  }
}
