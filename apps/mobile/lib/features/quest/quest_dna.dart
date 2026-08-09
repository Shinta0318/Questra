import 'quest_intent_resolution_service.dart';
import 'quest_model.dart';

/// Versioned, AI-derived facts used only after explicit Quest creation.
/// Values stay bounded so discovery and support never depend on free-form data.
class QuestDna {
  const QuestDna({
    required this.attributes,
    required this.version,
    required this.evaluatedAt,
    required this.provenance,
  });

  static const keys = <String>[
    'quest_type',
    'category',
    'theme',
    'difficulty',
    'duration',
    'budget',
    'location',
    'season',
    'required_skills',
    'related_interests',
    'risk_level',
    'emotional_weight',
    'life_stage',
    'motivation_type',
    'social_type',
    'monetization_relevance',
    'enterprise_relevance',
  ];

  final Map<String, String> attributes;
  final String version;
  final DateTime evaluatedAt;
  final String provenance;

  String valueFor(String key) => attributes[key] ?? '未評価';

  Map<String, Object?> toJson() => {
    'attributes': attributes,
    'version': version,
    'evaluated_at': evaluatedAt.toIso8601String(),
    'provenance': provenance,
  };

  static QuestDna? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final raw = json['attributes'];
    if (raw is! Map) return null;
    final attributes = <String, String>{
      for (final key in keys)
        key: (raw[key] as String?)?.trim().isNotEmpty == true
            ? (raw[key] as String).trim().substring(
                0,
                (raw[key] as String).trim().length.clamp(0, 120),
              )
            : '未評価',
    };
    return QuestDna(
      attributes: attributes,
      version: (json['version'] as String?)?.trim().isNotEmpty == true
          ? (json['version'] as String).trim()
          : 'quest-dna-v2',
      evaluatedAt:
          DateTime.tryParse(json['evaluated_at'] as String? ?? '') ??
          DateTime.now(),
      provenance: (json['provenance'] as String?)?.trim().isNotEmpty == true
          ? (json['provenance'] as String).trim()
          : 'local_fallback',
    );
  }

  factory QuestDna.fallback(Quest quest) {
    final source = '${quest.title} ${quest.description} ${quest.category}';
    final isTravel = RegExp(r'旅行|移住|登山|海外|留学').hasMatch(source);
    final isLearning = RegExp(r'学習|資格|英語|試験|読書').hasMatch(source);
    final difficulty =
        quest.evaluation?.difficultyScore ??
        switch (quest.difficulty) {
          QuestDifficulty.easy => 1,
          QuestDifficulty.normal => 2,
          QuestDifficulty.hard => 4,
          QuestDifficulty.legendary => 5,
        };
    return QuestDna(
      attributes: {
        'quest_type': classifyQuestType(source).storageKey,
        'category': quest.category,
        'theme': isTravel
            ? '冒険'
            : isLearning
            ? '学び'
            : '人生の航路',
        'difficulty': '$difficulty / 5',
        'duration': quest.evaluation?.durationLabel ?? '未評価',
        'budget': isTravel ? '要見積もり' : '低〜中',
        'location': isTravel ? '目的地に応じる' : '柔軟',
        'season': isTravel ? '時期を確認' : '通年',
        'required_skills': isLearning ? '基礎学習・継続' : '小さな実行・振り返り',
        'related_interests': quest.category,
        'risk_level': quest.evaluation?.riskSummary.isNotEmpty == true
            ? '要確認'
            : '低〜中',
        'emotional_weight': '中',
        'life_stage': '個人の状況に応じる',
        'motivation_type': '成長',
        'social_type': quest.visibility == QuestVisibility.private
            ? '個人'
            : '共有可能',
        'monetization_relevance': '未評価',
        'enterprise_relevance': '必要時に透明な支援を検討',
      },
      version: 'quest-dna-v2',
      evaluatedAt: DateTime.now(),
      provenance: 'local_fallback',
    );
  }
}
