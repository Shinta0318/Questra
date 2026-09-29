import 'trail_model.dart';

class TrailJourneyProjection {
  const TrailJourneyProjection({required this.trails, required this.trailIds});

  final List<Trail> trails;
  final Set<String> trailIds;
}

TrailJourneyProjection projectTrailJourney(
  Iterable<Trail> source, {
  String? questId,
  String? missionId,
}) {
  final trails = <Trail>[];
  final trailIds = <String>{};
  for (final trail in source) {
    if (questId != null && trail.questId != questId) continue;
    if (missionId != null && trail.missionId != missionId) continue;
    trails.add(trail);
    trailIds.add(trail.id);
  }
  return TrailJourneyProjection(
    trails: List.unmodifiable(trails),
    trailIds: Set.unmodifiable(trailIds),
  );
}
