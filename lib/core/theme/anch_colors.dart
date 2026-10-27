import 'package:flutter/material.dart';

abstract final class _AnchLightPalette {
  static const Color background = Color(0xFFF5F5F7);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFEFF0F2);
  static const Color surfaceEmphasis = Color(0xFFE9EDF4);
  static const Color surfaceMuted = Color(0xFF9A9FAA);
  static const Color divider = Color(0xFFE4E5E9);
  static const Color textPrimary = Color(0xFF23262C);
  static const Color textSecondary = Color(0xFF5C6068);
  static const Color textMuted = Color(0xFF666D78);
  static const Color documentIcon = textSecondary;
  static const Color accent = Color(0xFF43516A);
  static const Color accentDeep = Color(0xFF344151);
  static const Color accentSoft = Color(0xFFE9EDF4);
  static const Color accentMuted = surfaceMuted;
  static const Color accentInk = Color(0xFFFFFFFF);
  static const Color warning = Color(0xFF805A1F);
  static const Color warningSoft = Color(0xFFF6EDD8);
  static const Color danger = Color(0xFFAC3745);
  static const Color dangerSoft = Color(0xFFF5E9E8);
  static const Color success = Color(0xFF3F7252);
  static const Color successSoft = Color(0xFFE6F0E9);
}

abstract final class _AnchDarkPalette {
  static const Color background = Color(0xFF17191E);
  static const Color surface = Color(0xFF22252B);
  static const Color surfaceSoft = Color(0xFF2B3038);
  static const Color surfaceEmphasis = Color(0xFF344055);
  static const Color surfaceMuted = Color(0xFF7C8594);
  static const Color divider = Color(0xFF393D45);
  static const Color textPrimary = Color(0xFFF0F1F4);
  static const Color textSecondary = Color(0xFFC1C5CC);
  static const Color textMuted = Color(0xFFA6ADB8);
  static const Color documentIcon = textSecondary;
  static const Color accent = Color(0xFFC7D2E5);
  static const Color accentDeep = Color(0xFFE3E9F2);
  static const Color accentSoft = Color(0xFF344055);
  static const Color accentMuted = surfaceMuted;
  static const Color accentInk = Color(0xFF172747);
  static const Color warning = Color(0xFFEDC887);
  static const Color warningSoft = Color(0xFF453A20);
  static const Color danger = Color(0xFFF4A3AE);
  static const Color dangerSoft = Color(0xFF452C2D);
  static const Color success = Color(0xFF84BD96);
  static const Color successSoft = Color(0xFF24372B);
}

class AnchColorsExtension extends ThemeExtension<AnchColorsExtension> {
  final Color background;
  final Color surface;
  final Color surfaceSoft;
  final Color surfaceEmphasis;
  final Color surfaceMuted;
  final Color borderStrong;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color documentIcon;
  final Color accent;
  final Color accentDeep;
  final Color accentSoft;
  final Color accentMuted;
  final Color accentInk;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color successSoft;

  const AnchColorsExtension({
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceEmphasis,
    required this.surfaceMuted,
    required this.borderStrong,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.documentIcon,
    required this.accent,
    required this.accentDeep,
    required this.accentSoft,
    required this.accentMuted,
    required this.accentInk,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
  });

  static const AnchColorsExtension light = AnchColorsExtension(
    background: _AnchLightPalette.background,
    surface: _AnchLightPalette.surface,
    surfaceSoft: _AnchLightPalette.surfaceSoft,
    surfaceEmphasis: _AnchLightPalette.surfaceEmphasis,
    surfaceMuted: _AnchLightPalette.surfaceMuted,
    borderStrong: _AnchLightPalette.surfaceMuted,
    divider: _AnchLightPalette.divider,
    textPrimary: _AnchLightPalette.textPrimary,
    textSecondary: _AnchLightPalette.textSecondary,
    textMuted: _AnchLightPalette.textMuted,
    documentIcon: _AnchLightPalette.documentIcon,
    accent: _AnchLightPalette.accent,
    accentDeep: _AnchLightPalette.accentDeep,
    accentSoft: _AnchLightPalette.accentSoft,
    accentMuted: _AnchLightPalette.accentMuted,
    accentInk: _AnchLightPalette.accentInk,
    warning: _AnchLightPalette.warning,
    warningSoft: _AnchLightPalette.warningSoft,
    danger: _AnchLightPalette.danger,
    dangerSoft: _AnchLightPalette.dangerSoft,
    success: _AnchLightPalette.success,
    successSoft: _AnchLightPalette.successSoft,
  );

  static const AnchColorsExtension dark = AnchColorsExtension(
    background: _AnchDarkPalette.background,
    surface: _AnchDarkPalette.surface,
    surfaceSoft: _AnchDarkPalette.surfaceSoft,
    surfaceEmphasis: _AnchDarkPalette.surfaceEmphasis,
    surfaceMuted: _AnchDarkPalette.surfaceMuted,
    borderStrong: _AnchDarkPalette.surfaceMuted,
    divider: _AnchDarkPalette.divider,
    textPrimary: _AnchDarkPalette.textPrimary,
    textSecondary: _AnchDarkPalette.textSecondary,
    textMuted: _AnchDarkPalette.textMuted,
    documentIcon: _AnchDarkPalette.documentIcon,
    accent: _AnchDarkPalette.accent,
    accentDeep: _AnchDarkPalette.accentDeep,
    accentSoft: _AnchDarkPalette.accentSoft,
    accentMuted: _AnchDarkPalette.accentMuted,
    accentInk: _AnchDarkPalette.accentInk,
    warning: _AnchDarkPalette.warning,
    warningSoft: _AnchDarkPalette.warningSoft,
    danger: _AnchDarkPalette.danger,
    dangerSoft: _AnchDarkPalette.dangerSoft,
    success: _AnchDarkPalette.success,
    successSoft: _AnchDarkPalette.successSoft,
  );

  @override
  AnchColorsExtension copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSoft,
    Color? surfaceEmphasis,
    Color? surfaceMuted,
    Color? borderStrong,
    Color? divider,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? documentIcon,
    Color? accent,
    Color? accentDeep,
    Color? accentSoft,
    Color? accentMuted,
    Color? accentInk,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? success,
    Color? successSoft,
  }) {
    return AnchColorsExtension(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceSoft: surfaceSoft ?? this.surfaceSoft,
      surfaceEmphasis: surfaceEmphasis ?? this.surfaceEmphasis,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      documentIcon: documentIcon ?? this.documentIcon,
      accent: accent ?? this.accent,
      accentDeep: accentDeep ?? this.accentDeep,
      accentSoft: accentSoft ?? this.accentSoft,
      accentMuted: accentMuted ?? this.accentMuted,
      accentInk: accentInk ?? this.accentInk,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
    );
  }

  @override
  AnchColorsExtension lerp(
    ThemeExtension<AnchColorsExtension>? other,
    double t,
  ) {
    if (other is! AnchColorsExtension) {
      return this;
    }
    return AnchColorsExtension(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSoft: Color.lerp(surfaceSoft, other.surfaceSoft, t)!,
      surfaceEmphasis: Color.lerp(surfaceEmphasis, other.surfaceEmphasis, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      documentIcon: Color.lerp(documentIcon, other.documentIcon, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentDeep: Color.lerp(accentDeep, other.accentDeep, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
    );
  }
}

extension AnchThemeColorsX on BuildContext {
  AnchColorsExtension get anchColors {
    return Theme.of(this).extension<AnchColorsExtension>() ??
        AnchColorsExtension.light;
  }
}
