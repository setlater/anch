import 'package:flutter/material.dart';

import '../../app/dependency_provider.dart';
import '../../core/security/app_biometric_authenticator.dart';
import '../../core/security/app_lock_controller.dart';
import '../../core/security/app_lock_lifecycle_controller.dart';
import '../../core/security/app_lock_preferences_manager.dart';
import '../../core/security/app_lock_settings_manager.dart';
import '../../core/security/app_pin_manager.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_bottom_sheet.dart';
import '../../core/widgets/anch_empty_state.dart';
import '../../core/widgets/anch_icon.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';
import '../privacy/screen_protection_scope.dart';
import 'app_pin_verification_page.dart';
import 'app_pin_setup_page.dart';

class AppLockSettingsPage extends StatefulWidget {
  const AppLockSettingsPage({
    super.key,
    required this.appPinManager,
    required this.appLockSettingsManager,
    this.appLockController,
    this.preferencesManager,
    this.biometricAuthenticator,
    this.lifecycleController,
  });

  final AppPinManager appPinManager;
  final AppLockSettingsManager appLockSettingsManager;
  final AppLockController? appLockController;
  final AppLockPreferencesManager? preferencesManager;
  final AppBiometricAuthenticator? biometricAuthenticator;
  final AppLockLifecycleController? lifecycleController;

  @override
  State<AppLockSettingsPage> createState() => _AppLockSettingsPageState();
}

