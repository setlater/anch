import 'package:flutter/material.dart';

import '../../core/security/app_pin_manager.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_icon.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import 'app_pin_pad.dart';

class AppPinVerificationPage extends StatefulWidget {
  const AppPinVerificationPage({super.key, required this.appPinManager});

  final AppPinManager appPinManager;

  @override
  State<AppPinVerificationPage> createState() => _AppPinVerificationPageState();
}

class _AppPinVerificationPageState extends State<AppPinVerificationPage>
    with WidgetsBindingObserver {
  String _pin = '';
  String? _errorMessage;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.inactive &&
        state != AppLifecycleState.paused &&
        state != AppLifecycleState.detached &&
        !state.toString().contains('hidden') &&
        state != AppLifecycleState.resumed) {
      return;
    }
    if (mounted) setState(() => _pin = '');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin = '';
    super.dispose();
  }

  void _appendDigit(int digit) {
    if (_isVerifying || _pin.length >= 6) return;
    setState(() {
      _pin += '$digit';
      _errorMessage = null;
    });
    if (_pin.length == 6) _verify();
  }

  void _removeDigit() {
    if (_isVerifying || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _verify() async {
    if (_isVerifying || _pin.length != 6) return;
    setState(() => _isVerifying = true);
    var verified = false;
    try {
      verified = await widget.appPinManager.verifyPin(_pin);
    } catch (_) {
      verified = false;
    }
    if (!mounted) return;
    if (verified) {
      _pin = '';
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _pin = '';
      _isVerifying = false;
      _errorMessage = 'PIN 不正确，请重新输入';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '验证安册 PIN',
        onBack: _isVerifying ? null : () => Navigator.pop(context),
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
                const Text(
                  '输入 PIN',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AnchSpacing.sm),
                Text(
                  '验证后继续修改安全设置',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(height: AnchSpacing.xxl),
                AppPinDots(length: _pin.length),
                SizedBox(
                  height: 52,
                  child: Center(
                    child: Text(
                      _isVerifying ? '正在验证…' : _errorMessage ?? '',
                      key: const Key('pin_verification_status'),
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
                  enabled: !_isVerifying,
                  onDigit: _appendDigit,
                  onBackspace: _removeDigit,
                  canBackspace: _pin.isNotEmpty,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
