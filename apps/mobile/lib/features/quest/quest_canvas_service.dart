import '../mission/mission_model.dart';
import '../trail/trail_model.dart';
import 'quest_model.dart';

class QuestCanvasSnapshot {
  const QuestCanvasSnapshot({
    required this.quest,
    required this.missionCount,
    required this.completedMissionCount,
    required this.knowledgeCount,
    required this.skillThemes,
    required this.riskCount,
    required this.supportHintCount,
    required this.trailCount,
  });

  final Quest quest;
  final int missionCount;
  final int completedMissionCount;
  final int knowledgeCount;
  final List<String> skillThemes;
  final int riskCount;
  final int supportHintCount;
  final int trailCount;

  int get openMissionCount => missionCount - completedMissionCount;
  bool get isGrowing =>
      missionCount > 0 || knowledgeCount > 0 || trailCount > 0;
}

abstract final class QuestCanvasService {
  static QuestCanvasSnapshot build({
    required Quest quest,
    required Iterable<Mission> missions,
    required Iterable<Trail> trails,
  }) {
    final linkedMissions = missions
        .where((mission) => mission.questId == quest.id)
        .toList(growable: false);
    final linkedTrails = trails
        .where((trail) => trail.questId == quest.id)
        .toList(growable: false);
    final knowledge = linkedMissions
        .expand((mission) => mission.referenceHints)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    final skills = linkedMissions
        .map((mission) => mission.category.trim())
        .where((value) => value.isNotEmpty && value != '実行')
        .toSet()
        .take(5)
        .toList(growable: false);
    final supportHints = linkedMissions
        .expand((mission) => mission.enterpriseSupportHints)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    return QuestCanvasSnapshot(
      quest: quest,
      missionCount: linkedMissions.length,
      completedMissionCount: linkedMissions
          .where((mission) => mission.status == MissionStatus.completed)
          .length,
      knowledgeCount: knowledge.length,
      skillThemes: skills,
      riskCount: linkedMissions
          .where(
            (mission) =>
                mission.priority == MissionPriority.critical ||
                (mission.difficultyScore ?? 0) >= 4,
          )
          .length,
      supportHintCount: supportHints.length,
      trailCount: linkedTrails.length,
    );
  }
}
