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
            message: '今日の航路は見えているよ。最初の星を一緒に探そう。',
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
          Expanded(child: ArcSpeechBubble(message: '次に向かいたい星を聞かせて。急がなくて大丈夫。')),
        ],
      ),
    );
  }
}
