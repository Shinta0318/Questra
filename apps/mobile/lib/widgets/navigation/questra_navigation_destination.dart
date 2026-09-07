import 'package:flutter/material.dart';

import '../../core/router/app_routes.dart';
import '../../l10n/app_localizations.dart';

enum QuestraNavigationDestination {
  home(
    label: 'ホーム',
    compactLabel: 'ホーム',
    route: AppRoutes.home,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
  ),
  quest(
    label: 'Quest',
    compactLabel: 'Quest',
    route: AppRoutes.quest,
    icon: Icons.explore_outlined,
    selectedIcon: Icons.explore,
  ),
  arc(
    label: 'Arc',
    compactLabel: 'Arc',
    route: AppRoutes.arc,
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
  ),
  trail(
    label: 'Trail',
    compactLabel: 'Trail',
    route: AppRoutes.trail,
    icon: Icons.timeline_outlined,
    selectedIcon: Icons.timeline,
  ),
  profile(
    label: 'プロフィール',
    compactLabel: '自分',
    route: AppRoutes.profile,
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
  );

  const QuestraNavigationDestination({
    required this.label,
    required this.compactLabel,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String compactLabel;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  bool get isArc => this == QuestraNavigationDestination.arc;

  String localizedLabel(AppLocalizations copy) => switch (this) {
    QuestraNavigationDestination.home => copy.home,
    QuestraNavigationDestination.quest => copy.quest,
    QuestraNavigationDestination.arc => copy.arc,
    QuestraNavigationDestination.trail => copy.trail,
    QuestraNavigationDestination.profile => copy.profile,
  };

  String localizedCompactLabel(AppLocalizations copy) => switch (this) {
    QuestraNavigationDestination.profile => copy.profileCompact,
    _ => localizedLabel(copy),
  };
}
