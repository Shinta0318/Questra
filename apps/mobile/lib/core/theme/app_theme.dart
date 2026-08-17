import 'package:flutter/material.dart';

import '../accessibility/questra_accessibility.dart';
import 'app_colors.dart';
import 'app_field_sizes.dart';
import 'app_gradients.dart';
import 'app_radius.dart';
import 'app_shadows.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static SnackBarThemeData get _snackBarTheme => SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    backgroundColor: AppColors.notificationSurface,
    actionTextColor: AppColors.warmGold,
    disabledActionTextColor: AppColors.notificationMuted,
    contentTextStyle: const TextStyle(
      color: AppColors.notificationText,
      fontSize: 15,
      height: 1.35,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    ),
    elevation: 6,
    insetPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    showCloseIcon: true,
    closeIconColor: AppColors.notificationMuted,
    actionOverflowThreshold: 0.34,
    dismissDirection: DismissDirection.down,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
  );

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
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
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
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.cosmicBlue,
          minimumSize: const Size.square(QuestraAccessibility.minTapTarget),
          tapTargetSize: MaterialTapTargetSize.padded,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.deepNavy,
        elevation: 6,
        focusElevation: 8,
        hoverElevation: 8,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.cosmicBlue,
          side: BorderSide(color: AppColors.cosmicBlue.withValues(alpha: 0.32)),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          minimumSize: const Size(48, QuestraAccessibility.minTapTarget),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.cosmicBlue,
          minimumSize: const Size(48, QuestraAccessibility.minTapTarget),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        constraints: const BoxConstraints(minHeight: AppFieldSizes.shortInput),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
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
      snackBarTheme: _snackBarTheme,
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.midnightNavy,
          borderRadius: AppRadius.button,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        ),
        textStyle: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.cosmicBlue.withValues(alpha: 0.18),
        thickness: 1,
        space: AppSpacing.xl,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: AppSpacing.md,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        iconColor: AppColors.cosmicBlue,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.gold,
        linearTrackColor: AppColors.cosmicBlue.withValues(alpha: 0.12),
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
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered)
              ? AppColors.gold
              : AppColors.gold.withValues(alpha: 0.72),
        ),
        trackColor: WidgetStatePropertyAll(
          AppColors.white.withValues(alpha: 0.08),
        ),
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        interactive: true,
      ),
      extensions: <ThemeExtension<dynamic>>[const QuestraThemeTokens()],
    );
  }

  static ThemeData get dark {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.cosmicBlue,
      brightness: Brightness.dark,
      primary: AppColors.skyBlue,
      secondary: AppColors.gold,
      surface: AppColors.midnightNavy,
    );
    return light.copyWith(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.deepNavy,
      snackBarTheme: _snackBarTheme,
    );
  }
}

class QuestraThemeTokens extends ThemeExtension<QuestraThemeTokens> {
  const QuestraThemeTokens();

  LinearGradient get adventureGradient => AppGradients.adventure;
  LinearGradient get glassGradient => AppGradients.glass;
  List<BoxShadow> get glassShadow => AppShadows.glassCard;
  BorderRadius get cardRadius => AppRadius.card;
  BorderRadius get glassCardRadius => AppRadius.glassCard;
  BorderRadius get buttonRadius => AppRadius.button;
  EdgeInsets get cardPadding => const EdgeInsets.all(AppSpacing.xl);
  EdgeInsets get compactCardPadding => const EdgeInsets.all(AppSpacing.lg);
  double get sectionGap => AppSpacing.xl;
  double get componentGap => AppSpacing.md;

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
