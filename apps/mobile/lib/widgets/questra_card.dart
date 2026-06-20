import 'package:flutter/material.dart';

import '../core/theme/app_gradients.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_shadows.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/questra_colors.dart';

class QuestraCard extends StatelessWidget {
  const QuestraCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      shadowColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: AppGradients.glass,
          borderRadius: AppRadius.glassCard,
          border: Border.all(
            color: QuestraColors.white.withValues(alpha: 0.72),
          ),
          boxShadow: AppShadows.glassCard,
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: child,
        ),
      ),
    );
  }
}
