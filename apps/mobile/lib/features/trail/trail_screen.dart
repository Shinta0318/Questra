import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class TrailScreen extends StatelessWidget {
  const TrailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Trail',
      subtitle: 'Quest and Mission progress logs will live here.',
    );
  }
}
