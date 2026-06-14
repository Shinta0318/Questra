import 'package:flutter/material.dart';

import '../questra_card.dart';
import 'arc_emotion.dart';
import 'arc_speech_bubble.dart';
import 'arc_widget.dart';

class ArcHomeExample extends StatelessWidget {
  const ArcHomeExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuestraCard(
      child: Column(
        children: [
          ArcWidget(
            emotion: ArcEmotion.support,
            message: 'Today has a path. I will help you find the first star.',
          ),
        ],
      ),
    );
  }
}

class ArcChatExample extends StatelessWidget {
  const ArcChatExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const QuestraCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArcWidget(
            emotion: ArcEmotion.normal,
            size: 72,
            showSpeechBubble: false,
          ),
          SizedBox(width: 12),
          Expanded(
            child: ArcSpeechBubble(
              message: 'Tell me where you want to go next. No rush.',
            ),
          ),
        ],
      ),
    );
  }
}
