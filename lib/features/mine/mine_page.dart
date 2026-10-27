import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../app/dependency_provider.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_page_header.dart';
import '../../core/widgets/anch_section_header.dart';
import '../../core/widgets/anch_security_banner.dart';
import '../../core/runtime/runtime_scope.dart';
import 'data_management_page.dart';
import '../app_lock/app_lock_settings_page.dart';
import '../help/about_page.dart';
import '../help/external_document_launcher.dart';
import '../help/help_center_page.dart';
import '../privacy/screen_protection_settings_page.dart';
import '../../core/security/screen_protection_settings_manager.dart';
import '../../core/security/screen_protection_controller.dart';
import '../../core/security/app_lock_dependency_bundle.dart';

/// 我的页。
///
/// 展示本地保存说明、安全设置与数据管理入口。
class MinePage extends StatelessWidget {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final screenProtectionBundle = DependencyProvider.maybeOf(
      context,
    )?.screenProtectionBundle;
    final appLockBundle = DependencyProvider.maybeOf(context)?.appLockBundle;
    final appLockEntry = appLockBundle == null
        ? _buildAppLockEntry(
            context,
            colors,
            null,
            screenProtectionBundle != null,
          )
        : ValueListenableBuilder(
            valueListenable: appLockBundle.appLockController,
            builder: (context, _, _) => _buildAppLockEntry(
              context,
              colors,
              appLockBundle,
              screenProtectionBundle != null,
            ),
          );

    return AnchAppScaffold(
      body: ListView(
        children: [
          AnchPageHeader(title: '设置'),

          // 开发验证模式提示（必须保留）
          if (RuntimeScope.of(context).isDevMode)
            const AnchSecurityBanner(
              message: AnchSecurityBanner.devModeMessage,
              type: AnchBannerType.warning,
            ),

          const SizedBox(height: AnchSpacing.md),

          AnchSectionHeader(title: '安全设置'),
          if (screenProtectionBundle == null)
            appLockEntry
          else
            _SettingsGroup(
              key: const ValueKey('mine_security_settings_group'),
              children: [
                _ScreenProtectionEntry(
                  controller: screenProtectionBundle.controller,
                  grouped: true,
                ),
                Divider(height: 1, thickness: 1, color: colors.divider),
                appLockEntry,
              ],
            ),

          const SizedBox(height: AnchSpacing.sm),

          AnchSectionHeader(title: '数据管理'),
          _PlaceholderItem(
            key: const ValueKey('mine_data_management_entry'),
            icon: AnchIcons.backup,
            title: '数据与备份',
            description: '备份、恢复或删除本机资料',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DataManagementPage()),
              );
            },
          ),

          const SizedBox(height: AnchSpacing.sm),

          AnchSectionHeader(title: '帮助'),
          _PlaceholderItem(
            icon: AnchIcons.help,
            title: '帮助手册',
            description: '离线查看使用、安全与备份说明',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const HelpCenterPage()),
            ),
          ),
          _PlaceholderItem(
            key: const ValueKey('mine_privacy_policy_entry'),
            icon: AnchIcons.security,
            title: '隐私政策',
            description: '在系统浏览器中查看数据处理说明',
            onTap: () => AnchExternalDocuments.openPrivacyPolicy(context),
          ),
          _PlaceholderItem(
            icon: AnchIcons.info,
            title: '关于安册',
            description: '查看版本与产品边界',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AnchSpacing.page),
            child: Text(
              '资料仅保存在本机，不联网，无云同步。',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ),
          const SizedBox(height: AnchSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildAppLockEntry(
    BuildContext context,
    AnchColorsExtension colors,
    AppLockDependencyBundle? appLockBundle,
    bool grouped,
  ) {
    final enabled = appLockBundle?.appLockController.appLockEnabled == true;
    return _PlaceholderItem(
      key: const ValueKey('mine_security_settings_app_lock'),
      icon: AnchIcons.lock,
      title: '应用锁',
      description: '指纹或 PIN 保护本机资料',
      badge: enabled ? '已启用' : '未启用',
      badgeColor: enabled ? colors.success : colors.textMuted,
      grouped: grouped,
      onTap: appLockBundle == null
          ? null
          : () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => AppLockSettingsPage(
                  appPinManager: appLockBundle.appPinManager,
                  appLockSettingsManager: appLockBundle.appLockSettingsManager,
                  appLockController: appLockBundle.appLockController,
                  preferencesManager: appLockBundle.appLockPreferencesManager,
                  biometricAuthenticator:
                      appLockBundle.appBiometricAuthenticator,
                  lifecycleController: appLockBundle.appLockLifecycleController,
                ),
              ),
            ),
    );
  }
}

class _ScreenProtectionEntry extends StatelessWidget {
  const _ScreenProtectionEntry({
    required this.controller,
    this.grouped = false,
  });

  final ScreenProtectionController controller;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final ScreenProtectionMode mode = controller.mode;
        final label = switch (mode) {
          ScreenProtectionMode.sensitiveOnly => '仅敏感页面',
          ScreenProtectionMode.always => '全部保护',
          ScreenProtectionMode.unrestricted => '不限制',
        };
        return _PlaceholderItem(
          icon: AnchIcons.screenshot,
          title: '屏幕内容保护',
          description: '限制敏感页面截图和录屏',
          badge: label,
          badgeColor: colors.accent,
          grouped: grouped,
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  ScreenProtectionSettingsPage(controller: controller),
            ),
          ),
        );
      },
    );
  }
}

// ─── 本地保存说明卡片 ────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: 4,
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }
}

class _PlaceholderItem extends StatelessWidget {
  const _PlaceholderItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
    this.badgeColor,
    this.grouped = false,
    this.onTap,
  });

  final AnchIconData icon;
  final String title;
  final String description;
  final String? badge;
  final Color? badgeColor;
  final bool grouped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final titleStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: colors.textPrimary,
    );
    final badgeStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: badgeColor,
    );
    final Widget innerContent = Row(
      children: [
        AnchIcon(icon, size: 22, color: colors.textSecondary),
        const SizedBox(width: AnchSpacing.md),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = TextPainter(
                text: TextSpan(
                  children: [
                    TextSpan(text: title, style: titleStyle),
                    if (badge != null) TextSpan(text: badge, style: badgeStyle),
                  ],
                ),
                textDirection: Directionality.of(context),
                textScaler: MediaQuery.textScalerOf(context),
                maxLines: 1,
              )..layout();
              final stackBadge =
                  badge != null &&
                  heading.width + AnchSpacing.md > constraints.maxWidth;
              heading.dispose();
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: titleStyle),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: colors.textMuted),
                  ),
                  if (stackBadge) ...[
                    const SizedBox(height: AnchSpacing.xs),
                    Text(badge!, style: badgeStyle),
                  ],
                ],
              );
              if (badge == null || stackBadge) return copy;
              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: AnchSpacing.md),
                  Text(badge!, style: badgeStyle),
                ],
              );
            },
          ),
        ),
      ],
    );

    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AnchSpacing.sm,
          vertical: AnchSpacing.md,
        ),
        child: innerContent,
      ),
    );
    final item = onTap == null
        ? content
        : InkWell(onTap: onTap, child: content);

    if (grouped) return item;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: 4,
      ),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: item,
      ),
    );
  }
}
