import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/placeholder_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Settings',
      subtitle: 'Preferences and app configuration will live here.',
      actionLabel: 'Back to Quests',
      actionRoute: AppRoutes.quest,
    );
  }
}
