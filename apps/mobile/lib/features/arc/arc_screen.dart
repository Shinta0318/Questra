import 'package:flutter/material.dart';

import '../../widgets/questra_card.dart';
import 'arc_emotion.dart';
import 'arc_widget.dart';

class ArcScreen extends StatelessWidget {
  const ArcScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arc')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const QuestraCard(
              child: ArcWidget(
                emotion: ArcEmotion.normal,
                message: 'Arc is ready to guide the next step.',
              ),
            ),
            const SizedBox(height: 16),
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
