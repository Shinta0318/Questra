import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';

enum QuestraNavigationDestination {
  home(
    label: 'ホーム',
    route: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  arc(
    label: 'Arc',
    route: AppRoutes.arc,
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  ),
  quest(
    label: 'Quest',
    route: AppRoutes.quest,
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  trail(
    label: 'Trail',
    route: AppRoutes.trail,
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline,
  ),
  guild(
    label: 'Guild',
    route: AppRoutes.guild,
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups,
  ),
  profile(
    label: 'プロフィール',
    route: AppRoutes.profile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const QuestraNavigationDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  bool get isArc => this == QuestraNavigationDestination.arc;
}
