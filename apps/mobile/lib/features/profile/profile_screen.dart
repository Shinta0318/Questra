import 'package:flutter/material.dart';

import '../../widgets/placeholder_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Profile',
      subtitle: 'Player identity and achievements will live here.',
    );
  }
}
