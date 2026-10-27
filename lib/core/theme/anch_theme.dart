import 'package:flutter/material.dart';
import 'anch_colors.dart';
import 'anch_motion.dart';
import 'anch_radius.dart';

/// 安册主题入口。
///
/// 提供 [AnchTheme.light]，可直接赋给 [MaterialApp.theme]。
///
/// 保持 Material 3 行为能力，但视觉按“石墨资料册”定制。
abstract final class AnchTheme {
  AnchTheme._();

  /// 安册亮色主题。
  static ThemeData get light =>
      _buildTheme(AnchColorsExtension.light, Brightness.light);

  /// 安册暗色主题。
  static ThemeData get dark =>
      _buildTheme(AnchColorsExtension.dark, Brightness.dark);

  static ThemeData _buildTheme(
    AnchColorsExtension tokens,
    Brightness brightness,
  ) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: tokens.accent,
      onPrimary: tokens.accentInk,
      primaryContainer: tokens.accentSoft,
      onPrimaryContainer: tokens.accentDeep,
      secondary: tokens.accent,
      onSecondary: tokens.accentInk,
      secondaryContainer: tokens.accentSoft,
      onSecondaryContainer: tokens.textPrimary,
      tertiary: tokens.accent,
      onTertiary: tokens.accentInk,
      tertiaryContainer: tokens.accentSoft,
      onTertiaryContainer: tokens.textPrimary,
      error: tokens.danger,
      onError: tokens.accentInk,
      errorContainer: tokens.dangerSoft,
      onErrorContainer: tokens.danger,
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      surfaceContainerHighest: tokens.surfaceSoft,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.borderStrong,
      outlineVariant: tokens.divider,
      scrim: tokens.textPrimary.withValues(alpha: 0.4),
      inverseSurface: tokens.textPrimary,
      onInverseSurface: tokens.background,
      inversePrimary: tokens.accent,
      shadow: tokens.textPrimary.withValues(alpha: 0.1),
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      pageTransitionsTheme: AnchMotion.pageTransitionsTheme,

      // 页面背景
      scaffoldBackgroundColor: tokens.background,

      // 全局文本主题
      textTheme: _buildTextTheme(
        textPrimary: tokens.textPrimary,
        textSecondary: tokens.textSecondary,
        textMuted: tokens.textMuted,
      ),

      // Theme Extensions
      extensions: [tokens],

      // 应用栏
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: tokens.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          height: 1.25,
        ),
        iconTheme: IconThemeData(color: tokens.textSecondary),
      ),

      // 按钮
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.accent,
          foregroundColor: tokens.accentInk,
          disabledBackgroundColor: tokens.surfaceSoft,
          disabledForegroundColor: tokens.textMuted,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnchRadius.md),
          ),
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.accent,
          side: BorderSide(color: tokens.surfaceMuted, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AnchRadius.md),
          ),
          minimumSize: const Size.fromHeight(48),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.accent,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // 输入框
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: tokens.borderStrong, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: tokens.borderStrong, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: tokens.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
          borderSide: BorderSide(color: tokens.danger, width: 2),
        ),
        labelStyle: TextStyle(color: tokens.textSecondary, fontSize: 14),
        hintStyle: TextStyle(color: tokens.textMuted, fontSize: 14),
        errorStyle: TextStyle(color: tokens.danger, fontSize: 12),
      ),

      // 卡片
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.lg),
          side: BorderSide(color: tokens.divider, width: 1),
        ),
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: tokens.divider,
        thickness: 1,
        space: 1,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.accentInk,
        elevation: brightness == Brightness.dark ? 0 : 4,
        focusElevation: brightness == Brightness.dark ? 0 : 4,
        hoverElevation: brightness == Brightness.dark ? 0 : 5,
        highlightElevation: brightness == Brightness.dark ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.fab),
        ),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.surfaceSoft,
        contentTextStyle: TextStyle(color: tokens.textPrimary, fontSize: 13),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.sm),
        ),
      ),

      // 底部导航栏
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.accentSoft,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: tokens.accent, size: 22);
          }
          return IconThemeData(color: tokens.textMuted, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: tokens.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: tokens.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          );
        }),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.accent;
          return tokens.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return tokens.accentSoft;
          return tokens.divider;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: tokens.surfaceSoft,
        labelStyle: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide(color: tokens.divider, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AnchRadius.status),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  static TextTheme _buildTextTheme({
    required Color textPrimary,
    required Color textSecondary,
    required Color textMuted,
  }) {
    return TextTheme(
      // 页面大标题
      headlineLarge: TextStyle(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      // 页面标题
      headlineMedium: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.25,
      ),
      // 详情正文标题
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      // 卡片标题
      titleMedium: TextStyle(
        color: textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      // 小标题、字段标签标题
      titleSmall: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
        height: 1.4,
      ),
      // 正文
      bodyLarge: TextStyle(
        color: textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      // 次级正文
      bodyMedium: TextStyle(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      // 辅助说明
      bodySmall: TextStyle(
        color: textMuted,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      // 标签
      labelLarge: TextStyle(
        color: textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
    );
  }
}
