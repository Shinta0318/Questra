import 'package:flutter/material.dart';

import '../questra_card.dart';
import 'arc_emotion.dart';
import 'arc_widget.dart';

enum ArcPresenceSurface {
  home,
  chat,
  quest,
  mission,
  trail,
  emptyState,
  reflection,
  celebration,
  concern,
}

class ArcPresence extends StatelessWidget {
  const ArcPresence({
    required this.surface,
    required this.emotion,
    required this.message,
    this.action,
    this.showCard = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    super.key,
  });

  final ArcPresenceSurface surface;
  final ArcEmotion emotion;
  final String message;
  final Widget? action;
  final bool showCard;
  final CrossAxisAlignment crossAxisAlignment;

  double get arcSize {
    return switch (surface) {
      ArcPresenceSurface.home => 132,
      ArcPresenceSurface.chat => 120,
      ArcPresenceSurface.quest => 104,
      ArcPresenceSurface.mission => 104,
      ArcPresenceSurface.trail => 104,
      ArcPresenceSurface.emptyState => 88,
      ArcPresenceSurface.reflection => 96,
      ArcPresenceSurface.celebration => 116,
      ArcPresenceSurface.concern => 96,
    };
  }

  EdgeInsetsGeometry get padding {
    return switch (surface) {
      ArcPresenceSurface.home => const EdgeInsets.all(20),
      ArcPresenceSurface.chat => const EdgeInsets.all(18),
      ArcPresenceSurface.emptyState => const EdgeInsets.all(16),
      _ => const EdgeInsets.all(18),
    };
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        ArcWidget(emotion: emotion, message: message, size: arcSize),
        if (action != null) ...[const SizedBox(height: 18), action!],
      ],
    );

    if (!showCard) {
      return content;
    }

    return QuestraCard(padding: padding, child: content);
  }
}
