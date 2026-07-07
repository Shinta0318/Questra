import 'package:flutter/material.dart';

import '../../core/accessibility/questra_accessibility.dart';
import '../../core/theme/questra_colors.dart';

enum QuestraQuickAction {
  createQuest(
    label: 'Questを始める',
    subtitle: '新しい挑戦をArcと灯す',
    icon: Icons.flag_outlined,
  ),
  createTrail(
    label: 'Trailを残す',
    subtitle: '今日の進み方を記録する',
    icon: Icons.timeline_outlined,
  ),
  openArc(
    label: 'Arcと話す',
    subtitle: '次の一歩を一緒に見つける',
    icon: Icons.auto_awesome_outlined,
  ),
  openGuild(
    label: 'Guildへ相談',
    subtitle: '仲間に持ち寄る問いを整える',
    icon: Icons.groups_outlined,
  );

  const QuestraQuickAction({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;
}

class QuestraQuickActionMenu extends StatelessWidget {
  const QuestraQuickActionMenu({
    required this.onSelected,
    this.extended = false,
    super.key,
  });

  final ValueChanged<QuestraQuickAction> onSelected;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (extended) {
      return FloatingActionButton.extended(
        key: const ValueKey('questra-quick-action-menu'),
        heroTag: 'questra-quick-action-menu',
        tooltip: 'クイックアクション',
        backgroundColor: QuestraColors.gold,
        foregroundColor: QuestraColors.deepNavy,
        elevation: 6,
        onPressed: () => _showActions(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Star Map'),
        extendedPadding: const EdgeInsetsDirectional.only(start: 18, end: 20),
      );
    }

    return FloatingActionButton(
      key: const ValueKey('questra-quick-action-menu'),
      heroTag: 'questra-quick-action-menu',
      tooltip: 'クイックアクション',
      backgroundColor: QuestraColors.gold,
      foregroundColor: QuestraColors.deepNavy,
      elevation: 6,
      onPressed: () => _showActions(context),
      child: const Icon(Icons.auto_awesome),
    );
  }

  Future<void> _showActions(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickActionSheet(onSelected: onSelected),
    );
  }
}

class _QuickActionSheet extends StatelessWidget {
  const _QuickActionSheet({required this.onSelected});

  final ValueChanged<QuestraQuickAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: QuestraColors.deepNavy,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: QuestraColors.gold.withValues(alpha: 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: QuestraColors.deepNavy.withValues(alpha: 0.32),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(8, 6, 8, 10),
                  child: Text(
                    '次の航路',
                    style: TextStyle(
                      color: QuestraColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                for (final action in QuestraQuickAction.values)
                  _QuickActionTile(
                    action: action,
                    onTap: () {
                      Navigator.of(context).pop();
                      onSelected(action);
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final QuestraQuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: action.label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: QuestraAccessibility.comfortableTapTargetConstraints,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: QuestraColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: QuestraColors.cosmicBlue.withValues(alpha: 0.24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: QuestraColors.gold.withValues(alpha: 0.18),
                      ),
                      child: Icon(action.icon, color: QuestraColors.gold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            action.label,
                            style: const TextStyle(
                              color: QuestraColors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            action.subtitle,
                            style: const TextStyle(
                              color: QuestraColors.parchment,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: QuestraColors.parchment,
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
