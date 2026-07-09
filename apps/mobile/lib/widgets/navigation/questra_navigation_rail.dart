import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import 'questra_navigation_destination.dart';

class QuestraNavigationRail extends StatelessWidget {
  const QuestraNavigationRail({
    required this.currentIndex,
    required this.onDestinationSelected,
    this.extended = false,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      right: false,
      child: NavigationRail(
        backgroundColor: QuestraColors.deepNavy,
        selectedIndex: currentIndex,
        onDestinationSelected: onDestinationSelected,
        extended: extended,
        minWidth: 80,
        minExtendedWidth: 216,
        groupAlignment: -0.72,
        labelType: extended
            ? NavigationRailLabelType.none
            : NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(color: QuestraColors.gold),
        unselectedIconTheme: const IconThemeData(color: QuestraColors.white),
        selectedLabelTextStyle: const TextStyle(
          color: QuestraColors.gold,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: QuestraColors.white,
          fontWeight: FontWeight.w600,
        ),
        leading: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: extended
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, color: QuestraColors.gold),
                    SizedBox(width: 12),
                    Text(
                      'Questra',
                      style: TextStyle(
                        color: QuestraColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                )
              : const Icon(Icons.auto_awesome, color: QuestraColors.gold),
        ),
        destinations: [
          for (final destination in QuestraNavigationDestination.values)
            NavigationRailDestination(
              icon: destination.isArc
                  ? const _RailArcIcon(selected: false)
                  : Icon(destination.icon),
              selectedIcon: destination.isArc
                  ? const _RailArcIcon(selected: true)
                  : Icon(destination.selectedIcon),
              label: Text(destination.label),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
        ],
      ),
    );
  }
}

class _RailArcIcon extends StatelessWidget {
  const _RailArcIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: selected ? 48 : 44,
      height: selected ? 48 : 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: QuestraColors.white.withValues(alpha: 0.08),
        border: Border.all(color: QuestraColors.gold, width: selected ? 2 : 1),
      ),
      child: const ArcWidget(
        emotion: ArcEmotion.normal,
        size: 34,
        showSpeechBubble: false,
      ),
    );
  }
}
