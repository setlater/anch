import 'package:anch/core/theme/anch_colors.dart';
import 'package:anch/core/theme/anch_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('亮色主题使用石墨资料册画布与独立低饱和语义色', () {
    final colors = AnchTheme.light.extension<AnchColorsExtension>()!;

    expect(colors.background, const Color(0xFFF5F5F7));
    expect(colors.surface, const Color(0xFFFFFFFF));
    expect(colors.surfaceSoft, const Color(0xFFEFF0F2));
    expect(colors.surfaceEmphasis, const Color(0xFFE9EDF4));
    expect(colors.textPrimary, const Color(0xFF23262C));
    expect(colors.textSecondary, const Color(0xFF5C6068));
    expect(colors.textMuted, const Color(0xFF666D78));
    expect(colors.documentIcon, const Color(0xFF5C6068));
    expect(colors.accent, const Color(0xFF43516A));
    expect(colors.accentDeep, const Color(0xFF344151));
    expect(colors.accentSoft, const Color(0xFFE9EDF4));
    expect(colors.divider, const Color(0xFFE4E5E9));
    expect(colors.borderStrong, const Color(0xFF9A9FAA));
    expect(colors.success, const Color(0xFF3F7252));
    expect(colors.successSoft, const Color(0xFFE6F0E9));
    expect(colors.warning, const Color(0xFF805A1F));
    expect(colors.danger, const Color(0xFFAC3745));
  });

  test('亮暗主题的 Material 颜色均映射到同一组语义角色', () {
    for (final theme in [AnchTheme.light, AnchTheme.dark]) {
      final colors = theme.extension<AnchColorsExtension>()!;
      final scheme = theme.colorScheme;

      expect(theme.scaffoldBackgroundColor, colors.background);
      expect(scheme.primary, colors.accent);
      expect(scheme.primaryContainer, colors.accentSoft);
      expect(scheme.error, colors.danger);
      expect(scheme.errorContainer, colors.dangerSoft);
      expect(scheme.surface, colors.surface);
      expect(scheme.onSurface, colors.textPrimary);
      expect(scheme.onSurfaceVariant, colors.textSecondary);
      expect(scheme.outlineVariant, colors.divider);
      expect(scheme.outline, colors.borderStrong);
    }
  });

  test('正文、按钮与语义状态在各自背景上保持可读对比度', () {
    for (final colors in [
      AnchColorsExtension.light,
      AnchColorsExtension.dark,
    ]) {
      expect(
        _contrast(colors.textPrimary, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textSecondary, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.textMuted, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.accentInk, colors.accent),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.warning, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.danger, colors.background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(colors.success, colors.background),
        greaterThanOrEqualTo(4.5),
      );
    }
  });
}

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
