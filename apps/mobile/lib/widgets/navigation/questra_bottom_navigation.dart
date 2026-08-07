import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';
import '../arc/arc_emotion.dart';
import '../arc/arc_widget.dart';
import 'questra_navigation_destination.dart';

export 'questra_navigation_destination.dart';

class QuestraBottomNavigation extends StatelessWidget {
  const QuestraBottomNavigation({
    required this.currentIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: QuestraColors.deepNavy,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: QuestraColors.cosmicBlue.withValues(alpha: 0.36),
            ),
            boxShadow: [
              BoxShadow(
                color: QuestraColors.deepNavy.withValues(alpha: 0.28),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                for (final destination in QuestraNavigationDestination.values)
                  if (destination.isArc)
                    _ArcNavItem(
                      key: ValueKey('nav-${destination.name}'),
                      selected: currentIndex == destination.index,
                      onTap: () => onDestinationSelected(destination.index),
                    )
                  else
                    _NavItem(
                      key: ValueKey('nav-${destination.name}'),
                      icon: destination.icon,
                      selectedIcon: destination.selectedIcon,
                      label: destination.label,
                      selected: currentIndex == destination.index,
                      onTap: () => onDestinationSelected(destination.index),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? QuestraColors.gold : QuestraColors.white;

    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        selected: selected,
        child: ExcludeSemantics(
          child: Tooltip(
            message: label,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? QuestraColors.cosmicBlue.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? selectedIcon : icon,
                      color: color,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcNavItem extends StatelessWidget {
  const _ArcNavItem({required this.selected, required this.onTap, super.key});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: 'Arc',
        button: true,
        selected: selected,
        child: ExcludeSemantics(
          child: Tooltip(
            message: 'Arc',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 58,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? QuestraColors.cosmicBlue.withValues(alpha: 0.22)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const ArcWidget(
                      emotion: ArcEmotion.normal,
                      size: 25,
                      showSpeechBubble: false,
                      interactive: false,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Arc',
                      style: TextStyle(
                        color:
                            selected ? QuestraColors.gold : QuestraColors.white,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