class _AppLockSettingsPageState extends State<AppLockSettingsPage> {
  bool _isLoading = true;
  bool _loadFailed = false;
  bool _loadInProgress = false;
  bool _hasPin = false;
  bool _enabled = false;
  AppLockPreferences _preferences = const AppLockPreferences();
  AppBiometricAvailability _biometricAvailability =
      AppBiometricAvailability.unsupported;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    if (!mounted || _loadInProgress) return;
    _loadInProgress = true;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    try {
      final results = await Future.wait<Object>([
        widget.appPinManager.hasPin(),
        widget.appLockSettingsManager.isAppLockEnabled(),
        widget.preferencesManager?.load() ??
            Future.value(const AppLockPreferences()),
        widget.biometricAuthenticator?.getAvailability() ??
            Future.value(AppBiometricAvailability.unsupported),
      ]);
      if (!mounted) return;
      setState(() {
        _hasPin = results[0] as bool;
        _enabled = results[1] as bool;
        _preferences = results[2] as AppLockPreferences;
        _biometricAvailability = results[3] as AppBiometricAvailability;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    } finally {
      _loadInProgress = false;
    }
  }

  Future<void> _openPinSetup() async {
    final success = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenProtectionScope(
          child: AppPinSetupPage(
            appPinManager: widget.appPinManager,
            privacyShieldCoordinator: DependencyProvider.maybeOf(
              context,
            )?.privacyShieldBundle?.coordinator,
          ),
        ),
      ),
    );
    if (success == true) {
      await widget.appLockSettingsManager.setAppLockEnabled(true);
      widget.lifecycleController?.updateShouldLockOnForeground(true);
      widget.appLockController?.updateAppLockEnabled(true);
      await _loadSettings();
    }
  }

  Future<bool> _verifyPin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ScreenProtectionScope(
          child: AppPinVerificationPage(appPinManager: widget.appPinManager),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _reauthenticate() async {
    if (_preferences.biometricEnabled &&
        _biometricAvailability == AppBiometricAvailability.available &&
        widget.biometricAuthenticator != null &&
        widget.appLockController != null) {
      final privacyController = DependencyProvider.maybeOf(
        context,
      )?.privacyShieldBundle?.controller;
      Future<AppBiometricResult> authenticate() => widget.appLockController!
          .reauthenticateWithBiometric(widget.biometricAuthenticator!);
      final result = privacyController == null
          ? await authenticate()
          : await privacyController.runWhileLifecycleShieldSuppressed(
              authenticate,
            );
      if (result == AppBiometricResult.success) return true;
    }
    return _verifyPin();
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (widget.preferencesManager == null ||
        widget.biometricAuthenticator == null) {
      return;
    }
    if (enabled &&
        _biometricAvailability != AppBiometricAvailability.available) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请先在系统设置中录入强生物识别')));
      }
      return;
    }
    if (enabled) {
      final controller = widget.appLockController;
      if (controller == null) return;
      final privacyController = DependencyProvider.maybeOf(
        context,
      )?.privacyShieldBundle?.controller;
      Future<AppBiometricResult> authenticate() => controller
          .reauthenticateWithBiometric(widget.biometricAuthenticator!);
      final result = privacyController == null
          ? await authenticate()
          : await privacyController.runWhileLifecycleShieldSuppressed(
              authenticate,
            );
      if (result != AppBiometricResult.success) return;
    } else if (!await _reauthenticate()) {
      return;
    }
    await widget.preferencesManager!.setBiometricEnabled(enabled);
    widget.appLockController?.updateBiometricEnabled(enabled);
    await _loadSettings();
  }

  Future<void> _chooseAutoLockMode() async {
    if (widget.preferencesManager == null) return;
    final mode = await showAnchBottomSheet<AppLockAutoLockMode>(
      context: context,
      builder: (sheetContext) => AnchBottomSheetFrame(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnchBottomSheetHeader(title: '自动锁定方式'),
            AnchBottomSheetOptionGroup(
              children: [
                AnchBottomSheetOption(
                  icon: AnchIcons.lock,
                  title: '每次回到安册时',
                  description: '切换到其他应用后，返回安册时需要验证。',
                  isSelected:
                      _preferences.autoLockMode ==
                      AppLockAutoLockMode.everyForeground,
                  onTap: () => Navigator.pop(
                    sheetContext,
                    AppLockAutoLockMode.everyForeground,
                  ),
                ),
                AnchBottomSheetOption(
                  icon: AnchIcons.lockOpen,
                  title: '重新打开安册时',
                  description: '仅在安册已关闭或被系统终止后再次打开时需要验证。',
                  isSelected:
                      _preferences.autoLockMode ==
                      AppLockAutoLockMode.nextLaunch,
                  onTap: () => Navigator.pop(
                    sheetContext,
                    AppLockAutoLockMode.nextLaunch,
                  ),
                ),
              ],
            ),
            AnchBottomSheetDismissAction(
              onTap: () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    await widget.preferencesManager!.setAutoLockMode(mode);
    widget.lifecycleController?.updateAutoLockMode(mode);
    await _loadSettings();
  }

  Future<void> _disableLock() async {
    if (!await _reauthenticate() || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('关闭应用锁？'),
        content: const Text('关闭后，打开安册将不再要求验证。已设置的 PIN 不会被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认关闭'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.appLockSettingsManager.setAppLockEnabled(false);
    widget.lifecycleController?.updateShouldLockOnForeground(false);
    widget.appLockController?.updateAppLockEnabled(false);
    await widget.preferencesManager?.setBiometricEnabled(false);
    widget.appLockController?.updateBiometricEnabled(false);
    await _loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '应用锁',
        onBack: () => Navigator.pop(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? SingleChildScrollView(
              child: AnchEmptyState(
                title: '加载安全设置失败',
                description: '请重新加载后再操作',
                actionLabel: '重新加载',
                onAction: _loadSettings,
                icon: AnchIcons.error,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AnchSpacing.page,
                AnchSpacing.md,
                AnchSpacing.page,
                AnchSpacing.xxl,
              ),
              children: [
                ListTileTheme(
                  data: const ListTileThemeData(
                    contentPadding: EdgeInsets.zero,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('应用锁'),
                        subtitle: Text(_enabled ? '打开安册时验证身份' : '尚未开启'),
                        value: _enabled,
                        onChanged: (_) =>
                            _enabled ? _disableLock() : _openPinSetup(),
                      ),
                      if (_enabled) ...[
                        const Divider(),
                        SwitchListTile(
                          title: const Text('生物识别解锁'),
                          subtitle: Text(
                            _biometricAvailability ==
                                    AppBiometricAvailability.available
                                ? '使用指纹等生物识别解锁，仍可使用安册 PIN'
                                : '本机未配置可用的强生物识别',
                          ),
                          value: _preferences.biometricEnabled,
                          onChanged: _toggleBiometric,
                        ),
                        ListTile(
                          title: const Text('自动锁定方式'),
                          subtitle: Text(
                            _preferences.autoLockMode ==
                                    AppLockAutoLockMode.everyForeground
                                ? '每次回到安册时'
                                : '重新打开安册时',
                          ),
                          trailing: const AnchIcon(AnchIcons.chevronRight),
                          onTap: _chooseAutoLockMode,
                        ),
                        ListTile(
                          title: const Text('修改安册 PIN'),
                          trailing: const AnchIcon(AnchIcons.chevronRight),
                          onTap: () async {
                            if (await _reauthenticate() && mounted) {
                              await _openPinSetup();
                            }
                          },
                        ),
                      ] else if (_hasPin)
                        ListTile(
                          title: const Text('重新开启应用锁'),
                          onTap: () async {
                            if (!await _verifyPin()) return;
                            await widget.appLockSettingsManager
                                .setAppLockEnabled(true);
                            widget.lifecycleController
                                ?.updateShouldLockOnForeground(true);
                            widget.appLockController?.updateAppLockEnabled(
                              true,
                            );
                            await _loadSettings();
                          },
                        ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: AnchSpacing.lg),
                  child: Text(
                    '安册 PIN 是独立于系统锁屏的兜底方式。生物识别不可用或被系统锁定时，仍可使用 PIN。',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
    );
  }
}
