import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.cosmicBlue,
      brightness: Brightness.light,
      primary: AppColors.cosmicBlue,
      secondary: AppColors.gold,
      surface: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.cloud,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.deepNavy,
        foregroundColor: AppColors.white,
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shadowColor: AppColors.deepNavy.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.deepNavy,
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          elevation: 0,
          shadowColor: AppColors.gold.withValues(alpha: 0.24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cosmicBlue,
          side: BorderSide(color: AppColors.cosmicBlue.withValues(alpha: 0.32)),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(
            color: AppColors.cosmicBlue.withValues(alpha: 0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: BorderSide(
            color: AppColors.cosmicBlue.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.button,
          borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
        ),
      ),
      textTheme: AppTypography.textTheme,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.deepNavy,
        indicatorColor: AppColors.gold.withValues(alpha: 0.22),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.gold
                : AppColors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[const QuestraThemeTokens()],
    );
  }
}

class QuestraThemeTokens extends ThemeExtension<QuestraThemeTokens> {
  const QuestraThemeTokens();

  LinearGradient get adventureGradient => AppGradients.adventure;
  LinearGradient get glassGradient => AppGradients.glass;
  List<BoxShadow> get glassShadow => AppShadows.glassCard;

  @override
  ThemeExtension<QuestraThemeTokens> copyWith() {
    return const QuestraThemeTokens();
  }

  @override
  ThemeExtension<QuestraThemeTokens> lerp(
    covariant ThemeExtension<QuestraThemeTokens>? other,
    double t,
  ) {
    return const QuestraThemeTokens();
  }
}
