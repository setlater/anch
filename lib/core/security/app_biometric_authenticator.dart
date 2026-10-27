import 'package:flutter/services.dart';

enum AppBiometricAvailability {
  available,
  notEnrolled,
  noHardware,
  temporarilyUnavailable,
  securityUpdateRequired,
  unsupported,
}

enum AppBiometricResult { success, cancelled, lockedOut, unavailable, busy }

abstract interface class AppBiometricAuthenticator {
  Future<AppBiometricAvailability> getAvailability();
  Future<AppBiometricResult> authenticate();
  Future<void> cancel();
}

class AndroidStrongBiometricAuthenticator implements AppBiometricAuthenticator {
  static const _channel = MethodChannel('anch/strong_biometric');

  @override
  Future<AppBiometricAvailability> getAvailability() async {
    try {
      final value = await _channel.invokeMethod<String>('getAvailability');
      return AppBiometricAvailability.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => AppBiometricAvailability.unsupported,
      );
    } catch (_) {
      return AppBiometricAvailability.unsupported;
    }
  }

  @override
  Future<AppBiometricResult> authenticate() async {
    try {
      final value = await _channel.invokeMethod<String>('authenticate');
      return AppBiometricResult.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => AppBiometricResult.unavailable,
      );
    } catch (_) {
      return AppBiometricResult.unavailable;
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } catch (_) {}
  }
}
