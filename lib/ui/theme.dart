import 'package:flutter/material.dart';

/// Dark canvas, one amber accent. Nothing else gets a colour.
abstract final class AppColors {
  static const bg = Color(0xFF0B0B0C);
  static const surface = Color(0xFF141416);
  static const surfaceAlt = Color(0xFF1C1C1F);
  static const hairline = Color(0xFF26262A);
  static const text = Color(0xFFF4F1EA);
  static const textDim = Color(0xFF8A8780);
  static const amber = Color(0xFFE8A33D);
  static const amberDim = Color(0xFF4A3A1E);
  static const over = Color(0xFFD9603F);
}

abstract final class AppSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppText {
  static const hero = TextStyle(
    fontSize: 56,
    height: 1,
    fontWeight: FontWeight.w300,
    letterSpacing: -2,
    color: AppColors.text,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const title = TextStyle(
    fontSize: 28,
    height: 1.1,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.8,
    color: AppColors.text,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const label = TextStyle(
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.4,
    color: AppColors.textDim,
  );

  static const body = TextStyle(
    fontSize: 15,
    height: 1.35,
    color: AppColors.text,
  );

  static const mono = TextStyle(
    fontSize: 14,
    height: 1.2,
    color: AppColors.textDim,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.amber,
    onPrimary: AppColors.bg,
    secondary: AppColors.amber,
    onSecondary: AppColors.bg,
    surface: AppColors.surface,
    onSurface: AppColors.text,
    error: AppColors.over,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: 1,
      space: 1,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.surfaceAlt,
      contentTextStyle: AppText.body,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
