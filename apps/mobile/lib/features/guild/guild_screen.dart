import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Guild',
      subtitle: '同じQuestや価値観を持つ仲間と出会い、Missionの相談やTrailの気づきを受け取る場所です。',
    );
  }
}
