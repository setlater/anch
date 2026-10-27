import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../../core/security/screen_protection_controller.dart';
import '../../core/security/screen_protection_settings_manager.dart';
import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_radius.dart';
import '../../core/theme/anch_spacing.dart';
import '../../core/widgets/anch_app_scaffold.dart';
import '../../core/widgets/anch_centered_notice.dart';
import '../../core/widgets/anch_subpage_app_bar.dart';

class ScreenProtectionSettingsPage extends StatefulWidget {
  const ScreenProtectionSettingsPage({required this.controller, super.key});

  final ScreenProtectionController controller;

  @override
  State<ScreenProtectionSettingsPage> createState() =>
      _ScreenProtectionSettingsPageState();
}

class _ScreenProtectionSettingsPageState
    extends State<ScreenProtectionSettingsPage> {
  bool _isSaving = false;

  Future<void> _selectMode(ScreenProtectionMode mode) async {
    if (_isSaving || widget.controller.mode == mode) return;
    if (mode == ScreenProtectionMode.unrestricted) {
      final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('允许截屏和录屏？'),
          content: const Text('允许后，前台资料内容可能被保存到系统相册、云相册或分享给第三方应用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('仍然允许'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.setMode(mode);
    } catch (_) {
      if (mounted) {
        AnchCenteredNotice.showError(context, '保存屏幕内容保护设置失败');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return AnchAppScaffold(
      appBar: AnchSubpageAppBar(
        title: '屏幕内容保护',
        onBack: () => Navigator.pop(context),
      ),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(
            AnchSpacing.page,
            AnchSpacing.md,
            AnchSpacing.page,
            AnchSpacing.xxl,
          ),
          children: [
            Text(
              '控制前台截图和录屏。',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: AnchSpacing.lg),
            _ModeTile(
              mode: ScreenProtectionMode.sensitiveOnly,
              title: '仅保护敏感页面',
              description: '保护资料详情、录入、PIN 及备份密码等页面',
              selected:
                  widget.controller.mode == ScreenProtectionMode.sensitiveOnly,
              enabled: !_isSaving,
              onTap: _selectMode,
            ),
            const SizedBox(height: AnchSpacing.sm),
            _ModeTile(
              mode: ScreenProtectionMode.always,
              title: '保护所有页面',
              description: '整个应用都禁止截图和录屏',
              selected: widget.controller.mode == ScreenProtectionMode.always,
              enabled: !_isSaving,
              onTap: _selectMode,
            ),
            const SizedBox(height: AnchSpacing.sm),
            _ModeTile(
              mode: ScreenProtectionMode.unrestricted,
              title: '不限制',
              description: '允许前台页面截图和录屏',
              selected:
                  widget.controller.mode == ScreenProtectionMode.unrestricted,
              enabled: !_isSaving,
              onTap: _selectMode,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.title,
    required this.description,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ScreenProtectionMode mode;
  final String title;
  final String description;
  final bool selected;
  final bool enabled;
  final ValueChanged<ScreenProtectionMode> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Material(
      color: selected ? colors.accentSoft : colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        side: BorderSide(
          color: selected ? colors.accent : colors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: enabled ? () => onTap(mode) : null,
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.all(AnchSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AnchSpacing.xs),
                      Text(
                        description,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AnchSpacing.md),
                if (selected)
                  AnchIcon(
                    AnchIcons.success,
                    key: Key('screen_protection_selected_${mode.name}'),
                    color: colors.accent,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
