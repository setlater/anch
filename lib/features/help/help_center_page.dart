import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_page_header.dart';

/// 帮助与安全说明离线页面。
/// 全静态的离线信息卡片展示，解答不联网、本地保存、备份恢复等安全边界。
class HelpCenterPage extends StatelessWidget {
  const HelpCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnchAppScaffold(
      body: ListView(
        padding: const EdgeInsets.only(bottom: AnchSpacing.xxl),
        children: [
          AnchPageHeader(
            title: '帮助手册',
            onBack: () => Navigator.of(context).pop(),
          ),
          const _WarningBanner(message: '卸载安册或清除应用数据会删除本机资料，请先导出备份。'),
          const SizedBox(height: AnchSpacing.md),
          const _HelpSectionCard(
            title: '1. 快速开始',
            children: [
              Text(
                '• 在「成员」中添加家人。\n'
                '• 点击首页「新增」，选择资料类型并保存。\n'
                '• 通过首页、分类或搜索快速找到资料。\n'
                '• 敏感字段默认隐藏，需要时再查看或复制。',
                style: _bodyStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '2. 本地与安全',
            children: [
              Text(
                '• 安册无账号、无云同步，日常使用不需要联网。\n'
                '• 资料库与附件在本机加密保存。\n'
                '• “家庭”指在同一台设备上分成员管理，不代表家人间会自动同步。\n'
                '• 设备锁屏强度、系统安全和备份保管同样重要。',
                style: _bodyStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '3. 备份与恢复',
            children: [
              Text(
                '• 备份是手动离线操作，安册不会自动上传或异地备份。\n'
                '• 备份密码仅由你保管，安册不会保存，忘记后无法找回。\n'
                '• 请将备份文件与密码分开保管，并保留至少一份异机副本。\n'
                '• 恢复会用备份内容完整覆盖当前资料，确认前请核对恢复范围。\n'
                '• 应用锁 PIN、指纹偏好等本机安全设置不随备份迁移。',
                style: _bodyStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '4. 应用锁与忘记 PIN',
            children: [
              Text(
                '• 应用锁用于防止他人直接进入安册，不代替系统锁屏。\n'
                '• 开启强生物识别后，可用系统认证解锁或重设 PIN。\n'
                '• 如未开启可用的强生物识别且忘记 PIN，只能清空本机资料后，再使用备份恢复。',
                style: _bodyStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '5. 不应保存的信息',
            children: [
              Text(
                '• 支付密码、银行卡登录密码、手机网银登录信息\n'
                '• 网站或其他 App 的登录密码、动态验证码\n'
                '• CVC、CVV、信用卡安全码或支付授权凭据\n'
                '• 私钥、助记词以及其他可直接控制资产的凭据',
                style: _bulletStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '6. 到期信息',
            children: [
              Text(
                '首页及资料卡片会显示即将到期或已过期状态。当前不会通过系统通知栏主动提醒，请定期打开安册检查。',
                style: _bodyStyle,
              ),
            ],
          ),
          const _HelpSectionCard(
            title: '7. 换机或手机丢失',
            children: [
              Text(
                '• 换机前，先在旧手机导出备份，再在新手机覆盖恢复。\n'
                '• 恢复并核对资料与附件后，再处理旧手机。\n'
                '• 手机丢失后，安册无法远程擦除或找回资料；请使用系统提供的设备查找与保护能力。',
                style: _bodyStyle,
              ),
            ],
          ),
          const SizedBox(height: AnchSpacing.xxl),
        ],
      ),
    );
  }
}

// ─── 统一的文案样式定义 ──────────────────────────────────────────────────────

const TextStyle _bodyStyle = TextStyle(fontSize: 13, height: 1.6);

const TextStyle _bulletStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  height: 1.6,
);

// ─── 段落卡片组件 ────────────────────────────────────────────────────────────

class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: AnchSpacing.sm,
      ),
      padding: const EdgeInsets.all(AnchSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colors.accentDeep,
            ),
          ),
          const SizedBox(height: AnchSpacing.md),
          ...children,
        ],
      ),
    );
  }
}

// ─── 提示横幅组件 ────────────────────────────────────────────────────────────

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AnchSpacing.page),
      padding: const EdgeInsets.all(AnchSpacing.md),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(AnchRadius.md),
        border: Border.all(
          color: colors.warning.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnchIcon(AnchIcons.info, size: 16, color: colors.warning),
          const SizedBox(width: AnchSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: colors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
