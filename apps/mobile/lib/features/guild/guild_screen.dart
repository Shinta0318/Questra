import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class GuildScreen extends StatelessWidget {
  const GuildScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Guild',
      subtitle:
          'Guild members, follows, and shared Quest activity will live here.',
    );
  }
}
