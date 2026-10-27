import 'package:flutter/material.dart';
import '../theme/anch_colors.dart';
import '../theme/anch_spacing.dart';

/// 录入流程进度与步骤名称。
class AnchStepIndicator extends StatelessWidget {
  const AnchStepIndicator({
    super.key,
    required this.totalSteps,
    required this.currentStep,
    this.labels,
  });

  /// 总步骤数
  final int totalSteps;

  /// 当前步骤（0-based）
  final int currentStep;
  final List<String>? labels;

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AnchSpacing.page,
        vertical: 6.0,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (int i = 0; i < totalSteps; i++) ...[
                if (i > 0) const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels?[i] ?? '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: i == currentStep
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: i == currentStep
                              ? colors.accent
                              : colors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        key: ValueKey('step_indicator_segment_$i'),
                        duration: const Duration(milliseconds: 250),
                        width: double.infinity,
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= currentStep
                              ? colors.accent
                              : colors.divider,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
