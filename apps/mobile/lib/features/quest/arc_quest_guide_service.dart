import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/config/supabase_config.dart';
import '../mission/mission_model.dart';
import 'quest_guide_model.dart';
import 'quest_model.dart';

class ArcMissionCandidate {
  const ArcMissionCandidate({
    required this.title,
    required this.description,
    required this.guideType,
    required this.difficulty,
  });

  final String title;
  final String description;
  final GuideType guideType;
  final MissionDifficulty difficulty;
}

class ArcQuestGuide {
  const ArcQuestGuide({
    required this.questId,
    required this.summary,
    required this.path,
    required this.cautions,
    required this.encouragement,
    required this.missionCandidates,
    required this.sourceType,
  });

  final String questId;
  final String summary;
  final String path;
  final String cautions;
  final String encouragement;
  final List<ArcMissionCandidate> missionCandidates;
  final String sourceType;
}

abstract interface class ArcQuestGuideService {
  Future<ArcQuestGuide> generate({required Quest quest});
}

class LocalArcQuestGuideService implements ArcQuestGuideService {
  const LocalArcQuestGuideService();

  @override
  Future<ArcQuestGuide> generate({required Quest quest}) async {
    return ArcQuestGuide(
      questId: quest.id,
      summary:
          '「${quest.title}」は、${quest.category}の星へ向かう${quest.difficulty.label}Questです。${_descriptionHint(quest)}',
      path:
          'まず目的地を一文で固定し、今日できる小さなMissionを選びます。次にTrailへ気づきを残し、3日ごとに進み方を見直しましょう。',
      cautions:
          '最初から完璧な計画にしすぎないでください。難所はMissionを小さく分け、迷ったらTrailに現在地を書き残すのが安全です。',
      encouragement:
          'キャプテン、このQuestはもう星図に灯っています。最初の一歩は小さくて大丈夫。Arcは航路の変化を一緒に見ています。',
      missionCandidates: [
        ArcMissionCandidate(
          title: '${quest.title}の到達点を一文で書く',
          description: '達成した状態、期限、最初に確認したい基準を短く書き出します。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '${quest.category}で必要な知識を3つ集める',
          description: '分からないことを3つだけ選び、最初に調べる順番を決めます。',
          guideType: GuideType.knowledge,
          difficulty: MissionDifficulty.easy,
        ),
        ArcMissionCandidate(
          title: '10分だけ${quest.title}を進める',
          description: '今すぐできる最小の練習や準備を10分だけ試し、結果をTrailに残します。',
          guideType: GuideType.training,
          difficulty: MissionDifficulty.easy,
        ),
      ],
      sourceType: 'local_arc_quest_guide',
    );
  }

  String _descriptionHint(Quest quest) {
    if (quest.description.trim().isEmpty) {
      return '目的の背景は、これからTrailで少しずつ鮮明にできます。';
    }
    return '背景には「${quest.description.trim()}」があります。';
  }
}

class SupabaseArcQuestGuideService implements ArcQuestGuideService {
  const SupabaseArcQuestGuideService({
    required this.client,
    this.fallback = const LocalArcQuestGuideService(),
  });

  final SupabaseClient client;
  final ArcQuestGuideService fallback;

  @override
  Future<ArcQuestGuide> generate({required Quest quest}) async {
    if (!SupabaseConfig.isConfigured) {
      return fallback.generate(quest: quest);
    }

    try {
      final response = await client.functions.invoke(
        'arc-quest-guide',
        body: {
          'quest': {
            'id': quest.id,
            'title': quest.title,
            'description': quest.description,
            'difficulty': quest.difficulty.storageKey,
            'category': quest.category,
            'target_date': quest.targetDate?.toIso8601String(),
          },
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map);
      final candidates =
          (data['mission_candidates'] as List?)
              ?.map((item) => _candidateFromData(item))
              .whereType<ArcMissionCandidate>()
              .take(6)
              .toList(growable: false) ??
          const [];
      if (candidates.length < 3) {
        return fallback.generate(quest: quest);
      }
      return ArcQuestGuide(
        questId: quest.id,
        summary: data['summary'] as String? ?? 'Questの輪郭を整理しました。',
        path: data['path'] as String? ?? '小さなMissionから航路を作りましょう。',
        cautions: data['cautions'] as String? ?? '無理なく小さく進めましょう。',
        encouragement: data['encouragement'] as String? ?? 'この一歩は、ちゃんと星図に残ります。',
        missionCandidates: candidates,
        sourceType: data['source_type'] as String? ?? 'arc_quest_guide',
      );
    } catch (_) {
      return fallback.generate(quest: quest);
    }
  }

  ArcMissionCandidate? _candidateFromData(Object? item) {
    if (item is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(item);
    final title = data['title'] as String?;
    final description = data['description'] as String?;
    if (title == null || description == null) {
      return null;
    }
    return ArcMissionCandidate(
      title: title,
      description: description,
      guideType: _guideTypeFromValue(data['guide_type'] as String?),
      difficulty: _difficultyFromValue(data['difficulty'] as String?),
    );
  }

  GuideType _guideTypeFromValue(String? value) {
    return GuideType.values.firstWhere(
      (guideType) => guideType.name == value,
      orElse: () => GuideType.route,
    );
  }

  MissionDifficulty _difficultyFromValue(String? value) {
    return MissionDifficulty.values.firstWhere(
      (difficulty) => difficulty.name == value,
      orElse: () => MissionDifficulty.easy,
    );
  }
}
