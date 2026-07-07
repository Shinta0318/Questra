import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../layout/questra_responsive_layout.dart';
import '../theme/questra_colors.dart';
import '../../widgets/navigation/questra_arc_floating_entry.dart';
import '../../widgets/navigation/questra_bottom_navigation.dart';
import '../../widgets/navigation/questra_navigation_rail.dart';
import '../../widgets/navigation/questra_quick_action_menu.dart';
import 'app_routes.dart';

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
          floatingActionButton: _ShellFloatingActions(
            showArcEntry:
                navigationShell.currentIndex !=
                QuestraNavigationDestination.arc.index,
            extended: extendedRail,
            onOpenArc: () => context.go(AppRoutes.arc),
            onQuickActionSelected: (action) =>
                _selectQuickAction(context, action),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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

  void _selectQuickAction(BuildContext context, QuestraQuickAction action) {
    switch (action) {
      case QuestraQuickAction.createQuest:
        context.go('${AppRoutes.quest}/create');
      case QuestraQuickAction.createTrail:
        context.go(AppRoutes.trail);
      case QuestraQuickAction.openArc:
        context.go(AppRoutes.arc);
      case QuestraQuickAction.openGuild:
        context.go(AppRoutes.guild);
    }
  }
}

class _ShellFloatingActions extends StatelessWidget {
  const _ShellFloatingActions({
    required this.showArcEntry,
    required this.extended,
    required this.onOpenArc,
    required this.onQuickActionSelected,
  });

  final bool showArcEntry;
  final bool extended;
  final VoidCallback onOpenArc;
  final ValueChanged<QuestraQuickAction> onQuickActionSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showArcEntry) ...[
          QuestraArcFloatingEntry(extended: extended, onPressed: onOpenArc),
          const SizedBox(height: 10),
        ],
        QuestraQuickActionMenu(
          extended: extended,
          onSelected: onQuickActionSelected,
        ),
      ],
    );
  }
}
