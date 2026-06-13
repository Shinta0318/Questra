import 'package:flutter/material.dart';

import 'questra_colors.dart';

abstract final class QuestraTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: QuestraColors.cosmicBlue,
      brightness: Brightness.light,
      primary: QuestraColors.cosmicBlue,
      secondary: QuestraColors.gold,
      surface: QuestraColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: QuestraColors.cloud,
      appBarTheme: const AppBarTheme(
        backgroundColor: QuestraColors.deepNavy,
        foregroundColor: QuestraColors.white,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: QuestraColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: QuestraColors.gold,
          foregroundColor: QuestraColors.deepNavy,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: QuestraColors.deepNavy,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
        titleLarge: TextStyle(
          color: QuestraColors.deepNavy,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        bodyMedium: TextStyle(color: QuestraColors.slate, letterSpacing: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: QuestraColors.white,
        indicatorColor: QuestraColors.gold.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? QuestraColors.deepNavy
                : QuestraColors.slate,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
