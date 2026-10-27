import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../core/theme/anch_colors.dart';

/// 应用锁配置修复原因枚举。
///
/// [pinMissingButEnabled]：应用锁已标记为开启，但未找到可用的 PIN 校验材料。
/// [configurationError]：应用锁配置读取异常。
enum AppLockRecoveryReason {
  /// 应用锁已启用，但 PIN 不存在或损坏。
  /// 场景：enabled == true 且 hasPin == false。
  pinMissingButEnabled,

  /// 应用锁配置读取异常。
  /// 预留状态，本阶段不执行任何自动修复、清除或删除操作。
  configurationError,
}

/// 应用锁配置修复页。
///
/// 本页不会执行自动修复、数据清除或危险操作。
/// 当 [AppLockBootstrapPolicy] 返回 [requireSetup] 或 [configurationError]
/// 决策时，[AppLockBootstrapGate] 会展示本页引导用户修复配置。
///
/// 禁止在本页出现或暗示以下行为：
/// - 自动修复完成
/// - 已清除本地数据
/// - 已重置 App
/// - 已启用正式安全模式
/// - 可以录入真实敏感资料
class AppLockRecoveryPage extends StatelessWidget {
  const AppLockRecoveryPage({
    required this.reason,
    this.onOpenPinSetup,
    this.onBackToSettings,
    super.key,
  });

  /// 修复原因，决定页面展示的文案和可用按钮。
  final AppLockRecoveryReason reason;

  /// 点击“重新设置应用锁 PIN”按钮的回调。
  /// 仅在 [AppLockRecoveryReason.pinMissingButEnabled] 场景中可用。
  final VoidCallback? onOpenPinSetup;

  /// 点击"返回应用锁设置"按钮的回调。
  final VoidCallback? onBackToSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleFor(reason)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 图标
                AnchIcon(
                  _iconFor(reason),
                  size: 72,
                  color: _iconColorFor(reason, colors),
                ),
                const SizedBox(height: 24),

                // 标题
                Text(
                  _titleFor(reason),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // 正文说明
                Text(
                  _bodyFor(reason),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // 操作按钮区
                ..._buildButtons(context),
                const SizedBox(height: 32),

                // 安全处理边界
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: colors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colors.warning.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '安册不会自动清除、重置或删除你的资料。',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: colors.warning),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 根据原因返回页面标题。
  String _titleFor(AppLockRecoveryReason r) {
    switch (r) {
      case AppLockRecoveryReason.pinMissingButEnabled:
        return '应用锁配置需要修复';
      case AppLockRecoveryReason.configurationError:
        return '应用锁配置异常';
    }
  }

  /// 根据原因返回图标。
  AnchIconData _iconFor(AppLockRecoveryReason r) {
    switch (r) {
      case AppLockRecoveryReason.pinMissingButEnabled:
        return AnchIcons.settings;
      case AppLockRecoveryReason.configurationError:
        return AnchIcons.error;
    }
  }

  /// 根据原因返回图标颜色。
  Color _iconColorFor(AppLockRecoveryReason r, AnchColorsExtension colors) {
    switch (r) {
      case AppLockRecoveryReason.pinMissingButEnabled:
        return colors.warning;
      case AppLockRecoveryReason.configurationError:
        return colors.danger;
    }
  }

  /// 根据原因返回正文说明。
  String _bodyFor(AppLockRecoveryReason r) {
    switch (r) {
      case AppLockRecoveryReason.pinMissingButEnabled:
        return '应用锁已开启，但当前 PIN 配置不完整。'
            '为避免无法解锁，安册已暂停进入主界面。'
            '请重新设置应用锁 PIN 后继续。';
      case AppLockRecoveryReason.configurationError:
        return '应用锁配置暂时无法读取。'
            '安册已暂停进入主界面，且不会自动清除或重置资料。'
            '请重新打开安册后再试。';
    }
  }

  /// 根据原因构建操作按钮列表。
  List<Widget> _buildButtons(BuildContext context) {
    final buttons = <Widget>[];

    if (reason == AppLockRecoveryReason.pinMissingButEnabled &&
        onOpenPinSetup != null) {
      buttons.add(
        ElevatedButton(
          onPressed: onOpenPinSetup,
          child: const Text('重新设置应用锁 PIN'),
        ),
      );
      buttons.add(const SizedBox(height: 12));
    }

    if (onBackToSettings != null) {
      buttons.add(
        OutlinedButton(
          onPressed: onBackToSettings,
          child: const Text('返回应用锁设置'),
        ),
      );
    }

    return buttons;
  }
}
