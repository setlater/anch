import 'package:flutter/material.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/app_lock_state.dart';
import '../../app/dependency_provider.dart';
import 'app_lock_page.dart';
import 'app_lock_setup_placeholder_page.dart';
import '../privacy/screen_protection_scope.dart';
import '../../core/security/app_biometric_authenticator.dart';

class AppLockGate extends StatelessWidget {
  final AppLockController controller;
  final Widget child;
  final VoidCallback? onOpenPinSetup;
  final ValueChanged<BuildContext>? onForgotPin;
  final AppBiometricAuthenticator? biometricAuthenticator;
  final bool biometricEnabled;
  final Future<bool> Function(BuildContext)? onResetPinWithBiometric;

  const AppLockGate({
    super.key,
    required this.controller,
    required this.child,
    this.onOpenPinSetup,
    this.onForgotPin,
    this.biometricAuthenticator,
    this.biometricEnabled = false,
    this.onResetPinWithBiometric,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLockState>(
      valueListenable: controller,
      builder: (context, state, _) {
        final lockLayer = switch (state.status) {
          AppLockStatus.disabledForDev || AppLockStatus.unlocked => null,
          AppLockStatus.unconfigured => ScreenProtectionScope(
            child: AppLockSetupPlaceholderPage(
              controller: controller,
              onOpenPinSetup: onOpenPinSetup,
            ),
          ),
          AppLockStatus.locked ||
          AppLockStatus.unlocking ||
          AppLockStatus.temporarilyLocked => ScreenProtectionScope(
            child: AppLockPage(
              controller: controller,
              privacyShieldCoordinator: DependencyProvider.maybeOf(
                context,
              )?.privacyShieldBundle?.coordinator,
              onForgotPin: onForgotPin == null
                  ? null
                  : () => onForgotPin!(context),
              biometricAuthenticator: biometricAuthenticator,
              biometricEnabled: biometricEnabled || controller.biometricEnabled,
              onResetPinWithBiometric: onResetPinWithBiometric,
            ),
          ),
        };
        final unlocked = lockLayer == null;

        return PopScope<void>(
          canPop: unlocked,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: !unlocked,
                child: TickerMode(enabled: unlocked, child: child),
              ),
              if (lockLayer != null) Positioned.fill(child: lockLayer),
            ],
          ),
        );
      },
    );
  }
}
