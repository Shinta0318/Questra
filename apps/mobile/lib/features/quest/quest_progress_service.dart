import '../mission/mission_model.dart';

class QuestProgressSnapshot {
  const QuestProgressSnapshot({
    required this.completed,
    required this.total,
    required this.progressTotal,
  });

  final int completed;
  final int total;
  final int progressTotal;

  double get value => total == 0 ? 0 : progressTotal / (total * 100);
  int get percent => (value * 100).round();
  String get missionCountLabel => '$completed/$total';
}

class QuestProgressService {
  const QuestProgressService();

  QuestProgressSnapshot calculate(Iterable<Mission> missions) {
    var total = 0;
    var completed = 0;
    var progressTotal = 0;
    for (final mission in missions) {
      if (!mission.required ||
          mission.routeState == MissionRouteState.removed) {
        continue;
      }
      total++;
      if (mission.status == MissionStatus.completed) {
        completed++;
        progressTotal += 100;
      }
    }
    return QuestProgressSnapshot(
      completed: completed,
      total: total,
      progressTotal: progressTotal,
    );
  }
}
