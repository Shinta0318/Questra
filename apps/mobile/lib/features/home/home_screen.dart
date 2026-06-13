import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/placeholder_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Home',
      subtitle: 'A themed home placeholder for the Questra mobile app.',
      actionLabel: 'Open Quests',
      actionRoute: AppRoutes.quest,
    );
  }
}
