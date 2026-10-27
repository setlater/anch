import 'package:anch/core/theme/anch_icons.dart';
import 'package:anch/core/widgets/anch_icon.dart';
import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';
import 'dart:math' as math;

/// 石墨资料册的敏感字段面板。
///
/// 只负责展示与交互编排；显隐、复制和安全生命周期仍由页面控制。
class AnchSensitivePlate extends StatelessWidget {
  const AnchSensitivePlate({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.displayValue,
    required this.isRevealed,
    required this.copyButtonKey,
    required this.onToggleReveal,
    required this.onCopy,
    this.valueLength,
  });

  final String fieldKey;
  final int? valueLength;
  final String label;
  final String displayValue;
  final bool isRevealed;
  final Key copyButtonKey;
  final VoidCallback onToggleReveal;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;

    return Container(
      key: const Key('primary_number_card'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AnchSpacing.sectionGap),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AnchRadius.lg),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AnchRadius.lg),
        child: Material(
          key: const Key('anch_sensitive_plate_surface'),
          color: colors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: AnchSpacing.lg,
                  vertical: AnchSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        key: Key('field_label_$fieldKey'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '仅本机可见',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final style = TextStyle(
                      fontSize: 20,
                      height: 1.6,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    );
                    double measure(String text) {
                      final painter = TextPainter(
                        text: TextSpan(text: text, style: style),
                        textDirection: Directionality.of(context),
                        textScaler: MediaQuery.textScalerOf(context),
                      )..layout(maxWidth: constraints.maxWidth);
                      final height = painter.height;
                      painter.dispose();
                      return height;
                    }

                    // 仅用长度预留空间，不把隐藏的明文传给展示组件。
                    final length = math.max(
                      24,
                      valueLength ?? displayValue.length,
                    );
                    final reservedHeight = math.max(
                      measure('8' * length),
                      measure('••••  ••••  ••••  8888'),
                    );
                    return ConstrainedBox(
                      key: Key('sensitive_value_zone_$fieldKey'),
                      constraints: BoxConstraints(
                        minHeight: math.max(40, reservedHeight),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(displayValue, style: style),
                      ),
                    );
                  },
                ),
              ),
              Container(
                key: Key('field_trailing_actions_$fieldKey'),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PlateAction(
                        buttonKey: const Key('primary_sensitive_reveal_button'),
                        icon: isRevealed
                            ? AnchIcons.visibilityOff
                            : AnchIcons.visibility,
                        label: isRevealed ? '隐藏' : '查看',
                        foreground: colors.accent,
                        background: colors.surface,
                        onTap: onToggleReveal,
                      ),
                    ),
                    SizedBox(
                      height: 48,
                      child: VerticalDivider(
                        width: 1,
                        thickness: 1,
                        color: colors.divider,
                      ),
                    ),
                    Expanded(
                      child: _PlateAction(
                        buttonKey: copyButtonKey,
                        icon: AnchIcons.copy,
                        label: '复制',
                        foreground: colors.accent,
                        background: colors.surface,
                        onTap: onCopy,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlateAction extends StatelessWidget {
  const _PlateAction({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    required this.onTap,
  });

  final Key buttonKey;
  final AnchIconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      key: buttonKey,
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 48),
        tapTargetSize: MaterialTapTargetSize.padded,
        padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.md),
        elevation: 0,
        backgroundColor: background,
        foregroundColor: foreground,
        shadowColor: Colors.transparent,
        shape: const RoundedRectangleBorder(),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnchIcon(icon, size: 18),
          const SizedBox(width: AnchSpacing.sm),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
