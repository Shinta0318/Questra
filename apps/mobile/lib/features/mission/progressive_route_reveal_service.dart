import '../quest/arc_quest_guide_service.dart';

class ProgressiveRouteReveal {
  const ProgressiveRouteReveal({
    required this.today,
    required this.next,
    required this.future,
  });

  final ArcMissionCandidate? today;
  final List<ArcMissionCandidate> next;
  final List<ArcMissionCandidate> future;
}

abstract final class ProgressiveRouteRevealService {
  static ProgressiveRouteReveal organize(List<ArcMissionCandidate> route) {
    final ordered = [...route]
      ..sort((a, b) => _priority(b).compareTo(_priority(a)));
    final today = ordered.isEmpty ? null : ordered.first;
    final next = ordered.skip(1).take(3).toList(growable: false);
    final future = ordered.skip(4).toList(growable: false);
    return ProgressiveRouteReveal(today: today, next: next, future: future);
  }

  static int _priority(ArcMissionCandidate candidate) =>
      switch (candidate.priority.name) {
        'critical' => 4,
        'high' => 3,
        'normal' => 2,
        _ => 1,
      };
}
