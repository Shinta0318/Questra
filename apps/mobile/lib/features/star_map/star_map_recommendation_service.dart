import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_highlight_service.dart';
import '../trail/trail_model.dart';

class StarMapRecommendation {
  const StarMapRecommendation({
    required this.title,
    required this.category,
    required this.score,
    required this.reason,
    required this.sourceType,
  });

  final String title;
  final String category;
  final int score;
  final String reason;
  final String sourceType;
}

class StarMapRecommendationService {
  const StarMapRecommendationService();

  List<StarMapRecommendation> recommend({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    required List<TrailHighlight> highlights,
  }) {
    final completedQuests = quests
        .where((quest) => quest.status == QuestStatus.completed)
        .toList(growable: false);
    final activeQuests = quests
        .where((quest) => quest.status == QuestStatus.active)
        .toList(growable: false);
    final completedMissions = missions
        .where((mission) => mission.status == MissionStatus.completed)
        .toList(growable: false);
    final reflections = trails
        .where((trail) => trail.trailType == TrailType.arcReflection)
        .toList(growable: false);

    final candidates = <StarMapRecommendation>[];

    if (quests.isEmpty) {
      candidates.add(
        const StarMapRecommendation(
          title: '最初のQuestを星図に置く',
          category: '冒険',
          score: 80,
          reason: 'まだQuestがありません。小さな目的地をひとつ置くと、Star Mapが動き始めます。',
          sourceType: 'empty_journey',
        ),
      );
    }

    for (final quest in activeQuests) {
      final relatedMissions = missions
          .where((mission) => mission.questId == quest.id)
          .toList(growable: false);
      final openCount = relatedMissions
          .where((mission) => mission.status == MissionStatus.todo)
          .length;
      if (quest.progress < 0.35 || openCount == 0) {
        candidates.add(
          StarMapRecommendation(
            title: '${quest.title}の次のMissionを作る',
            category: quest.category,
            score: 64 + (openCount == 0 ? 10 : 0),
            reason: '進行中のQuestに、次の小さな一歩を足すと航路が続きます。',
            sourceType: 'active_quest_gap',
          ),
        );
      }
    }

    if (completedMissions.length >= 3 && reflections.isEmpty) {
      candidates.add(
        const StarMapRecommendation(
          title: '最近のMissionをTrailで振り返る',
          category: 'Reflection',
          score: 70,
          reason: 'Missionの完了が増えています。Trailに学びを残すと次のQuest候補が見えやすくなります。',
          sourceType: 'mission_reflection_gap',
        ),
      );
    }

    if (highlights.isNotEmpty) {
      candidates.add(
        StarMapRecommendation(
          title: 'Star Memoryから次のQuestを探す',
          category: 'Star Map',
          score: 72 + highlights.take(2).length * 6,
          reason: '意味の強いTrailが見つかっています。そこから次の挑戦を選べます。',
          sourceType: 'trail_highlight',
        ),
      );
    }

    for (final quest in completedQuests.take(2)) {
      candidates.add(
        StarMapRecommendation(
          title: '${quest.category}を少し広げるQuest',
          category: quest.category,
          score: 76,
          reason: '完了したQuest「${quest.title}」の勢いを、隣の挑戦へつなげられます。',
          sourceType: 'completed_quest',
        ),
      );
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.take(5).toList(growable: false);
  }
}
