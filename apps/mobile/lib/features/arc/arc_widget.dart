import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';
import 'arc_emotion.dart';

class ArcWidget extends StatelessWidget {
  const ArcWidget({
    this.emotion = ArcEmotion.normal,
    this.message,
    this.size = 132,
    super.key,
  });

  final ArcEmotion emotion;
  final String? message;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = _ArcPalette.fromEmotion(emotion);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [colors.glow, colors.core],
              center: Alignment.topLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.core.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: size * 0.68,
              height: size * 0.68,
              decoration: BoxDecoration(
                color: QuestraColors.deepNavy.withValues(alpha: 0.84),
                shape: BoxShape.circle,
                border: Border.all(color: QuestraColors.gold, width: 2),
              ),
              child: Center(
                child: Text(
                  emotion.face,
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: size * 0.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(
            message!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

class _ArcPalette {
  const _ArcPalette({
    required this.core,
    required this.glow,
    required this.accent,
  });

  final Color core;
  final Color glow;
  final Color accent;

  factory _ArcPalette.fromEmotion(ArcEmotion emotion) {
    return switch (emotion) {
      ArcEmotion.normal => const _ArcPalette(
        core: QuestraColors.cosmicBlue,
        glow: QuestraColors.skyBlue,
        accent: QuestraColors.white,
      ),
      ArcEmotion.excited => const _ArcPalette(
        core: Color(0xFF1CB5E0),
        glow: Color(0xFFB8F7FF),
        accent: QuestraColors.gold,
      ),
      ArcEmotion.support => const _ArcPalette(
        core: Color(0xFF2FBF71),
        glow: Color(0xFFB8F5D1),
        accent: QuestraColors.white,
      ),
      ArcEmotion.serious => const _ArcPalette(
        core: QuestraColors.midnightNavy,
        glow: QuestraColors.cosmicBlue,
        accent: QuestraColors.gold,
      ),
      ArcEmotion.worried => const _ArcPalette(
        core: Color(0xFF7B61FF),
        glow: Color(0xFFD7C8FF),
        accent: QuestraColors.white,
      ),
      ArcEmotion.lonely => const _ArcPalette(
        core: Color(0xFF5F6F89),
        glow: Color(0xFFC7D0DD),
        accent: QuestraColors.white,
      ),
      ArcEmotion.celebrate => const _ArcPalette(
        core: QuestraColors.gold,
        glow: Color(0xFFFFF1B8),
        accent: QuestraColors.deepNavy,
      ),
    };
  }
}
