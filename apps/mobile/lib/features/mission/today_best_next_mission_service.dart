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
  static TodayMissionRecommendation? recommend(
    List<Mission> missions, {
    int? availableMinutes,
    Set<String> excludedMissionIds = const {},
    String? fiveMinuteMissionId,
  }) {
    if (availableMinutes != null && availableMinutes <= 0) return null;
    final completed = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .map((mission) => mission.id)
        .toSet();
    final candidates = missions
        .where(
          (mission) =>
              mission.status == MissionStatus.todo &&
              mission.routeState == MissionRouteState.active &&
              !excludedMissionIds.contains(mission.id) &&
              mission.dependencyIds.every(completed.contains),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) =>
          _score(b, availableMinutes).compareTo(_score(a, availableMinutes)),
    );
    final mission = candidates.first;
    final effortMinutes = mission.effortEstimate?.activeEffortMinutes;
    final fitsAvailability =
        availableMinutes != null &&
        effortMinutes != null &&
        effortMinutes <= availableMinutes;
    return TodayMissionRecommendation(
      mission: mission,
      reason: mission.id == fiveMinuteMissionId
          ? '今日は5分だけ。途中でやめても大丈夫です。'
          : fitsAvailability
          ? '今日の$availableMinutes分に収まる、次の一歩です。'
          : mission.isToday
          ? '今日選んだ一歩です。'
          : '今の航路で、無理なく次に進める一歩です。',
    );
  }

  static int _score(Mission mission, int? availableMinutes) {
    final priority = switch (mission.priority) {
      MissionPriority.critical => 40,
      MissionPriority.high => 30,
      MissionPriority.normal => 20,
      MissionPriority.low => 10,
    };
    final effortMinutes = mission.effortEstimate?.activeEffortMinutes;
    final availabilityScore = availableMinutes == null || effortMinutes == null
        ? 0
        : effortMinutes <= availableMinutes
        ? 60
        : -(effortMinutes - availableMinutes).clamp(0, 240);
    return priority +
        (mission.isToday ? 100 : 0) -
        mission.sortOrder.clamp(0, 20) +
        availabilityScore;
  }
}
