class MissionPlanQuality {
  const MissionPlanQuality({
    required this.score,
    required this.generationVersion,
    required this.criticPasses,
    required this.repairedMissionCount,
    required this.generatedAt,
  });

  final double score;
  final String generationVersion;
  final int criticPasses;
  final int repairedMissionCount;
  final DateTime generatedAt;

  Map<String, Object?> toJson() => {
    'score': score.clamp(0, 1),
    'generation_version': generationVersion,
    'critic_passes': criticPasses.clamp(0, 2),
    'repaired_mission_count': repairedMissionCount.clamp(0, 30),
    'generated_at': generatedAt.toUtc().toIso8601String(),
  };

  static MissionPlanQuality? fromJson(Object? value) {
    if (value is! Map) return null;
    final data = Map<String, dynamic>.from(value);
    final generatedAt = DateTime.tryParse(
      data['generated_at'] as String? ?? '',
    );
    final score = (data['score'] as num?)?.toDouble();
    if (generatedAt == null || score == null) return null;
    return MissionPlanQuality(
      score: score.clamp(0, 1),
      generationVersion:
          data['generation_version'] as String? ?? 'quest_guide_v3',
      criticPasses: ((data['critic_passes'] as num?)?.round() ?? 0).clamp(0, 2),
      repairedMissionCount:
          ((data['repaired_mission_count'] as num?)?.round() ?? 0).clamp(0, 30),
      generatedAt: generatedAt,
    );
  }
}
