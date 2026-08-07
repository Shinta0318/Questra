import 'package:flutter/material.dart';

import 'arc_emotion.dart';
import 'arc_widget.dart';

class ArcApprovedPortrait extends StatelessWidget {
  const ArcApprovedPortrait({
    this.size = 96,
    this.emotion = ArcEmotion.normal,
    super.key,
  });

  final double size;
  final ArcEmotion emotion;

  @override
  Widget build(BuildContext context) {
    return ArcWidget(emotion: emotion, size: size, showSpeechBubble: false);
  }
}
