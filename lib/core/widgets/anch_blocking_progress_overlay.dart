import 'package:flutter/material.dart';

import '../theme/anch_colors.dart';
import '../theme/anch_radius.dart';
import '../theme/anch_spacing.dart';

/// 阻断页面交互的共享长操作进度遮罩。
///
/// 业务调用方负责提供可靠进度和阶段说明；组件只处理主题、可访问性与阻断行为。
class AnchBlockingProgressOverlay extends StatelessWidget {
  final String title;
  final String message;
  final double? progress;
  final String semanticsLabel;
  final Key? barrierKey;
  final VoidCallback? onCancel;
  final String? cancelLabel;

  const AnchBlockingProgressOverlay({
    super.key,
    required this.title,
    required this.message,
    required this.progress,
    required this.semanticsLabel,
    this.barrierKey,
    this.onCancel,
    this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.anchColors;
    final normalizedProgress = progress?.clamp(0.0, 1.0).toDouble();
    final percentage = normalizedProgress == null
        ? null
        : '${(normalizedProgress * 100).floor()}%';

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            ModalBarrier(
              key: barrierKey,
              dismissible: false,
              color: const Color(0x8A000000),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AnchSpacing.lg),
                child: Semantics(
                  label: semanticsLabel,
                  value: percentage,
                  liveRegion: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Material(
                      color: colors.surface,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(AnchRadius.lg),
                      ),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: colors.textPrimary,
                          decoration: TextDecoration.none,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AnchSpacing.xl,
                            vertical: AnchSpacing.lg,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: AnchSpacing.md),
                              if (normalizedProgress == null)
                                const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              else
                                LinearProgressIndicator(
                                  value: normalizedProgress,
                                  minHeight: 4,
                                  color: colors.accent,
                                  backgroundColor: colors.accentSoft,
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(2),
                                  ),
                                ),
                              if (percentage != null) ...[
                                const SizedBox(height: AnchSpacing.sm),
                                Text(
                                  percentage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colors.accentDeep,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                              const SizedBox(height: AnchSpacing.sm),
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.textSecondary,
                                  height: 1.4,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              if (onCancel != null) ...[
                                const SizedBox(height: AnchSpacing.md),
                                TextButton(
                                  onPressed: onCancel,
                                  child: Text(cancelLabel ?? '取消'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
