class SegmentCandidate {
  const SegmentCandidate({
    required this.dimensions,
    required this.cohortSize,
    required this.sensitive,
  });
  final Map<String, Object?> dimensions;
  final int cohortSize;
  final bool sensitive;
}

class PrivacySafeSegmentService {
  const PrivacySafeSegmentService({this.minimumCohortSize = 10});
  final int minimumCohortSize;
  static const allowedDimensions = {
    'quest_category',
    'quest_theme',
    'quest_stage',
    'target_period_band',
    'budget_band',
    'location_scope',
    'experience_level',
    'support_need',
    'commercial_intent',
    'progress_band',
    'completion_rate',
  };
  Map<String, Object?>? publish(SegmentCandidate candidate) {
    if (candidate.sensitive || candidate.cohortSize < minimumCohortSize) {
      return null;
    }
    final dimensions = <String, Object?>{
      for (final entry in candidate.dimensions.entries)
        if (allowedDimensions.contains(entry.key)) entry.key: entry.value,
    };
    if (dimensions.isEmpty) {
      return null;
    }
    return {'dimensions': dimensions, 'cohort_size': candidate.cohortSize};
  }
}
