import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Guild',
      subtitle: '同じQuestや価値観を持つ仲間と出会う場所です。Guild Followや共有Trailはここに広がります。',
    );
  }
}
