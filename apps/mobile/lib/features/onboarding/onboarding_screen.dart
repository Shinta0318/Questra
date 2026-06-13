import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/placeholder_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Onboarding',
      subtitle: 'Player setup and first-run guidance will live here.',
      actionLabel: 'Start Questing',
      actionRoute: AppRoutes.quest,
    );
  }
}
