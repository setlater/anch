import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';

/// 安全提示横幅的视觉类型。
enum AnchBannerType {
  /// 警告，如开发验证模式提示、高风险操作提示
  warning,

  /// 本地状态，如"所有资料本地存储"说明
  local,

  /// 信息，如普通帮助说明
  info,

  /// 中度警告，用于即将到期提示
  caution,
}

/// 安册安全提示横幅。
///
/// 用途：
/// - 开发验证模式提示（首页、录入页、详情页必须覆盖）
/// - 高风险操作提示
/// - 本地存储状态说明
/// - 普通信息提示
///
/// 要求：
/// - 不使用大红强警告
/// - 提示要清晰，不制造恐慌
/// - 不遮挡主操作
class AnchSecurityBanner extends StatelessWidget {
  /// 开发验证模式默认提示文案
  static const String devModeMessage = '开发验证模式，请勿录入真实敏感资料';

  const AnchSecurityBanner({
    super.key,
    required this.message,
    this.type = AnchBannerType.warning,
    this.icon,
    this.margin,
    this.compactWhenKeyboardVisible = false,
    this.isKeyboardVisible,
  });

  /// 提示文案
  final String message;

  /// 视觉类型
  final AnchBannerType type;

  /// 自定义图标（可选），不传则使用类型默认图标
  final AnchIconData? icon;

  /// 外边距（可选）
  final EdgeInsetsGeometry? margin;

  /// 键盘弹出时是否开启紧凑模式
  final bool compactWhenKeyboardVisible;

  /// 显式传入的键盘可见状态（可选），用于覆盖默认 MediaQuery 检测
  final bool? isKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final view = View.maybeOf(context);
    final keyboardHeight = view != null
        ? (view.viewInsets.bottom / view.devicePixelRatio)
        : 0.0;
    final isKeyboard =
        keyboardHeight > 0 || MediaQuery.of(context).viewInsets.bottom > 0;
    final isKeyboardActive = isKeyboardVisible ?? isKeyboard;
    final isKeyboardVisibleEffective =
        compactWhenKeyboardVisible && isKeyboardActive;
    final config = _resolveConfig(context, type);
    final effectiveIcon = icon ?? config.icon;

    final displayText = isKeyboardVisibleEffective && message == devModeMessage
        ? '请勿录入真实敏感资料'
        : message;

    return Container(
      margin:
          margin ??
          EdgeInsets.symmetric(
            horizontal: AnchSpacing.page,
            vertical: isKeyboardVisibleEffective ? 2.0 : AnchSpacing.xs,
          ),
      padding: EdgeInsets.symmetric(
        horizontal: AnchSpacing.md,
        vertical: isKeyboardVisibleEffective ? 4.0 : AnchSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(AnchRadius.sm),
        border: Border.all(color: config.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AnchIcon(
            effectiveIcon,
            size: isKeyboardVisibleEffective ? 12 : 15,
            color: config.iconColor,
          ),
          const SizedBox(width: AnchSpacing.sm),
          Expanded(
            child: Text(
              displayText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: config.textColor,
                height: isKeyboardVisibleEffective ? 1.2 : 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _BannerConfig _resolveConfig(BuildContext context, AnchBannerType t) {
    switch (t) {
      case AnchBannerType.warning:
        return _BannerConfig(
          backgroundColor: context.anchColors.dangerSoft,
          borderColor: context.anchColors.danger.withValues(alpha: 0.25),
          iconColor: context.anchColors.danger,
          textColor: context.anchColors.danger,
          icon: AnchIcons.info,
        );
      case AnchBannerType.local:
        return _BannerConfig(
          backgroundColor: context.anchColors.accentSoft,
          borderColor: context.anchColors.accent.withValues(alpha: 0.16),
          iconColor: context.anchColors.accentDeep,
          textColor: context.anchColors.textSecondary,
          icon: AnchIcons.lock,
        );
      case AnchBannerType.info:
        return _BannerConfig(
          backgroundColor: context.anchColors.accentSoft,
          borderColor: context.anchColors.accent.withValues(alpha: 0.16),
          iconColor: context.anchColors.accent,
          textColor: context.anchColors.textSecondary,
          icon: AnchIcons.lightbulb,
        );
      case AnchBannerType.caution:
        return _BannerConfig(
          backgroundColor: context.anchColors.warningSoft,
          borderColor: context.anchColors.warning.withValues(alpha: 0.25),
          iconColor: context.anchColors.warning,
          textColor: context.anchColors.warning,
          icon: AnchIcons.warning,
        );
    }
  }
}

class _BannerConfig {
  const _BannerConfig({
    required this.backgroundColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final AnchIconData icon;
}
