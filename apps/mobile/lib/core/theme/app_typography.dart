import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  static const textTheme = TextTheme(
    headlineMedium: TextStyle(
      color: AppColors.deepNavy,
      fontSize: 28,
      fontWeight: FontWeight.w900,
      height: 1.12,
      letterSpacing: 0,
    ),
    titleLarge: TextStyle(
      color: AppColors.deepNavy,
      fontSize: 20,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      color: AppColors.deepNavy,
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.25,
      letterSpacing: 0,
    ),
    bodyLarge: TextStyle(
      color: AppColors.slate,
      fontSize: 16,
      height: 1.45,
      letterSpacing: 0,
    ),
    bodyMedium: TextStyle(
      color: AppColors.slate,
      fontSize: 14,
      height: 1.42,
      letterSpacing: 0,
    ),
    bodySmall: TextStyle(
      color: AppColors.slate,
      fontSize: 12,
      height: 1.35,
      letterSpacing: 0,
    ),
  );
}
