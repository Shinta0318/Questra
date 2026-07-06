import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/questra_responsive_layout.dart';
import '../theme/questra_colors.dart';
import '../../widgets/navigation/questra_bottom_navigation.dart';
import '../../widgets/navigation/questra_navigation_rail.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = QuestraLayoutSpec.fromWidth(constraints.maxWidth);
        final usesRail = !layout.isCompact;
        final extendedRail =
            constraints.maxWidth >= QuestraBreakpoints.extendedNavigation;

        return Scaffold(
          body: usesRail
              ? Row(
                  children: [
                    QuestraNavigationRail(
                      currentIndex: navigationShell.currentIndex,
                      extended: extendedRail,
                      onDestinationSelected: _selectDestination,
                    ),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: QuestraColors.cosmicBlue.withValues(alpha: 0.28),
                    ),
                    Expanded(child: navigationShell),
                  ],
                )
              : navigationShell,
          bottomNavigationBar: usesRail
              ? null
              : QuestraBottomNavigation(
                  currentIndex: navigationShell.currentIndex,
                  onDestinationSelected: _selectDestination,
                ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
