import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_shadows.dart';
import '../../core/theme/questra_colors.dart';

class ArcSpeechBubble extends StatelessWidget {
  const ArcSpeechBubble({
    required this.message,
    this.maxWidth = 280,
    super.key,
  });

  final String message;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.glass,
          borderRadius: AppRadius.card,
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.26)),
          boxShadow: AppShadows.goldGlow,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: QuestraColors.midnightNavy,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}
