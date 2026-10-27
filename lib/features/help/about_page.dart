import 'package:flutter/material.dart';

import '../../app/app_metadata.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_icons.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_icon.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '关于安册',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AnchSpacing.page),
        children: [
          const SizedBox(height: AnchSpacing.xl),
          AnchIcon(AnchIcons.document, size: 64, color: colors.accentDeep),
          const SizedBox(height: AnchSpacing.md),
          Text(
            anchAppName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AnchSpacing.xs),
          Text(
            '重要资料，整理成册',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AnchSpacing.sm),
          Text(
            '版本 $anchAppVersion（$anchAppBuildNumber）',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textMuted),
          ),
          const SizedBox(height: AnchSpacing.xxl),
          Text(
            '作者：setlater',
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: AnchSpacing.sm),
          Text(
            '安册采用 MIT 许可证开源，第三方材料遵循各自许可。',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AnchSpacing.lg),
          Text(
            '用于在当前设备上按成员整理和查找重要资料。资料管理无需账号或网络，不会自动上传或同步。',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: AnchSpacing.lg),
          Text(
            '安册不适合保存支付密码、登录密码、动态验证码、CVV、私钥或助记词。',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: AnchSpacing.xl),
          _AboutActionRow(
            label: '第三方许可',
            description: '查看组件与图标的版权和许可',
            onTap: () => showLicensePage(
              context: context,
              applicationName: anchAppName,
              applicationVersion: '$anchAppVersion（$anchAppBuildNumber）',
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutActionRow extends StatelessWidget {
  const _AboutActionRow({
    required this.label,
    required this.description,
    required this.onTap,
  });

  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('about_open_source_licenses'),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AnchSpacing.md),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.divider),
              bottom: BorderSide(color: colors.divider),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: colors.textPrimary)),
                    const SizedBox(height: AnchSpacing.xs),
                    Text(
                      description,
                      style: TextStyle(color: colors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              AnchIcon(
                AnchIcons.chevronRight,
                size: 18,
                color: colors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
