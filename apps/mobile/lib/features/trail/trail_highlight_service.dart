import '../media/media_model.dart';
import 'trail_model.dart';

class TrailHighlight {
  const TrailHighlight({
    required this.trailId,
    required this.score,
    required this.reason,
    required this.isStarMemoryCandidate,
  });

  final String trailId;
  final int score;
  final String reason;
  final bool isStarMemoryCandidate;
}

class TrailHighlightService {
  const TrailHighlightService();

  List<TrailHighlight> rank({
    required List<Trail> trails,
    required Map<String, MediaAttachment> attachments,
  }) {
    final highlights =
        trails
            .map(
              (trail) => _scoreTrail(
                trail,
                hasMedia: attachments.containsKey(trail.id),
              ),
            )
            .where((highlight) => highlight.score >= 45)
            .toList(growable: false)
          ..sort((a, b) => b.score.compareTo(a.score));
    return highlights;
  }

  TrailHighlight _scoreTrail(Trail trail, {required bool hasMedia}) {
    var score = 0;
    final reasons = <String>[];

    if (trail.trailType == TrailType.arcReflection) {
      score += 35;
      reasons.add('Arc Reflection');
    }
    if (trail.questId != null) {
      score += 15;
      reasons.add('Quest連携');
    }
    if (trail.missionId != null) {
      score += 15;
      reasons.add('Mission連携');
    }
    if (hasMedia) {
      score += 20;
      reasons.add('画像つき');
    }
    if (trail.content.length >= 120) {
      score += 20;
      reasons.add('深い記録');
    } else if (trail.content.length >= 60) {
      score += 10;
      reasons.add('十分な記録');
    }

    final reason = reasons.isEmpty
        ? 'まだ静かなTrailです'
        : '${reasons.join(' / ')} があるため、あとで見返す価値が高いTrailです。';

    return TrailHighlight(
      trailId: trail.id,
      score: score.clamp(0, 100),
      reason: reason,
      isStarMemoryCandidate: score >= 70,
    );
  }
}
