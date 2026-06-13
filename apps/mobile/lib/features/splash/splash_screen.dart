import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../widgets/placeholder_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Questra',
      subtitle: 'Adventure begins here.',
      actionLabel: 'Enter',
      actionRoute: AppRoutes.login,
    );
  }
}
