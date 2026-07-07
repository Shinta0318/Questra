import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/accessibility/questra_accessibility.dart';
import 'package:questra/core/theme/app_colors.dart';
import 'package:questra/core/theme/app_radius.dart';
import 'package:questra/core/theme/app_spacing.dart';
import 'package:questra/core/theme/app_theme.dart';
import 'package:questra/core/theme/app_typography.dart';

void main() {
  test('AppTheme exposes Questra design system tokens', () {
    final theme = AppTheme.light;

    expect(theme.scaffoldBackgroundColor, AppColors.cloud);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w800);
    expect(theme.textTheme.bodyMedium?.letterSpacing, 0);
    expect(theme.extension<QuestraThemeTokens>(), isA<QuestraThemeTokens>());
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
  });

  test('Design system defines premium card and typography primitives', () {
    expect(AppRadius.glassCard, BorderRadius.circular(AppRadius.xl));
    expect(AppTypography.textTheme.headlineMedium?.color, AppColors.deepNavy);
    expect(AppTypography.textTheme.titleLarge?.letterSpacing, 0);
  });

  test('Design system V2 defines shared component rules', () {
    final theme = AppTheme.light;
    final tokens = theme.extension<QuestraThemeTokens>()!;

    expect(
      theme.iconButtonTheme.style?.minimumSize?.resolve({}),
      const Size.square(QuestraAccessibility.minTapTarget),
    );
    expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    expect(theme.tooltipTheme.textStyle?.letterSpacing, 0);
    expect(theme.progressIndicatorTheme.color, AppColors.gold);
    expect(tokens.cardPadding, const EdgeInsets.all(AppSpacing.xl));
    expect(tokens.buttonRadius, AppRadius.button);
  });
}
