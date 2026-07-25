import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';

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
          color: AppColors.midnightNavy.withValues(alpha: 0.84),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.skyBlue.withValues(alpha: 0.20)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Text(
            message,
            textAlign: TextAlign.start,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.white,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
