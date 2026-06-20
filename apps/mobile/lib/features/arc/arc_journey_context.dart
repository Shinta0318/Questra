import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

class ArcJourneyContext {
  const ArcJourneyContext({
    required this.activeQuestCount,
    required this.trailCount,
    required this.guidance,
    this.focusQuestTitle,
    this.latestTrailTitle,
  });

  final int activeQuestCount;
  final int trailCount;
  final String guidance;
  final String? focusQuestTitle;
  final String? latestTrailTitle;

  factory ArcJourneyContext.fromJourney({
    required List<Quest> quests,
    required List<Trail> trails,
  }) {
    final activeQuests =
        quests.where((quest) => quest.status == QuestStatus.active).toList()
          ..sort((a, b) => b.progress.compareTo(a.progress));
    final latestTrails = [...trails]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final focusQuest = activeQuests.firstOrNull;
    final latestTrail = latestTrails.firstOrNull;

    return ArcJourneyContext(
      activeQuestCount: activeQuests.length,
      trailCount: trails.length,
      focusQuestTitle: focusQuest?.title,
      latestTrailTitle: latestTrail?.title,
      guidance: _buildGuidance(focusQuest, latestTrail, activeQuests.length),
    );
  }

  static String _buildGuidance(
    Quest? focusQuest,
    Trail? latestTrail,
    int activeQuestCount,
  ) {
    if (focusQuest != null && latestTrail != null) {
      return '「${focusQuest.title}」の航路は、最新のTrail「${latestTrail.title}」につながっているよ。次は小さなMissionをひとつ選ぼう。';
    }

    if (focusQuest != null) {
      return '今いちばん輪郭が見えているQuestは「${focusQuest.title}」。次の一歩を進めたら、Trailとして旅の記録に残そう。';
    }

    if (latestTrail != null) {
      return '最新のTrail「${latestTrail.title}」は次の星の手がかりになりそう。準備ができたら、新しいQuestへつなげよう。';
    }

    if (activeQuestCount == 0) {
      return '今は静かな出発点にいるね。まずQuestをひとつ置けば、次のMissionを一緒に形にできるよ。';
    }

    return 'QuestとTrailの流れを見ながら、今日記録できる小さなMissionを一緒に探そう。';
  }
}
