import '../quest/arc_quest_guide_service.dart';

abstract final class MissionPlanGraphService {
  static const minMissionCount = 3;
  static const maxMissionCount = 30;

  static List<ArcMissionCandidate> normalize(
    Iterable<ArcMissionCandidate> input,
  ) {
    final source = input.take(maxMissionCount).toList(growable: false);
    final usedKeys = <String>{};
    final withKeys = <ArcMissionCandidate>[];
    for (var index = 0; index < source.length; index++) {
      var key = _safeKey(source[index].planKey, index);
      while (!usedKeys.add(key)) {
        key = '$key-${index + 1}';
      }
      withKeys.add(source[index].copyWith(planKey: key));
    }

    final keys = withKeys.map((item) => item.planKey).toSet();
    final normalized = <ArcMissionCandidate>[];
    for (final candidate in withKeys) {
      final parent = candidate.parentPlanKey;
      final safeParent =
          parent != null &&
              parent != candidate.planKey &&
              keys.contains(parent) &&
              !_wouldCreateParentCycle(candidate.planKey, parent, withKeys)
          ? parent
          : null;
      final dependencies = candidate.dependencyPlanKeys
          .where(
            (key) =>
                key != candidate.planKey &&
                keys.contains(key) &&
                !_wouldCreateDependencyCycle(candidate.planKey, key, withKeys),
          )
          .toSet()
          .toList(growable: false);
      normalized.add(
        candidate.copyWith(
          parentPlanKey: safeParent,
          clearParentPlan: safeParent == null,
          dependencyPlanKeys: dependencies,
        ),
      );
    }
    return normalized;
  }

  static String _safeKey(String value, int index) {
    final compact = value.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
    if (compact.isEmpty) return 'mission-${index + 1}';
    return compact.length <= 64 ? compact : compact.substring(0, 64);
  }

  static bool _wouldCreateParentCycle(
    String child,
    String parent,
    List<ArcMissionCandidate> candidates,
  ) {
    final byKey = {for (final item in candidates) item.planKey: item};
    final visited = <String>{child};
    String? cursor = parent;
    while (cursor != null) {
      if (!visited.add(cursor)) return true;
      cursor = byKey[cursor]?.parentPlanKey;
    }
    return false;
  }

  static bool _wouldCreateDependencyCycle(
    String candidate,
    String dependency,
    List<ArcMissionCandidate> candidates,
  ) {
    final byKey = {for (final item in candidates) item.planKey: item};
    final pending = <String>[dependency];
    final visited = <String>{};
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (current == candidate) return true;
      if (!visited.add(current)) continue;
      pending.addAll(byKey[current]?.dependencyPlanKeys ?? const []);
    }
    return false;
  }
}
