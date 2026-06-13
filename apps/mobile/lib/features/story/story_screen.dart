import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class StoryScreen extends StatelessWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Story',
      subtitle: 'Narrative memories and lore will live here.',
    );
  }
}
