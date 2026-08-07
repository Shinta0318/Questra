class QuestEvaluation {
  const QuestEvaluation({
    required this.difficultyScore,
    required this.estimatedDurationDays,
    required this.estimatedMissionCount,
    required this.version,
    required this.evaluatedAt,
    this.estimatedCostLabel,
    this.riskSummary = '',
    this.successLikelihood,
    this.recommendedStartDate,
    this.confidence,
    this.rationale = '',
  });

  final int difficultyScore;
  final int estimatedDurationDays;
  final int estimatedMissionCount;
  final String? estimatedCostLabel;
  final String riskSummary;
  final double? successLikelihood;
  final DateTime? recommendedStartDate;
  final String version;
  final double? confidence;
  final DateTime evaluatedAt;
  final String rationale;

  String get difficultyStars {
    final score = difficultyScore.clamp(1, 5);
    return '${List.filled(score, '★').join()}'
        '${List.filled(5 - score, '☆').join()}';
  }

  String get durationLabel {
    if (estimatedDurationDays < 14) return '約$estimatedDurationDays日';
    if (estimatedDurationDays < 60) {
      return '約${(estimatedDurationDays / 7).ceil()}週間';
    }
    return '約${(estimatedDurationDays / 30).ceil()}ヶ月';
  }

  Map<String, Object?> toJson() => {
    'difficulty_score': difficultyScore,
    'estimated_duration_days': estimatedDurationDays,
    'estimated_mission_count': estimatedMissionCount,
    'estimated_cost': estimatedCostLabel,
    'risk_summary': riskSummary,
    'estimated_success_rate': successLikelihood,
    'recommended_start_date': recommendedStartDate?.toIso8601String(),
    'evaluation_version': version,
    'confidence': confidence,
    'evaluated_at': evaluatedAt.toIso8601String(),
    'rationale': rationale,
  };

  static QuestEvaluation? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final difficulty = (json['difficulty_score'] as num?)?.toInt();
    final duration = (json['estimated_duration_days'] as num?)?.toInt();
    final count = (json['estimated_mission_count'] as num?)?.toInt();
    if (difficulty == null || duration == null || count == null) return null;
    return QuestEvaluation(
      difficultyScore: difficulty.clamp(1, 5),
      estimatedDurationDays: duration.clamp(1, 36500),
      estimatedMissionCount: count.clamp(3, 30),
      estimatedCostLabel: json['estimated_cost'] as String?,
      riskSummary: json['risk_summary'] as String? ?? '',
      successLikelihood: (json['estimated_success_rate'] as num?)
          ?.toDouble()
          .clamp(0, 1),
      recommendedStartDate: _date(json['recommended_start_date']),
      version: json['evaluation_version'] as String? ?? 'local-v1',
      confidence: (json['confidence'] as num?)?.toDouble().clamp(0, 1),
      evaluatedAt: _date(json['evaluated_at']) ?? DateTime.now(),
      rationale: json['rationale'] as String? ?? '',
    );
  }

  static DateTime? _date(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}
