import '../../widgets/arc/arc_asset_paths.dart';
import '../../widgets/arc/arc_emotion.dart';
import '../../widgets/arc/arc_visual_asset.dart';
import '../mission/mission_model.dart';
import '../quest/quest_model.dart';
import '../trail/trail_model.dart';

enum ArcExpressionMoment {
  idle,
  questFocus,
  missionFocus,
  trailReflection,
  celebration,
  concern,
  empty,
  bondGrowth,
}

class ArcExpressionContext {
  const ArcExpressionContext({
    this.quest,
    this.mission,
    this.trail,
    this.reflection,
    this.bondScore,
    this.moment = ArcExpressionMoment.idle,
    this.now,
  });

  final Quest? quest;
  final Mission? mission;
  final Trail? trail;
  final Trail? reflection;
  final int? bondScore;
  final ArcExpressionMoment moment;
  final DateTime? now;
}

class ArcExpressionDecision {
  const ArcExpressionDecision({
    required this.emotion,
    required this.asset,
    required this.reason,
  });

  final ArcEmotion emotion;
  final ArcVisualAsset asset;
  final String reason;

  String get assetPath => asset.path;
}

class ArcExpressionEngine {
  const ArcExpressionEngine();

  ArcExpressionDecision resolve(ArcExpressionContext context) {
    final emotion = _resolveEmotion(context);
    return ArcExpressionDecision(
      emotion: emotion,
      asset: ArcAssetPaths.assetForEmotion(emotion),
      reason: _reasonFor(context, emotion),
    );
  }

  ArcExpressionDecision resolveJourney({
    required List<Quest> quests,
    required List<Mission> missions,
    required List<Trail> trails,
    int? bondScore,
    DateTime? now,
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

    return resolve(
      ArcExpressionContext(
        quest: activeQuests.firstOrNull,
        mission: openMissions.firstOrNull,
        trail: recentTrails.firstOrNull,
        reflection: reflections.firstOrNull,
        bondScore: bondScore,
        moment: activeQuests.isEmpty && openMissions.isEmpty
            ? ArcExpressionMoment.empty
            : ArcExpressionMoment.questFocus,
        now: now,
      ),
    );
  }

  ArcEmotion _resolveEmotion(ArcExpressionContext context) {
    if (context.moment == ArcExpressionMoment.celebration ||
        context.quest?.status == QuestStatus.completed ||
        context.mission?.status == MissionStatus.completed) {
      return ArcEmotion.celebrate;
    }

    if (context.moment == ArcExpressionMoment.bondGrowth) {
      return _emotionForBond(context.bondScore);
    }

    final reflection = context.reflection;
    final trail = context.trail;
    if (context.moment == ArcExpressionMoment.trailReflection ||
        reflection != null ||
        trail?.trailType == TrailType.arcReflection) {
      return ArcEmotion.support;
    }

    if (context.moment == ArcExpressionMoment.concern ||
        _isQuestStalled(context.quest, context.now)) {
      return ArcEmotion.worried;
    }

    final mission = context.mission;
    if (mission != null) {
      return switch (mission.difficulty) {
        MissionDifficulty.easy => ArcEmotion.support,
        MissionDifficulty.normal => ArcEmotion.serious,
      };
    }

    final quest = context.quest;
    if (quest != null) {
      if (quest.progress >= 0.85) {
        return ArcEmotion.excited;
      }
      if (quest.progress >= 0.45) {
        return ArcEmotion.support;
      }
      return switch (quest.difficulty) {
        QuestDifficulty.easy => ArcEmotion.normal,
        QuestDifficulty.normal => ArcEmotion.serious,
        QuestDifficulty.hard => ArcEmotion.serious,
        QuestDifficulty.legendary => ArcEmotion.excited,
      };
    }

    if (context.moment == ArcExpressionMoment.empty) {
      return ArcEmotion.lonely;
    }

    return _emotionForBond(context.bondScore);
  }

  ArcEmotion _emotionForBond(int? bondScore) {
    if (bondScore == null) {
      return ArcEmotion.normal;
    }
    if (bondScore >= 80) {
      return ArcEmotion.celebrate;
    }
    if (bondScore >= 40) {
      return ArcEmotion.excited;
    }
    if (bondScore <= 5) {
      return ArcEmotion.lonely;
    }
    return ArcEmotion.support;
  }

  bool _isQuestStalled(Quest? quest, DateTime? now) {
    final targetDate = quest?.targetDate;
    if (quest == null ||
        quest.status != QuestStatus.active ||
        targetDate == null ||
        quest.progress >= 1) {
      return false;
    }
    final today = DateTime(
      now?.year ?? DateTime.now().year,
      now?.month ?? DateTime.now().month,
      now?.day ?? DateTime.now().day,
    );
    return targetDate.isBefore(today);
  }

  String _reasonFor(ArcExpressionContext context, ArcEmotion emotion) {
    if (context.moment == ArcExpressionMoment.celebration) {
      return 'celebration event';
    }
    if (context.moment == ArcExpressionMoment.bondGrowth) {
      return 'bond growth signal';
    }
    if (context.reflection != null ||
        context.trail?.trailType == TrailType.arcReflection) {
      return 'reflection context';
    }
    if (emotion == ArcEmotion.worried) {
      return 'concern context';
    }
    if (context.mission != null) {
      return 'mission context';
    }
    if (context.quest != null) {
      return 'quest context';
    }
    if (context.moment == ArcExpressionMoment.empty) {
      return 'empty journey context';
    }
    return 'default Arc presence';
  }
}
