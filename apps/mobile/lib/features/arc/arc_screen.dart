import 'package:flutter/material.dart';

import '../../widgets/questra_card.dart';
import '../../widgets/arc/arc_examples.dart';
import 'arc_emotion.dart';
import 'arc_widget.dart';

class ArcScreen extends StatelessWidget {
  const ArcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arc Chat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const QuestraCard(
              child: ArcWidget(
                emotion: ArcEmotion.normal,
                message: '一緒に進もう。君の航路を覚えているよ。',
              ),
            ),
            const SizedBox(height: 16),
            Text('旅の会話', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const ArcHomeExample(),
            const SizedBox(height: 12),
            const ArcChatExample(),
            const SizedBox(height: 16),
            Text('Arcの表情', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: ArcEmotion.values
                  .map(
                    (emotion) => SizedBox(
                      width: 150,
                      child: QuestraCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            ArcWidget(emotion: emotion, size: 72),
                            const SizedBox(height: 8),
                            Text(
                              emotion.label,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
