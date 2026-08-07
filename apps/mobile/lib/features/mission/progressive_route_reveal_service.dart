import '../quest/arc_quest_guide_service.dart';

class ProgressiveRouteReveal {
  const ProgressiveRouteReveal({
    required this.today,
    required this.next,
    required this.future,
    required this.milestones,
  });

  final ArcMissionCandidate? today;
  final List<ArcMissionCandidate> next;
  final List<ArcMissionCandidate> future;
  final List<ProgressiveRouteMilestone> milestones;
}

class ProgressiveRouteMilestone {
  const ProgressiveRouteMilestone({
    required this.title,
    required this.items,
    required this.estimatedDays,
  });

  final String title;
  final List<ArcMissionCandidate> items;
  final int estimatedDays;
}

abstract final class ProgressiveRouteRevealService {
  static ProgressiveRouteReveal organize(List<ArcMissionCandidate> route) {
    final ordered = _dependencyAwareOrder(route);
    final today = ordered.isEmpty ? null : ordered.first;
    final next = ordered.skip(1).take(3).toList(growable: false);
    final future = ordered.skip(4).toList(growable: false);
    return ProgressiveRouteReveal(
      today: today,
      next: next,
      future: future,
      milestones: _milestones(future),
    );
  }

  static List<ProgressiveRouteMilestone> _milestones(
    List<ArcMissionCandidate> future,
  ) {
    final values = <ProgressiveRouteMilestone>[];
    for (var start = 0; start < future.length; start += 4) {
      final items = future.skip(start).take(4).toList(growable: false);
      values.add(
        ProgressiveRouteMilestone(
          title: 'Milestone ${values.length + 1}',
          items: items,
          estimatedDays: items.fold(
            0,
            (sum, item) => sum + (item.estimatedDurationDays ?? 0),
          ),
        ),
      );
    }
    return values;
  }

  static int _priority(ArcMissionCandidate candidate) =>
      switch (candidate.priority.name) {
        'critical' => 4,
        'high' => 3,
        'normal' => 2,
        _ => 1,
      };

  static List<ArcMissionCandidate> _dependencyAwareOrder(
    List<ArcMissionCandidate> route,
  ) {
    final remaining = [...route];
    final resolved = <String>{};
    final ordered = <ArcMissionCandidate>[];
    while (remaining.isNotEmpty) {
      final available =
          remaining
              .where(
                (candidate) =>
                    candidate.dependencyPlanKeys.every(resolved.contains),
              )
              .toList()
            ..sort((a, b) => _priority(b).compareTo(_priority(a)));
      if (available.isEmpty) {
        // Invalid or cyclic provider output remains visible for review, but it
        // is never promoted ahead of a feasible root Mission.
        ordered.addAll(remaining);
        break;
      }
      final selected = available.first;
      ordered.add(selected);
      remaining.remove(selected);
      if (selected.planKey.isNotEmpty) resolved.add(selected.planKey);
    }
    return ordered;
  }
}
