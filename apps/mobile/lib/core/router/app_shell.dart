import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_tour_controller.dart';
import '../layout/questra_responsive_layout.dart';
import '../theme/questra_colors.dart';
import '../../widgets/navigation/questra_bottom_navigation.dart';
import '../../widgets/navigation/questra_navigation_rail.dart';
import '../../widgets/onboarding/questra_onboarding_tour.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final tourVisible = ref.watch(onboardingTourControllerProvider).isVisible;
    final navigationShell = widget.navigationShell;

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = QuestraLayoutSpec.fromWidth(constraints.maxWidth);
        final usesRail = !layout.isCompact;
        final extendedRail =
            constraints.maxWidth >= QuestraBreakpoints.extendedNavigation;

        return Stack(
          children: [
            Scaffold(
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
                          color: QuestraColors.cosmicBlue.withValues(
                            alpha: 0.28,
                          ),
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
            ),
            if (tourVisible) const QuestraOnboardingTour(),
          ],
        );
      },
    );
  }

  void _selectDestination(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
