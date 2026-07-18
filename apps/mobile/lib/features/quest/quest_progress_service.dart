import '../mission/mission_model.dart';

class QuestProgressSnapshot {
  const QuestProgressSnapshot({required this.completed, required this.total});

  final int completed;
  final int total;

  double get value => total == 0 ? 0 : completed / total;
  int get percent => (value * 100).round();
  String get missionCountLabel => '$completed/$total';
}

class QuestProgressService {
  const QuestProgressService();

  QuestProgressSnapshot calculate(Iterable<Mission> missions) {
    var total = 0;
    var completed = 0;
    for (final mission in missions) {
      total++;
      if (mission.status == MissionStatus.completed) completed++;
    }
    return QuestProgressSnapshot(completed: completed, total: total);
  }
}
