import 'mission_model.dart';

class TodayMissionRecommendation {
  const TodayMissionRecommendation({
    required this.mission,
    required this.reason,
  });

  final Mission mission;
  final String reason;
}

abstract final class TodayBestNextMissionService {
  static TodayMissionRecommendation? recommend(List<Mission> missions) {
    final completed = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .map((mission) => mission.id)
        .toSet();
    final candidates = missions
        .where(
          (mission) =>
              mission.status == MissionStatus.todo &&
              mission.routeState == MissionRouteState.active &&
              mission.dependencyIds.every(completed.contains),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => _score(b).compareTo(_score(a)));
    final mission = candidates.first;
    return TodayMissionRecommendation(
      mission: mission,
      reason: mission.isToday ? '今日選んだ一歩です。' : '今の航路で、無理なく次に進める一歩です。',
    );
  }

  static int _score(Mission mission) {
    final priority = switch (mission.priority) {
      MissionPriority.critical => 40,
      MissionPriority.high => 30,
      MissionPriority.normal => 20,
      MissionPriority.low => 10,
    };
    return priority +
        (mission.isToday ? 100 : 0) -
        mission.sortOrder.clamp(0, 20);
  }
}
