import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A surface and its readable foregrounds must be selected together.
enum QuestraSurfacePalette {
  light,
  dark;

  Color get background =>
      this == dark ? AppColors.midnightNavy : AppColors.white;
  Color get foreground =>
      this == dark ? AppColors.notificationText : AppColors.deepNavy;
  Color get muted =>
      this == dark ? AppColors.notificationMuted : AppColors.midnightNavy;
  Color get action => this == dark ? AppColors.skyBlue : AppColors.nebulaBlue;

  ThemeData theme(ThemeData base) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.cosmicBlue,
      brightness: this == dark ? Brightness.dark : Brightness.light,
      surface: background,
      onSurface: foreground,
      onSurfaceVariant: muted,
      primary: action,
      secondary: AppColors.gold,
      onSecondary: AppColors.deepNavy,
      secondaryContainer: AppColors.gold,
      onSecondaryContainer: AppColors.deepNavy,
      outline: action,
    );
    return base.copyWith(
      colorScheme: scheme,
      textTheme: base.textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      iconTheme: base.iconTheme.copyWith(color: action),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: background,
        labelStyle: TextStyle(color: foreground),
        hintStyle: TextStyle(color: muted),
        helperStyle: TextStyle(color: muted),
        counterStyle: TextStyle(color: muted),
      ),
      textButtonTheme: TextButtonThemeData(
        style: (base.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : action,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (base.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : action,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: action)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: (base.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          foregroundColor: WidgetStatePropertyAll(action),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.deepNavy
                : foreground,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.gold
                : background,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: action)),
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: background,
        textStyle: base.textTheme.bodyMedium?.copyWith(color: foreground),
      ),
    );
  }
}

class QuestraSurfaceScope extends StatelessWidget {
  const QuestraSurfaceScope({
    required this.palette,
    required this.child,
    super.key,
  });

  final QuestraSurfacePalette palette;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: palette.theme(Theme.of(context)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: palette.foreground),
        child: IconTheme.merge(
          data: IconThemeData(color: palette.action),
          child: child,
        ),
      ),
    );
  }
}
