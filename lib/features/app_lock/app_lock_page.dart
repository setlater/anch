import 'dart:async';

import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/security/app_biometric_authenticator.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/app_lock_state.dart';
import '../../core/theme/anch_colors.dart';
import '../privacy/privacy_shield_coordinator.dart';
import '../privacy/privacy_shield_controller.dart';
import 'app_pin_pad.dart';

class AppLockPage extends StatefulWidget {
  final AppLockController controller;
  final PrivacyShieldCoordinator? privacyShieldCoordinator;
  final VoidCallback? onForgotPin;
  final AppBiometricAuthenticator? biometricAuthenticator;
  final bool biometricEnabled;
  final Future<bool> Function(BuildContext)? onResetPinWithBiometric;

  const AppLockPage({
    super.key,
    required this.controller,
    this.privacyShieldCoordinator,
    this.onForgotPin,
    this.biometricAuthenticator,
    this.biometricEnabled = false,
    this.onResetPinWithBiometric,
  });

  @override
  State<AppLockPage> createState() => _AppLockPageState();
}

class _AppLockPageState extends State<AppLockPage> with WidgetsBindingObserver {
  String _pin = '';
  String? _errorMessage;
  bool _isUnlocking = false;
  bool _isBiometricUnlocking = false;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) FocusManager.instance.primaryFocus?.unfocus();
    });
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerStateChanged);
    _scheduleCooldownExpiry();
    if (widget.biometricEnabled && widget.biometricAuthenticator != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _authenticateBiometric(),
      );
    }
  }

  Future<void> _authenticateBiometric() async {
    if (_isUnlocking || !mounted || widget.biometricAuthenticator == null) {
      return;
    }
    setState(() {
      _isUnlocking = true;
      _isBiometricUnlocking = true;
      _errorMessage = null;
    });
    final privacyController = DependencyProvider.maybeOf(
      context,
    )?.privacyShieldBundle?.controller;
    Future<AppBiometricResult> authenticate() =>
        widget.controller.unlockWithBiometric(widget.biometricAuthenticator!);
    final result = privacyController == null
        ? await authenticate()
        : await privacyController.runWhileLifecycleShieldSuppressed(
            authenticate,
          );
    if (!mounted) return;
    setState(() {
      _isUnlocking = false;
      _isBiometricUnlocking = false;
      if (result == AppBiometricResult.lockedOut) {
        _errorMessage = '生物识别暂时不可用，请使用安册 PIN';
      } else if (result == AppBiometricResult.unavailable) {
        _errorMessage = '无法使用生物识别，请使用安册 PIN';
      }
    });
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerStateChanged);
    _pin = '';
    if (widget.privacyShieldCoordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.appLockInput,
        );
      });
    }
    super.dispose();
  }

  void _clearSensitiveInputForLifecycle() {
    if (mounted) setState(() => _pin = '');
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.appLockInput,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.checkTemporaryLockExpiry();
      _scheduleCooldownExpiry();
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state.toString().contains('hidden') ||
        state == AppLifecycleState.resumed) {
      _clearSensitiveInputForLifecycle();
    }
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.detached ||
            state.toString().contains('hidden')) &&
        _isBiometricUnlocking &&
        widget.biometricAuthenticator != null) {
      setState(() {
        _isUnlocking = false;
        _isBiometricUnlocking = false;
      });
      unawaited(
        widget.controller.cancelBiometricUnlock(widget.biometricAuthenticator!),
      );
    }
  }

  void _onControllerStateChanged() {
    _scheduleCooldownExpiry();
    if (mounted) {
      setState(() {
        if (widget.controller.value.status == AppLockStatus.temporarilyLocked) {
          _errorMessage = '尝试次数过多，请稍后再试';
          _pin = '';
          widget.privacyShieldCoordinator?.clear(
            source: PrivacyShieldSource.appLockInput,
          );
        } else if (_errorMessage == '尝试次数过多，请稍后再试') {
          _errorMessage = null;
        }
      });
    }
  }

  void _scheduleCooldownExpiry() {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    final state = widget.controller.value;
    final until = state.lockedUntilMillis;
    if (state.status != AppLockStatus.temporarilyLocked || until == null) {
      return;
    }
    final remaining = until - DateTime.now().millisecondsSinceEpoch;
    _cooldownTimer = Timer(
      Duration(milliseconds: remaining > 0 ? remaining : 0),
      () {
        widget.controller.checkTemporaryLockExpiry();
        _scheduleCooldownExpiry();
      },
    );
  }

  void _appendDigit(int digit) {
    if (_isUnlocking ||
        widget.controller.pinStorageUnavailable ||
        widget.controller.value.status == AppLockStatus.temporarilyLocked ||
        _pin.length >= 6) {
      return;
    }
    setState(() {
      _pin += '$digit';
      _errorMessage = null;
    });
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.appLockInput,
    );
    if (_pin.length == 6) _handleUnlock();
  }

  void _removeDigit() {
    if (_isUnlocking || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _handleUnlock() async {
    if (_isUnlocking || _pin.length != 6) return;

    setState(() {
      _isUnlocking = true;
      _errorMessage = null;
    });

    final pinInput = _pin;
    final now = DateTime.now().millisecondsSinceEpoch;
    final success = await widget.controller.unlockWithPin(
      pinInput,
      nowMillis: now,
    );

    if (mounted) {
      setState(() {
        _isUnlocking = false;
        if (success) {
          _errorMessage = null;
          _pin = '';
          widget.privacyShieldCoordinator?.clear(
            source: PrivacyShieldSource.appLockInput,
          );
        } else {
          final state = widget.controller.value;
          if (widget.controller.pinStorageUnavailable) {
            _errorMessage = '安全存储暂时不可用，请重新打开安册后再试';
          } else if (state.status == AppLockStatus.temporarilyLocked) {
            _errorMessage = '尝试次数过多，请稍后再试';
          } else {
            _errorMessage = 'PIN 不正确';
          }
          _pin = '';
        }
      });
    }
  }

  Future<void> _handleForgotPin() async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('忘记安册 PIN？'),
        content: const Text('如果生物识别可用，可验证身份后重设 PIN；否则只能删除本机资料。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          if (widget.onResetPinWithBiometric != null)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'biometric'),
              child: const Text('使用生物识别重设'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'reset'),
            child: const Text('删除本机资料'),
          ),
        ],
      ),
    );
    if (action == 'biometric') {
      if (!mounted) return;
      final success =
          await widget.onResetPinWithBiometric?.call(context) ?? false;
      if (!success && mounted) {
        setState(() => _errorMessage = '身份验证未完成，PIN 未重设');
      }
    } else if (action == 'reset') {
      widget.onForgotPin?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ValueListenableBuilder<AppLockState>(
              valueListenable: widget.controller,
              builder: (context, state, child) {
                final isTempLocked =
                    state.status == AppLockStatus.temporarilyLocked;
                final storageUnavailable =
                    widget.controller.pinStorageUnavailable;
                final displayError = storageUnavailable
                    ? '安全存储暂时不可用，请重新打开安册后再试'
                    : isTempLocked
                    ? '尝试次数过多，请稍后再试'
                    : _errorMessage;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnchIcon(
                          AnchIcons.lock,
                          size: 48,
                          color: colors.accent,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '安册已锁定',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '输入安册 PIN，或使用已启用的生物识别',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),
                        AppPinDots(length: _pin.length),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 52),
                          child: Center(
                            child: Text(
                              _isUnlocking ? '正在验证…' : displayError ?? '',
                              key: const Key('app_lock_status'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: displayError == null
                                    ? colors.textSecondary
                                    : colors.danger,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        AppPinPad(
                          enabled:
                              !isTempLocked &&
                              !storageUnavailable &&
                              !_isUnlocking,
                          onDigit: _appendDigit,
                          onBackspace: _removeDigit,
                          canBackspace: _pin.isNotEmpty,
                          onBiometric:
                              !_isUnlocking &&
                                  widget.biometricEnabled &&
                                  widget.biometricAuthenticator != null
                              ? _authenticateBiometric
                              : null,
                        ),
                        if (widget.onForgotPin != null) ...[
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _handleForgotPin,
                            child: Text(
                              '忘记 PIN？',
                              style: TextStyle(
                                color: colors.danger,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
