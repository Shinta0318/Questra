import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/placeholder_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Login',
      subtitle: 'Authentication UI will live here.',
      actionLabel: 'Continue',
      actionRoute: AppRoutes.onboarding,
    );
  }
}
