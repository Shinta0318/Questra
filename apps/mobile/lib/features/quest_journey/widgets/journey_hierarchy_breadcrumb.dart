import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

class JourneyHierarchyBreadcrumb extends StatelessWidget {
  const JourneyHierarchyBreadcrumb({
    required this.questId,
    required this.questTitle,
    this.missionId,
    this.missionTitle,
    this.currentLevel,
    super.key,
  });

  final String questId;
  final String questTitle;
  final String? missionId;
  final String? missionTitle;
  final String? currentLevel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '現在位置',
      explicitChildNodes: true,
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 4,
        runSpacing: 4,
        children: [
          _HierarchyLink(
            semanticLabel: '親Quest、$questTitleを開く',
            icon: Icons.flag_outlined,
            label: questTitle,
            onPressed: () => context.go('${AppRoutes.quest}/$questId'),
          ),
          if (missionId case final id?) ...[
            Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            _HierarchyLink(
              semanticLabel: '親Mission、${missionTitle ?? 'Mission'}を開く',
              icon: Icons.route_outlined,
              label: missionTitle ?? 'Mission',
              onPressed: () => context.go(AppRoutes.missionDetail(questId, id)),
            ),
          ],
          if (currentLevel case final level?) ...[
            Icon(Icons.chevron_right, size: 18, color: scheme.outline),
            Semantics(
              label: '現在の$level',
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  level,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HierarchyLink extends StatelessWidget {
  const _HierarchyLink({
    required this.semanticLabel,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String semanticLabel;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semanticLabel,
    excludeSemantics: true,
    child: TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    ),
  );
}
