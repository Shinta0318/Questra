import 'package:flutter/material.dart';

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
          color: QuestraColors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: QuestraColors.cosmicBlue.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: QuestraColors.deepNavy.withValues(alpha: 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
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
