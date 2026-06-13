import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/router/app_routes.dart';
import '../core/theme/questra_colors.dart';
import 'questra_card.dart';
import 'questra_primary_button.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.actionRoute,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? actionLabel;
  final String? actionRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Questra'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: QuestraCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.travel_explore,
                    color: QuestraColors.gold,
                    size: 40,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                  if (actionLabel != null && actionRoute != null) ...[
                    const SizedBox(height: 24),
                    QuestraPrimaryButton(
                      label: actionLabel!,
                      onPressed: () => context.go(actionRoute!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
