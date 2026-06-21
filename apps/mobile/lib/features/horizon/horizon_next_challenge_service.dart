import '../arc/navigator_rank_service.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

class HorizonNextChallenge {
  const HorizonNextChallenge({
    required this.title,
    required this.category,
    required this.reason,
    required this.readinessLabel,
    required this.suggestedAction,
  });

  final String title;
  final String category;
  final String reason;
  final String readinessLabel;
  final String suggestedAction;
}

class HorizonNextChallengeService {
  const HorizonNextChallengeService();

  HorizonNextChallenge suggest({
    required NavigatorRankState rank,
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
  }) {
    final completedQuests = quests
        .where((quest) => quest.status == QuestStatus.completed)
        .toList(growable: false);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    final completedMissions = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .length;
    final reflections = trails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .length;

    if (quests.isEmpty || rank.rank == NavigatorRank.novice) {
      return const HorizonNextChallenge(
        title: '7日で終わる小さなQuest',
        category: 'はじめの航路',
        readinessLabel: 'Low readiness',
        reason: 'まずは短く終わるQuestで、Arcと一緒に成功の感覚を作りましょう。',
        suggestedAction: '今日できる目的地を1つだけ書く',
      );
    }

    if (completedQuests.isNotEmpty || rank.rank == NavigatorRank.navigator) {
      final category = completedQuests.isEmpty
          ? activeQuests.firstOrNull?.category ?? '挑戦'
          : completedQuests.first.category;
      return HorizonNextChallenge(
        title: '$categoryを広げる次のQuest',
        category: category,
        readinessLabel: 'High readiness',
        reason: '完了した航路があります。今の勢いを、少し広い挑戦へつなげられます。',
        suggestedAction: '前回より少しだけ大きい到達点を決める',
      );
    }

    if (completedMissions >= 3 ||
        reflections >= 1 ||
        rank.rank == NavigatorRank.stargazer) {
      return const HorizonNextChallenge(
        title: 'Trailから見つける次のQuest',
        category: 'Reflection',
        readinessLabel: 'Medium readiness',
        reason: 'MissionやTrailが育っています。記録の中から次の挑戦の種を選べます。',
        suggestedAction: '最近のTrailを1つ開いて、次のテーマを抜き出す',
      );
    }

    final quest = activeQuests.firstOrNull;
    return HorizonNextChallenge(
      title: '${quest?.title ?? '今のQuest'}を一段進める',
      category: quest?.category ?? '冒険',
      readinessLabel: 'Medium readiness',
      reason: '進行中のQuestがあります。新しい挑戦より、まず今の航路を一段だけ進めましょう。',
      suggestedAction: '未完了Missionを1つ完了する',
    );
  }
}
