import 'package:flutter/material.dart';

import '../core/theme/app_gradients.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/questra_colors.dart';
import '../core/theme/questra_surface_palette.dart';

class QuestraCard extends StatelessWidget {
  const QuestraCard({
    required this.child,
    this.padding,
    this.palette = QuestraSurfacePalette.light,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final QuestraSurfacePalette palette;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<QuestraThemeTokens>();

    return Card(
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        width: double.infinity,
        padding: padding ?? tokens?.cardPadding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.background,
          gradient: palette == QuestraSurfacePalette.light
              ? tokens?.glassGradient ?? AppGradients.glass
              : null,
          borderRadius: tokens?.glassCardRadius ?? AppRadius.glassCard,
          border: Border.all(
            color: QuestraColors.white.withValues(alpha: 0.72),
          ),
          boxShadow: tokens?.glassShadow ?? AppShadows.glassCard,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: QuestraSurfaceScope(palette: palette, child: child),
        ),
      ),
    );
  }
}
