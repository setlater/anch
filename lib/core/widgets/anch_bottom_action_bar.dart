import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';
import 'anch_adaptive_layout.dart';

/// 安册底部操作栏。
///
/// 用途：录入流程每个步骤的底部操作区。
///
/// 支持：
/// - 一个主按钮（必须）
/// - 一个次级文字按钮（可选）
/// - 加载态（主按钮禁用并显示 spinner）
///
/// 不写入任何业务保存逻辑。
class AnchBottomActionBar extends StatelessWidget {
  const AnchBottomActionBar({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.isLoading = false,
    this.primaryEnabled = true,
    this.compactWhenKeyboardVisible = false,
    this.compactPrimaryLabel,
    this.compactSecondaryLabel,
    this.isKeyboardVisible,
    this.flat = false,
  });

  /// 是否使用平坦/透明无边框模式
  final bool flat;

  /// 主按钮文案
  final String primaryLabel;

  /// 主按钮点击回调
  final VoidCallback? onPrimary;

  /// 次级按钮文案（可选）
  final String? secondaryLabel;

  /// 次级按钮点击回调（可选）
  final VoidCallback? onSecondary;

  /// 是否加载中（主按钮禁用并显示 spinner）
  final bool isLoading;

  /// 主按钮是否可用（false 时禁用但不显示 spinner）
  final bool primaryEnabled;

  /// 键盘弹出时是否开启紧凑模式
  final bool compactWhenKeyboardVisible;

  /// 紧凑模式下的主按钮文案（可选）
  final String? compactPrimaryLabel;

  /// 紧凑模式下的次级按钮文案（可选）
  final String? compactSecondaryLabel;

  /// 显式传入的键盘可见状态（可选），用于覆盖默认 MediaQuery 检测
  final bool? isKeyboardVisible;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final view = View.maybeOf(context);
    final keyboardHeight = view != null
        ? (view.viewInsets.bottom / view.devicePixelRatio)
        : 0.0;
    final isKeyboard =
        keyboardHeight > 0 || MediaQuery.of(context).viewInsets.bottom > 0;
    final isKeyboardActive = isKeyboardVisible ?? isKeyboard;
    final isCompactHeight =
        AnchLayoutScope.heightOf(context) == AnchWindowHeightClass.compact;
    final isKeyboardVisibleEffective =
        compactWhenKeyboardVisible && (isKeyboardActive || isCompactHeight);

    if (isKeyboardVisibleEffective &&
        secondaryLabel != null &&
        onSecondary != null) {
      // 键盘态下的紧凑双按钮布局
      final resolvedPrimary = compactPrimaryLabel ?? primaryLabel;
      final resolvedSecondary = compactSecondaryLabel ?? secondaryLabel!;

      return Container(
        decoration: BoxDecoration(
          color: flat ? Colors.transparent : colors.surfaceSoft,
          border: flat
              ? null
              : Border(top: BorderSide(color: colors.divider, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AnchSpacing.page,
          vertical: AnchSpacing.xs,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useStackedActions =
                MediaQuery.textScalerOf(context).scale(1) >= 1.5 ||
                constraints.maxWidth < 320;
            final secondaryButton = TextButton(
              onPressed: isLoading ? null : onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.md),
              ),
              child: Text(
                resolvedSecondary,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
            final primaryButton = ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryEnabled && !isLoading
                    ? colors.accent
                    : colors.accentSoft,
                foregroundColor: colors.accentInk,
                disabledBackgroundColor: colors.accentSoft,
                disabledForegroundColor: colors.textMuted,
                elevation: 0,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnchRadius.pill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.lg),
              ),
              onPressed: (isLoading || !primaryEnabled) ? null : onPrimary,
              child: isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textMuted,
                      ),
                    )
                  : Text(
                      resolvedPrimary,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            );

            if (useStackedActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  primaryButton,
                  const SizedBox(height: AnchSpacing.xs),
                  secondaryButton,
                ],
              );
            }

            return SizedBox(
              height: 48,
              child: Row(
                children: [secondaryButton, const Spacer(), primaryButton],
              ),
            );
          },
        ),
      );
    }

    // 非键盘态或单按钮键盘态（单按钮时自适应压缩高度和 padding）
    return Container(
      decoration: BoxDecoration(
        color: flat ? Colors.transparent : colors.surfaceSoft,
        border: flat
            ? null
            : Border(top: BorderSide(color: colors.divider, width: 1)),
      ),
      padding: EdgeInsets.fromLTRB(
        AnchSpacing.page,
        AnchSpacing.md,
        AnchSpacing.page,
        isKeyboardVisibleEffective ? AnchSpacing.md : AnchSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 主按钮
          ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: double.infinity,
              minHeight: isKeyboardVisibleEffective ? 48 : 52,
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryEnabled && !isLoading
                    ? colors.accent
                    : colors.accentSoft,
                foregroundColor: colors.accentInk,
                disabledBackgroundColor: colors.accentSoft,
                disabledForegroundColor: colors.textMuted,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AnchRadius.pill),
                ),
              ),
              onPressed: (isLoading || !primaryEnabled) ? null : onPrimary,
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.textMuted,
                      ),
                    )
                  : Text(
                      isKeyboardVisibleEffective
                          ? (compactPrimaryLabel ?? primaryLabel)
                          : primaryLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),

          // 次级按钮
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AnchSpacing.xs),
            TextButton(
              onPressed: isLoading ? null : onSecondary,
              style: TextButton.styleFrom(
                foregroundColor: colors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AnchSpacing.lg,
                  vertical: AnchSpacing.sm,
                ),
              ),
              child: Text(
                isKeyboardVisibleEffective
                    ? (compactSecondaryLabel ?? secondaryLabel!)
                    : secondaryLabel!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
