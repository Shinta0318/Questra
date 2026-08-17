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
    expect(theme.snackBarTheme.backgroundColor, AppColors.notificationSurface);
    expect(
      theme.snackBarTheme.contentTextStyle?.color,
      AppColors.notificationText,
    );
    expect(theme.snackBarTheme.contentTextStyle?.fontSize, 15);
    expect(theme.snackBarTheme.contentTextStyle?.fontWeight, FontWeight.w600);
    expect(theme.snackBarTheme.showCloseIcon, isTrue);
    expect(theme.tooltipTheme.textStyle?.letterSpacing, 0);
    expect(theme.progressIndicatorTheme.color, AppColors.gold);
    expect(tokens.cardPadding, const EdgeInsets.all(AppSpacing.xl));
    expect(tokens.buttonRadius, AppRadius.button);
  });

  test('light and dark SnackBars share an AA contrast-safe palette', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final background = theme.snackBarTheme.backgroundColor!;
      final foreground = theme.snackBarTheme.contentTextStyle!.color!;
      expect(_contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
      expect(theme.snackBarTheme.closeIconColor, AppColors.notificationMuted);
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = [
    first.computeLuminance(),
    second.computeLuminance(),
  ].reduce((a, b) => a > b ? a : b);
  final darker = [
    first.computeLuminance(),
    second.computeLuminance(),
  ].reduce((a, b) => a < b ? a : b);
  return (lighter + 0.05) / (darker + 0.05);
}
