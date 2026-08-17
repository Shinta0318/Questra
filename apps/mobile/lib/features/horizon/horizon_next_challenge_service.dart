import '../arc/navigator_rank_service.dart';
import '../challenge_graph/challenge_graph_preview_service.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

enum HorizonDestination { arc, mission, trail }

class HorizonNextChallenge {
  const HorizonNextChallenge({
    required this.title,
    required this.category,
    required this.reason,
    required this.readinessLabel,
    required this.suggestedAction,
    required this.destination,
    this.questId,
    this.missionId,
  });

  final String title;
  final String category;
  final String reason;
  final String readinessLabel;
  final String suggestedAction;
  final HorizonDestination destination;
  final String? questId;
  final String? missionId;
}

class HorizonNextChallengeService {
  const HorizonNextChallengeService();

  HorizonNextChallenge suggest({
    required NavigatorRankState rank,
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    List<ChallengeGraphInsight> graphInsights = const [],
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

    if (quests.isEmpty) {
      return const HorizonNextChallenge(
        title: 'Arcと最初のQuestを見つける',
        category: 'はじめの航路',
        readinessLabel: 'はじめの一歩',
        reason: '叶えたいことをArcに話すと、目指す状態を一緒に整理できます。',
        suggestedAction: 'Arcに話す',
        destination: HorizonDestination.arc,
      );
    }

    final activeQuest = activeQuests.firstOrNull;
    final nextMission = activeQuest == null
        ? null
        : (missions
                  .where(
                    (mission) =>
                        mission.questId == activeQuest.id &&
                        mission.status == MissionStatus.todo &&
                        mission.routeState == MissionRouteState.active,
                  )
                  .toList()
                ..sort((a, b) {
                  if (a.isToday != b.isToday) return a.isToday ? -1 : 1;
                  final order = a.orderIndex.compareTo(b.orderIndex);
                  return order != 0
                      ? order
                      : a.sortOrder.compareTo(b.sortOrder);
                }))
              .firstOrNull;
    if (activeQuest != null && nextMission != null) {
      return HorizonNextChallenge(
        title: nextMission.title,
        category: activeQuest.title,
        readinessLabel: '次のMission',
        reason: '進行中の「${activeQuest.title}」を前へ進める、現在の航路です。',
        suggestedAction: 'Missionを開く',
        destination: HorizonDestination.mission,
        questId: activeQuest.id,
        missionId: nextMission.id,
      );
    }

    final graphInsight = graphInsights.firstOrNull;
    if (graphInsight != null &&
        activeQuests.isNotEmpty &&
        completedQuests.isEmpty) {
      return HorizonNextChallenge(
        title: graphInsight.title,
        category: 'Challenge Graph',
        readinessLabel: '航路の提案',
        reason: graphInsight.message,
        suggestedAction: 'ArcとMissionを考える',
        destination: HorizonDestination.arc,
        questId: activeQuest?.id,
      );
    }

    if (activeQuest != null) {
      return HorizonNextChallenge(
        title: '「${activeQuest.title}」の次のMissionを考える',
        category: activeQuest.category,
        readinessLabel: '航路を準備',
        reason: '進行中のQuestに、次に取り組めるMissionがまだありません。',
        suggestedAction: 'Arcに相談する',
        destination: HorizonDestination.arc,
        questId: activeQuest.id,
      );
    }

    if (completedQuests.isNotEmpty || rank.rank == NavigatorRank.navigator) {
      final category = completedQuests.isEmpty
          ? activeQuests.firstOrNull?.category ?? '挑戦'
          : completedQuests.first.category;
      return HorizonNextChallenge(
        title: '$categoryを広げる次のQuest',
        category: category,
        readinessLabel: '次のQuest候補',
        reason: '完了した航路があります。今の勢いを、少し広い挑戦へつなげられます。',
        suggestedAction: 'Arcと次を考える',
        destination: HorizonDestination.arc,
      );
    }

    if (completedMissions >= 3 ||
        reflections >= 1 ||
        rank.rank == NavigatorRank.stargazer) {
      return const HorizonNextChallenge(
        title: 'Trailから見つける次のQuest',
        category: 'Reflection',
        readinessLabel: 'Trailから発見',
        reason: 'MissionやTrailが育っています。記録の中から次の挑戦の種を選べます。',
        suggestedAction: '最近のTrailを見る',
        destination: HorizonDestination.trail,
      );
    }

    final quest = activeQuests.firstOrNull;
    return HorizonNextChallenge(
      title: '${quest?.title ?? '今のQuest'}を一段進める',
      category: quest?.category ?? '冒険',
      readinessLabel: '次の一歩',
      reason: '進行中のQuestがあります。新しい挑戦より、まず今の航路を一段だけ進めましょう。',
      suggestedAction: 'Arcに相談する',
      destination: HorizonDestination.arc,
    );
  }
}
