import '../mission/mission_model.dart';
import 'quest_guide_model.dart';
import 'quest_milestone_model.dart';
import 'quest_model.dart';

class QuestMilestoneService {
  const QuestMilestoneService();

  List<QuestMilestone> plan({
    required Quest quest,
    required List<QuestGuide> guides,
    required List<Mission> missions,
  }) {
    final completedMissionCount = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;
    final missionProgress = missions.isEmpty
        ? 0.0
        : completedMissionCount / missions.length;

    return [
      QuestMilestone(
        questId: quest.id,
        title: '目的地を決める',
        description: 'Questの達成状態と最初の判断基準を言葉にする。',
        status: quest.progress > 0 || guides.isNotEmpty
            ? QuestMilestoneStatus.completed
            : QuestMilestoneStatus.active,
        progress: guides.isEmpty ? quest.progress.clamp(0, 0.35) : 1,
        sortOrder: 0,
        guideType: GuideType.route,
      ),
      QuestMilestone(
        questId: quest.id,
        title: 'Missionへ分解する',
        description: 'GuideやArc Guideから、今日できる小さなMissionを作る。',
        status: missions.isEmpty
            ? QuestMilestoneStatus.active
            : QuestMilestoneStatus.completed,
        progress: missions.isEmpty ? 0.25 : 1,
        sortOrder: 1,
        guideType: GuideType.training,
      ),
      QuestMilestone(
        questId: quest.id,
        title: 'Trailで進行を残す',
        description: '完了したMissionや気づきをTrailに残し、次の航路へつなげる。',
        status: missionProgress >= 1
            ? QuestMilestoneStatus.completed
            : QuestMilestoneStatus.active,
        progress: missionProgress.clamp(0, 1),
        sortOrder: 2,
        guideType: GuideType.knowledge,
      ),
    ];
  }

  QuestMilestoneStatus nextStatus(QuestMilestoneStatus status) {
    return switch (status) {
      QuestMilestoneStatus.planned => QuestMilestoneStatus.active,
      QuestMilestoneStatus.active => QuestMilestoneStatus.completed,
      QuestMilestoneStatus.completed => QuestMilestoneStatus.planned,
    };
  }
}
