import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens — single source of truth
// Neo-brutalist: ink/paper palette, heavy Manrope, flat surfaces.
// Blood red for favorite hearts only. Everything else is black and white.
// ---------------------------------------------------------------------------

abstract final class AppColors {
  // Light mode
  static const ink     = Color(0xFF0A0A0A);  // near-black: text, icons, borders
  static const paper   = Color(0xFFFAFAFA);  // near-white: scaffold background
  static const cream   = Color(0xFFF0EDE8);  // warm off-white: input fill, surfaces
  static const muted   = Color(0xFF888888);  // secondary text, inactive tabs
  static const divide  = Color(0xFFDDDDDD);  // dividers
  static const blood   = Color(0xFFE8261C);  // favorites heart — used nowhere else

  // Dark mode
  static const dkInk    = Color(0xFFF0EDE8);
  static const dkPaper  = Color(0xFF0A0A0A);
  static const dkCream  = Color(0xFF1A1A1A);
  static const dkMuted  = Color(0xFF5A5A5A);
  static const dkDivide = Color(0xFF2A2A2A);
}

abstract final class AppSpacing {
  static const xs  =  4.0;
  static const s   =  8.0;
  static const m   = 16.0;
  static const l   = 24.0;
  static const xl  = 32.0;
  static const xxl = 48.0;
}

abstract final class AppTheme {
  // ------------------------------------------------------------------
  // Light
  // ------------------------------------------------------------------
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'Manrope',
    colorScheme: const ColorScheme.light(
      primary:    AppColors.ink,
      onPrimary:  AppColors.paper,
      secondary:  AppColors.ink,
      background: AppColors.paper,
      surface:    AppColors.paper,
      onSurface:  AppColors.ink,
      error:      Color(0xFFCC2200),
    ),
    scaffoldBackgroundColor: AppColors.paper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.paper,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: _textTheme(AppColors.ink),
    inputDecorationTheme: _inputDecoration(
      fill:   AppColors.cream,
      text:   AppColors.ink,
      hint:   AppColors.muted,
      border: AppColors.ink,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.ink),
        foregroundColor: WidgetStateProperty.all(AppColors.paper),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.ink),
        side: WidgetStateProperty.all(
          const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    dividerColor: AppColors.divide,
    cardTheme: const CardThemeData(elevation: 0, color: AppColors.cream),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.paper,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.ink,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope', fontSize: 13,
        fontWeight: FontWeight.w500, color: AppColors.paper,
      ),
    ),
  );

  // ------------------------------------------------------------------
  // Dark
  // ------------------------------------------------------------------
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Manrope',
    colorScheme: const ColorScheme.dark(
      primary:    AppColors.dkInk,
      onPrimary:  AppColors.dkPaper,
      secondary:  AppColors.dkInk,
      background: AppColors.dkPaper,
      surface:    AppColors.dkPaper,
      onSurface:  AppColors.dkInk,
      error:      Color(0xFFFF5533),
    ),
    scaffoldBackgroundColor: AppColors.dkPaper,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.dkPaper,
      foregroundColor: AppColors.dkInk,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: _textTheme(AppColors.dkInk),
    inputDecorationTheme: _inputDecoration(
      fill:   AppColors.dkCream,
      text:   AppColors.dkInk,
      hint:   AppColors.dkMuted,
      border: AppColors.dkInk,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(AppColors.dkInk),
        foregroundColor: WidgetStateProperty.all(AppColors.dkPaper),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.dkInk),
        side: WidgetStateProperty.all(
          const BorderSide(color: AppColors.dkInk, width: 1.5),
        ),
        textStyle: WidgetStateProperty.all(
          const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600, fontSize: 14),
        ),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    ),
    dividerColor: AppColors.dkDivide,
    cardTheme: const CardThemeData(elevation: 0, color: AppColors.dkCream),
    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.dkCream,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(
        fontFamily: 'Manrope', fontSize: 14,
        fontWeight: FontWeight.w500, color: AppColors.dkInk,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.dkInk,
      contentTextStyle: TextStyle(
        fontFamily: 'Manrope', fontSize: 13,
        fontWeight: FontWeight.w500, color: AppColors.dkPaper,
      ),
    ),
  );

  // ------------------------------------------------------------------
  // Private helpers
  // ------------------------------------------------------------------

  static TextTheme _textTheme(Color base) {
    final muted = base.withOpacity(0.5);
    return TextTheme(
      // Display — "LIBRARY", "WISHLIST", book title in detail
      displayLarge: TextStyle(
        fontFamily: 'Manrope', fontSize: 38, fontWeight: FontWeight.w800,
        color: base, letterSpacing: -0.5, height: 1.1,
      ),
      displayMedium: TextStyle(
        fontFamily: 'Manrope', fontSize: 30, fontWeight: FontWeight.w800,
        color: base, letterSpacing: -0.3, height: 1.15,
      ),
      displaySmall: TextStyle(
        fontFamily: 'Manrope', fontSize: 24, fontWeight: FontWeight.w800,
        color: base, letterSpacing: -0.2, height: 1.2,
      ),
      // Headlines
      headlineLarge: TextStyle(
        fontFamily: 'Manrope', fontSize: 22, fontWeight: FontWeight.w700,
        color: base,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'Manrope', fontSize: 18, fontWeight: FontWeight.w700,
        color: base,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'Manrope', fontSize: 16, fontWeight: FontWeight.w700,
        color: base,
      ),
      // Titles
      titleLarge: TextStyle(
        fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700,
        color: base,
      ),
      titleMedium: TextStyle(
        fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w600,
        color: base,
      ),
      titleSmall: TextStyle(
        fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w600,
        color: base,
      ),
      // Body
      bodyLarge: TextStyle(
        fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w400,
        color: base,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'Manrope', fontSize: 14, fontWeight: FontWeight.w400,
        color: base,
      ),
      bodySmall: TextStyle(
        fontFamily: 'Manrope', fontSize: 12, fontWeight: FontWeight.w400,
        color: muted,
      ),
      // Labels
      labelLarge: TextStyle(
        fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w600,
        color: base,
      ),
      labelMedium: TextStyle(
        fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.w600,
        color: muted,
      ),
      labelSmall: TextStyle(
        fontFamily: 'Manrope', fontSize: 10, fontWeight: FontWeight.w500,
        color: muted, letterSpacing: 0.5,
      ),
    );
  }

  static InputDecorationTheme _inputDecoration({
    required Color fill,
    required Color text,
    required Color hint,
    required Color border,
  }) {
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: border.withOpacity(0.15), width: 1),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(
        fontFamily: 'Manrope', fontSize: 14,
        fontWeight: FontWeight.w400, color: hint,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border, width: 1.5),
      ),
    );
  }
}
