import 'package:flutter/material.dart';

import '../../core/theme/questra_colors.dart';

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
                _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: 'ホーム',
                  selected: currentIndex == 0,
                  onTap: () => onDestinationSelected(0),
                ),
                _NavItem(
                  icon: Icons.explore_outlined,
                  selectedIcon: Icons.explore,
                  label: 'クエスト',
                  selected: currentIndex == 1,
                  onTap: () => onDestinationSelected(1),
                ),
                _ArcNavItem(
                  selected: currentIndex == 2,
                  onTap: () => onDestinationSelected(2),
                ),
                _NavItem(
                  icon: Icons.timeline_outlined,
                  selectedIcon: Icons.timeline,
                  label: 'トレイル',
                  selected: currentIndex == 3,
                  onTap: () => onDestinationSelected(3),
                ),
                _NavItem(
                  icon: Icons.flag_outlined,
                  selectedIcon: Icons.flag,
                  label: 'ミッション',
                  selected: currentIndex == 4,
                  onTap: () => onDestinationSelected(4),
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
                Icon(selected ? selectedIcon : icon, color: color, size: 22),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcNavItem extends StatelessWidget {
  const _ArcNavItem({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: 'アーク',
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: SizedBox(
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: selected ? 60 : 54,
                  height: selected ? 60 : 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [QuestraColors.skyBlue, QuestraColors.cosmicBlue],
                      center: Alignment.topLeft,
                    ),
                    border: Border.all(color: QuestraColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: QuestraColors.gold.withValues(
                          alpha: selected ? 0.34 : 0.18,
                        ),
                        blurRadius: selected ? 22 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.travel_explore,
                    color: QuestraColors.white,
                    size: 28,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: Text(
                    'アーク',
                    style: TextStyle(
                      color: selected
                          ? QuestraColors.gold
                          : QuestraColors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
