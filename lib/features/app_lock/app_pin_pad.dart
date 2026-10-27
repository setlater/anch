import 'package:flutter/material.dart';

import '../../core/theme/anch_colors.dart';
import '../../core/theme/anch_spacing.dart';

class AppPinDots extends StatelessWidget {
  const AppPinDots({super.key, required this.length, this.total = 6});

  final int length;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (index) {
        final filled = index < length;
        return Container(
          key: Key('pin_dot_$index'),
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? colors.accent : Colors.transparent,
            border: Border.all(
              color: filled ? colors.accent : colors.divider,
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class AppPinPad extends StatelessWidget {
  const AppPinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onBiometric,
    this.enabled = true,
    this.canBackspace = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onBiometric;
  final bool enabled;
  final bool canBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _digitRow([1, 2, 3]),
        const SizedBox(height: AnchSpacing.sm),
        _digitRow([4, 5, 6]),
        const SizedBox(height: AnchSpacing.sm),
        _digitRow([7, 8, 9]),
        const SizedBox(height: AnchSpacing.sm),
        Row(
          children: [
            Expanded(
              child: onBiometric == null
                  ? const SizedBox(height: 64)
                  : _PinPadAction(
                      key: const Key('pin_biometric'),
                      semanticLabel: '使用生物识别',
                      enabled: true,
                      onTap: onBiometric,
                      child: const Text(
                        '生物识别',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            Expanded(child: _digitButton(0)),
            Expanded(
              child: _PinPadAction(
                key: const Key('pin_backspace'),
                semanticLabel: '删除一位 PIN',
                enabled: enabled && canBackspace,
                onTap: onBackspace,
                child: const Icon(Icons.backspace_outlined, size: 26),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _digitRow(List<int> digits) {
    return Row(
      children: [
        for (final digit in digits) Expanded(child: _digitButton(digit)),
      ],
    );
  }

  Widget _digitButton(int digit) {
    return _PinPadAction(
      key: Key('pin_digit_$digit'),
      semanticLabel: '数字 $digit',
      enabled: enabled,
      onTap: () => onDigit(digit),
      child: Text(
        '$digit',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _PinPadAction extends StatelessWidget {
  const _PinPadAction({
    super.key,
    required this.semanticLabel,
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final bool enabled;
  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: 64,
        child: InkWell(
          onTap: enabled ? onTap : null,
          splashFactory: NoSplash.splashFactory,
          child: Center(
            child: IconTheme(
              data: IconThemeData(
                color: enabled ? colors.textPrimary : colors.textMuted,
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: enabled ? colors.textPrimary : colors.textMuted,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
