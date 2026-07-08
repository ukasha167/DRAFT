import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

abstract final class AppColors {
  static const ink = draftInk;
  static const paper = draftBackground;
  static const cream = draftSurface;
  static const muted = draftInkSecondary;
  static const divide = draftDivider;
  static const blood = draftRed;

  static const dkInk = draftInkDark;
  static const dkPaper = draftBackgroundDark;
  static const dkCream = draftSurfaceDark;
  static const dkMuted = draftInkSecondaryDark;
  static const dkDivide = draftDividerDark;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 16.0;
  static const l = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class AppTheme {
  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'ClashDisplay',

    colorScheme: const ColorScheme.light(
      primary: draftInk,
      onPrimary: draftBackground,
      secondary: draftInk,
      surface: draftSurface,
      onSurface: draftInk,
      error: draftRed,
    ),
    scaffoldBackgroundColor: draftBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: draftBackground,
      foregroundColor: draftInk,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: _inputDecoration(
      fill: draftBackground,
      text: draftInk,
      hint: draftInkDisabled,
      border: draftBorder,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(draftInk),
        foregroundColor: WidgetStateProperty.all(draftBackground),
        textStyle: WidgetStateProperty.all(clashDisplayButton),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 0, horizontal: 24),
        ),
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
      ),
    ),
    dividerColor: draftDivider,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: draftSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: draftBorder, width: 1),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: draftSurface,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: draftInk,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: draftInk,
      foregroundColor: draftBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'ClashDisplay',

    colorScheme: const ColorScheme.dark(
      primary: draftInkDark,
      onPrimary: draftBackgroundDark,
      secondary: draftInkDark,
      surface: draftSurfaceDark,
      onSurface: draftInkDark,
      error: draftRed,
    ),
    scaffoldBackgroundColor: draftBackgroundDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: draftBackgroundDark,
      foregroundColor: draftInkDark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: _inputDecoration(
      fill: draftBackgroundDark,
      text: draftInkDark,
      hint: draftInkDisabledDark,
      border: draftBorderDark,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(draftInkDark),
        foregroundColor: WidgetStateProperty.all(draftBackgroundDark),
        textStyle: WidgetStateProperty.all(clashDisplayButton),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: 0, horizontal: 24),
        ),
        minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)),
      ),
    ),
    dividerColor: draftDividerDark,
    cardTheme: const CardThemeData(
      elevation: 0,
      color: draftSurfaceDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: draftBorderDark, width: 1),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: draftSurfaceDark,
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: draftInkDark,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: draftInkDark,
      foregroundColor: draftBackgroundDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
  );

  static InputDecorationTheme _inputDecoration({
    required Color fill,
    required Color text,
    required Color hint,
    required Color border,
  }) {
    final enabledBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.transparent, width: 0),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hintStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: hint,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: enabledBorder,
      enabledBorder: enabledBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: border, width: 1),
      ),
    );
  }
}
