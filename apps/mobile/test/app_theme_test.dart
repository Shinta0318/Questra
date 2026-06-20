import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_radius.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/core/theme/app_typography.dart';

void main() {
  test('AppTheme exposes Questra design system tokens', () {
    final theme = AppTheme.light;

    expect(theme.scaffoldBackgroundColor, AppColors.cloud);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w800);
    expect(theme.textTheme.bodyMedium?.letterSpacing, 0);
    expect(theme.extension<QuestraThemeTokens>(), isA<QuestraThemeTokens>());
  });

  test('Design system defines premium card and typography primitives', () {
    expect(AppRadius.glassCard, BorderRadius.circular(AppRadius.xl));
    expect(AppTypography.textTheme.headlineMedium?.color, AppColors.deepNavy);
    expect(AppTypography.textTheme.titleLarge?.letterSpacing, 0);
  });
}
