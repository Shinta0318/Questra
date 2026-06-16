import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

class ArcGuidance {
  const ArcGuidance({
    required this.nextMission,
    required this.questComment,
    required this.reflectionFeedback,
    this.questTitle,
    this.missionTitle,
    this.trailTitle,
    this.reflectionTitle,
  });

  final String nextMission;
  final String questComment;
  final String reflectionFeedback;
  final String? questTitle;
  final String? missionTitle;
  final String? trailTitle;
  final String? reflectionTitle;
}

class ArcGuidanceService {
  const ArcGuidanceService();

  ArcGuidance build({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
  }) {
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));
    final openMissions =
        missions
            .where((mission) => mission.status == MissionStatus.todo)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final recentTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final reflections = recentTrails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .toList();

    final quest = activeQuests.firstOrNull;
    final mission = openMissions.firstOrNull;
    final trail = recentTrails.firstOrNull;
    final reflection = reflections.firstOrNull;

    return ArcGuidance(
      questTitle: quest?.title,
      missionTitle: mission?.title,
      trailTitle: trail?.title,
      reflectionTitle: reflection?.title,
      nextMission: _nextMission(quest, mission, reflection),
      questComment: _questComment(quest),
      reflectionFeedback: _reflectionFeedback(reflection, trail),
    );
  }

  String _nextMission(Quest? quest, Mission? mission, Trail? reflection) {
    if (mission != null) {
      return '次は「${mission.title}」を小さく進めよう。終えたらTrailへ残せば、航路がはっきりするよ。';
    }
    if (reflection != null) {
      return 'Reflectionに残した気づきから、5分でできるMissionをひとつ選ぼう。';
    }
    if (quest != null) {
      return '「${quest.title}」から今日のMissionをひとつ作ろう。小さくて見える一歩がいい。';
    }
    return 'まずQuestをひとつ星にしよう。そこから次のMissionを一緒に見つけられるよ。';
  }

  String _questComment(Quest? quest) {
    if (quest == null) {
      return '今はQuestを始める前の静かな場所にいるね。願いを一文で置くところから始めよう。';
    }
    final percent = (quest.progress * 100).round();
    return '「${quest.title}」は$percent%まで見えているよ。焦らず、次のMissionで少しだけ輪郭を濃くしよう。';
  }

  String _reflectionFeedback(Trail? reflection, Trail? latestTrail) {
    if (reflection != null) {
      return '「${reflection.title}」のReflectionは、次のMissionを選ぶための手がかりになっているよ。';
    }
    if (latestTrail != null) {
      return '最新のTrail「${latestTrail.title}」に、学びと次の小さなMissionを足してみよう。';
    }
    return '最初のTrailを残したら、そこからArcが次の行動を一緒に見つけるよ。';
  }
}
