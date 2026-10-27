import 'package:flutter/material.dart';
import '../../core/security/app_pin_manager.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_icon.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../privacy/privacy_shield_coordinator.dart';
import '../privacy/privacy_shield_controller.dart';
import 'app_pin_pad.dart';

class AppPinSetupPage extends StatefulWidget {
  final AppPinManager appPinManager;
  final AppLockController? appLockController;
  final VoidCallback? onSetupCompleted;
  final PrivacyShieldCoordinator? privacyShieldCoordinator;

  const AppPinSetupPage({
    super.key,
    required this.appPinManager,
    this.appLockController,
    this.onSetupCompleted,
    this.privacyShieldCoordinator,
  });

  @override
  State<AppPinSetupPage> createState() => _AppPinSetupPageState();
}

class _AppPinSetupPageState extends State<AppPinSetupPage>
    with WidgetsBindingObserver {
  String _firstPin = '';
  String _currentPin = '';
  bool _isConfirming = false;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.appPinSetup,
    );
  }

  void _clearSensitiveInputsForLifecycle() {
    if (mounted) {
      setState(() {
        _firstPin = '';
        _currentPin = '';
        _isConfirming = false;
        _errorMessage = null;
      });
    }
    widget.privacyShieldCoordinator?.clear(
      source: PrivacyShieldSource.appPinSetup,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state.toString().contains('hidden') ||
        state == AppLifecycleState.resumed) {
      _clearSensitiveInputsForLifecycle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _firstPin = '';
    _currentPin = '';
    if (widget.privacyShieldCoordinator != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.privacyShieldCoordinator?.clear(
          source: PrivacyShieldSource.appPinSetup,
        );
      });
    }
    super.dispose();
  }

  void _appendDigit(int digit) {
    if (_isSaving || _currentPin.length >= 6) return;
    setState(() {
      _currentPin += '$digit';
      _errorMessage = null;
    });
    if (_currentPin.length == 6) _completeEntry();
  }

  void _removeDigit() {
    if (_isSaving || _currentPin.isEmpty) return;
    setState(() {
      _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _completeEntry() async {
    if (_isSaving || _currentPin.length != 6) return;
    if (!_isConfirming) {
      setState(() {
        _firstPin = _currentPin;
        _currentPin = '';
        _isConfirming = true;
      });
      return;
    }

    if (_firstPin != _currentPin) {
      setState(() {
        _firstPin = '';
        _currentPin = '';
        _isConfirming = false;
        _errorMessage = '两次输入不一致，请重新设置';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await widget.appPinManager.setPin(_firstPin);

      widget.appLockController?.markConfiguredAndLocked();
      widget.onSetupCompleted?.call();

      if (mounted) {
        _firstPin = '';
        _currentPin = '';
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _firstPin = '';
          _currentPin = '';
          _isConfirming = false;
          _isSaving = false;
          _errorMessage = 'PIN 设置失败，请稍后再试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '设置安册 PIN',
        onBack: _isSaving ? null : () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AnchSpacing.page,
          AnchSpacing.xxl,
          AnchSpacing.page,
          AnchSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                AnchIcon(AnchIcons.lock, size: 40, color: colors.accent),
                const SizedBox(height: AnchSpacing.lg),
                Text(
                  _isConfirming ? '再次输入 PIN' : '设置 PIN',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AnchSpacing.sm),
                Text(
                  _isConfirming ? '再次输入相同的 6 位 PIN' : '请使用与手机解锁密码不同的数字组合',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(height: AnchSpacing.xxl),
                AppPinDots(length: _currentPin.length),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Center(
                    child: Text(
                      _isSaving ? '正在保存…' : _errorMessage ?? '',
                      key: const Key('pin_setup_status'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _errorMessage == null
                            ? colors.textSecondary
                            : colors.danger,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                AppPinPad(
                  enabled: !_isSaving,
                  onDigit: _appendDigit,
                  onBackspace: _removeDigit,
                  canBackspace: _currentPin.isNotEmpty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
