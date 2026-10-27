import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_icons.dart';
import '../theme/anch_motion.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';
import 'anch_icon.dart';

/// 统一展示安册的底部弹窗外壳。
Future<T?> showAnchBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: context.anchColors.textPrimary.withValues(alpha: 0.32),
    sheetAnimationStyle: AnchMotion.bottomSheetAnimationStyle(context),
    builder: builder,
  );
}

/// 底部弹窗的共享表面与拖拽提示。
class AnchBottomSheetFrame extends StatelessWidget {
  const AnchBottomSheetFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Material(
      color: colors.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AnchRadius.xl),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AnchSpacing.sm),
              decoration: BoxDecoration(
                color: colors.surfaceMuted,
                borderRadius: BorderRadius.circular(AnchRadius.pill),
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

/// 选择类弹窗的标题与可选说明。
class AnchBottomSheetHeader extends StatelessWidget {
  const AnchBottomSheetHeader({
    super.key,
    required this.title,
    this.description,
  });

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AnchSpacing.page,
        AnchSpacing.md,
        AnchSpacing.page,
        AnchSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description case final String text) ...[
            const SizedBox(height: AnchSpacing.xs),
            Text(text, style: TextStyle(color: colors.textMuted, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// 平面档案式选项轨道，以细分隔线连接标题、选项与取消操作。
class AnchBottomSheetOptionGroup extends StatelessWidget {
  const AnchBottomSheetOptionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: colors.divider),
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(height: 1, thickness: 1, color: colors.divider),
        ],
      ],
    );
  }
}

/// 带图标、说明和可选选中态的选择行。
class AnchBottomSheetOption extends StatelessWidget {
  const AnchBottomSheetOption({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.onTap,
    this.isSelected = false,
    this.isDestructive = false,
  });

  final AnchIconData icon;
  final String title;
  final String? description;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final foreground = isDestructive ? colors.danger : colors.textPrimary;
    final iconColor = isDestructive
        ? colors.danger
        : isSelected
        ? colors.accent
        : colors.textSecondary;
    return Semantics(
      label: title,
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 62),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AnchSpacing.page,
                vertical: AnchSpacing.sm,
              ),
              child: Row(
                children: [
                  AnchIcon(icon, size: 20, color: iconColor),
                  const SizedBox(width: AnchSpacing.md),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: isSelected ? colors.accentDeep : foreground,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (description case final String text) ...[
                          const SizedBox(height: 2),
                          Text(
                            text,
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: AnchSpacing.sm),
                    AnchIcon(AnchIcons.success, size: 20, color: colors.accent),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 选择类弹窗的独立取消入口。
class AnchBottomSheetDismissAction extends StatelessWidget {
  const AnchBottomSheetDismissAction({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 1, thickness: 1, color: colors.divider),
        Semantics(
          button: true,
          label: '取消',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: Center(
                child: Text(
                  '取消',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 日期和时间滚轮使用的顶部操作栏。
class AnchBottomSheetPickerHeader extends StatelessWidget {
  const AnchBottomSheetPickerHeader({
    super.key,
    required this.title,
    required this.onCancel,
    required this.onConfirm,
  });

  final String title;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AnchSpacing.sm,
        AnchSpacing.xs,
        AnchSpacing.sm,
        AnchSpacing.sm,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 48,
            child: TextButton(onPressed: onCancel, child: const Text('取消')),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 64,
            height: 48,
            child: TextButton(
              onPressed: onConfirm,
              child: Text(
                '确定',
                style: TextStyle(
                  color: colors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
