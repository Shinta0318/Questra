import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'quest_clarification_service.dart';

enum QuestType {
  achievement,
  experience,
  travel,
  learning,
  habit,
  career,
  financial,
  creation,
  healthFitness,
  relationship,
  purchase,
  event,
  exploration,
  other,
}

extension QuestTypeStorage on QuestType {
  String get storageKey => switch (this) {
    QuestType.healthFitness => 'health_fitness',
    _ => name,
  };

  String get displayLabel => switch (this) {
    QuestType.achievement => '達成',
    QuestType.experience => '体験',
    QuestType.travel => '旅行',
    QuestType.learning => '学び',
    QuestType.habit => '習慣',
    QuestType.career => 'キャリア',
    QuestType.financial => 'お金',
    QuestType.creation => '創作',
    QuestType.healthFitness => '健康・運動',
    QuestType.relationship => '人とのつながり',
    QuestType.purchase => '購入',
    QuestType.event => 'イベント',
    QuestType.exploration => '探索',
    QuestType.other => 'その他',
  };
}

enum QuestIntentClarity { clear, needsClarification, multipleDirections }

class QuestDirection {
  const QuestDirection({
    required this.title,
    required this.successCondition,
    required this.rationale,
  });

  final String title;
  final String successCondition;
  final String rationale;
}

class QuestIntentResolution {
  const QuestIntentResolution({
    required this.originalWish,
    required this.questType,
    required this.clarity,
    required this.optimizedTitle,
    required this.summary,
    required this.successCondition,
    required this.clarificationQuestions,
    required this.directions,
    required this.sourceType,
  });

  final String originalWish;
  final QuestType questType;
  final QuestIntentClarity clarity;
  final String optimizedTitle;
  final String summary;
  final String successCondition;
  final List<QuestClarificationQuestion> clarificationQuestions;
  final List<QuestDirection> directions;
  final String sourceType;
}

final questIntentResolutionServiceProvider =
    Provider<QuestIntentResolutionService>((ref) {
      if (SupabaseConfig.isConfigured) {
        return SupabaseQuestIntentResolutionService(Supabase.instance.client);
      }
      return const LocalQuestIntentResolutionService();
    });

abstract interface class QuestIntentResolutionService {
  Future<QuestIntentResolution> resolve({
    required String wish,
    DateTime? targetDate,
  });
}

class LocalQuestIntentResolutionService
    implements QuestIntentResolutionService {
  const LocalQuestIntentResolutionService();

  @override
  Future<QuestIntentResolution> resolve({
    required String wish,
    DateTime? targetDate,
  }) async {
    final input = wish.trim();
    final type = classifyQuestType(input);
    final questions = QuestClarificationService.resolve(
      input: input,
      category: type.storageKey,
      targetDate: targetDate,
    );
    return QuestIntentResolution(
      originalWish: input,
      questType: type,
      clarity: questions.isEmpty
          ? QuestIntentClarity.clear
          : QuestIntentClarity.needsClarification,
      optimizedTitle: input,
      summary: questions.isEmpty
          ? '叶えたい状態と達成条件を、この内容から整理できます。'
          : '航路を決める前に、${questions.length}つだけ確認したいことがあります。',
      successCondition: '',
      clarificationQuestions: questions,
      directions: const [],
      sourceType: 'local_semantic_intent',
    );
  }
}

class SupabaseQuestIntentResolutionService
    implements QuestIntentResolutionService {
  const SupabaseQuestIntentResolutionService(this.client);

  final SupabaseClient client;

  @override
  Future<QuestIntentResolution> resolve({
    required String wish,
    DateTime? targetDate,
  }) async {
    final response = await client.functions.invoke(
      'arc-quest-guide',
      body: {
        'mode': 'quest_intent',
        'wish': wish,
        'target_date': targetDate?.toIso8601String(),
      },
    );
    if (response.status < 200 ||
        response.status >= 300 ||
        response.data is! Map) {
      throw const QuestIntentUnavailableException();
    }
    final data = Map<String, dynamic>.from(response.data as Map);
    final type = _questType(data['quest_type']);
    final clarity = _clarity(data['clarity']);
    final questions = (data['clarification_questions'] as List? ?? const [])
        .whereType<Map>()
        .map(QuestClarificationQuestion.fromJson)
        .whereType<QuestClarificationQuestion>()
        .take(3)
        .toList(growable: false);
    final directions = (data['directions'] as List? ?? const [])
        .whereType<Map>()
        .map((value) {
          final item = Map<String, dynamic>.from(value);
          final title = (item['title'] as String?)?.trim() ?? '';
          final success = (item['success_condition'] as String?)?.trim() ?? '';
          if (title.isEmpty || success.isEmpty) return null;
          return QuestDirection(
            title: title,
            successCondition: success,
            rationale: (item['rationale'] as String?)?.trim() ?? '',
          );
        })
        .whereType<QuestDirection>()
        .where((direction) => !_looksTemplateGenerated(wish, direction.title))
        .take(3)
        .toList(growable: false);
    if (clarity == QuestIntentClarity.multipleDirections &&
        directions.length < 2) {
      throw const QuestIntentUnavailableException();
    }
    return QuestIntentResolution(
      originalWish: wish.trim(),
      questType: type,
      clarity: clarity,
      optimizedTitle:
          (data['optimized_title'] as String?)?.trim().isNotEmpty == true
          ? (data['optimized_title'] as String).trim()
          : wish.trim(),
      summary: (data['summary'] as String?)?.trim() ?? '',
      successCondition: (data['success_condition'] as String?)?.trim() ?? '',
      clarificationQuestions: questions,
      directions: directions,
      sourceType: (data['source_type'] as String?) ?? 'gemini_quest_intent',
    );
  }

  static QuestType _questType(Object? value) => QuestType.values.firstWhere(
    (type) => type.storageKey == value,
    orElse: () => QuestType.other,
  );

  static QuestIntentClarity _clarity(Object? value) => switch (value) {
    'needs_clarification' => QuestIntentClarity.needsClarification,
    'multiple_directions' => QuestIntentClarity.multipleDirections,
    _ => QuestIntentClarity.clear,
  };
}

class QuestIntentUnavailableException implements Exception {
  const QuestIntentUnavailableException();

  @override
  String toString() =>
      'ArcがQuestを整理できませんでした。入力は残っています。もう一度試すか、内容を少し具体的にしてください。';
}

QuestType classifyQuestType(String wish) {
  final source = wish.toLowerCase();
  if (_containsAny(source, const [
    '旅行',
    '旅',
    '海外',
    '観光',
    '登山',
    'キャンプ',
    '行きたい',
  ])) {
    return QuestType.travel;
  }
  if (_containsAny(source, const ['毎日', '毎朝', '毎週', '習慣', '継続'])) {
    return QuestType.habit;
  }
  if (_containsAny(source, const ['英語', '学習', '勉強', '資格', '習得'])) {
    return QuestType.learning;
  }
  if (_containsAny(source, const ['転職', '就職', '昇進', '仕事', 'キャリア'])) {
    return QuestType.career;
  }
  if (_containsAny(source, const ['貯金', '投資', '収入', '返済'])) {
    return QuestType.financial;
  }
  if (_containsAny(source, const ['作る', '制作', '執筆', '開発', '出版'])) {
    return QuestType.creation;
  }
  if (_containsAny(source, const ['健康', '運動', '走る', '筋トレ', '減量'])) {
    return QuestType.healthFitness;
  }
  if (_containsAny(source, const ['家族', '友人', 'パートナー', '関係'])) {
    return QuestType.relationship;
  }
  if (_containsAny(source, const ['買う', '購入', '手に入れる'])) {
    return QuestType.purchase;
  }
  if (_containsAny(source, const ['開催', '参加', '大会', 'イベント'])) {
    return QuestType.event;
  }
  if (_containsAny(source, const ['体験', '経験', '見たい'])) {
    return QuestType.experience;
  }
  return QuestType.other;
}

bool _containsAny(String source, List<String> values) =>
    values.any(source.contains);

bool _looksTemplateGenerated(String wish, String title) {
  final normalizedWish = wish.trim();
  if (!title.startsWith(normalizedWish)) return false;
  return const [
    'を小さく試す',
    'を習慣にする',
    'に本格的に取り組む',
    'に挑戦する',
    'を達成する',
  ].any(title.endsWith);
}
