import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../trail/trail_model.dart';

final arcBondGrowthServiceProvider = Provider<ArcBondGrowthService>(
  (ref) => const ArcBondGrowthService(),
);

enum ArcBondGrowthEvent {
  questCreated,
  questUpdated,
  missionCreated,
  missionCompleted,
  trailPosted,
  trailReflection,
  arcConversation,
}

class ArcBondGrowthResult {
  const ArcBondGrowthResult({
    required this.event,
    required this.delta,
    required this.reason,
  });

  final ArcBondGrowthEvent event;
  final int delta;
  final String reason;
}

class ArcBondGrowthService {
  const ArcBondGrowthService();

  static const maxBondScore = 100;

  ArcBondGrowthResult forQuest(ArcMemorySourceType sourceType) {
    return switch (sourceType) {
      ArcMemorySourceType.questCreated => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.questCreated,
        delta: 5,
        reason: 'Questを星図に灯した',
      ),
      ArcMemorySourceType.questUpdated => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.questUpdated,
        delta: 1,
        reason: 'Questの航路を整えた',
      ),
      _ => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.questUpdated,
        delta: 0,
        reason: 'Quest外のイベント',
      ),
    };
  }

  ArcBondGrowthResult forMission(ArcMemorySourceType sourceType) {
    return switch (sourceType) {
      ArcMemorySourceType.missionCreated => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.missionCreated,
        delta: 2,
        reason: 'Missionを小さな一歩にした',
      ),
      ArcMemorySourceType.missionCompleted => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.missionCompleted,
        delta: 4,
        reason: 'Missionを完了してTrailへつないだ',
      ),
      _ => const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.missionCreated,
        delta: 0,
        reason: 'Mission外のイベント',
      ),
    };
  }

  ArcBondGrowthResult forTrail(Trail trail) {
    if (trail.trailType == TrailType.arcReflection) {
      return const ArcBondGrowthResult(
        event: ArcBondGrowthEvent.trailReflection,
        delta: 5,
        reason: 'Trailを振り返って学びを残した',
      );
    }
    return const ArcBondGrowthResult(
      event: ArcBondGrowthEvent.trailPosted,
      delta: 3,
      reason: 'Trailを残して航路を記録した',
    );
  }

  ArcBondGrowthResult forArcConversation() {
    return const ArcBondGrowthResult(
      event: ArcBondGrowthEvent.arcConversation,
      delta: 1,
      reason: 'Arcと航路を相談した',
    );
  }

  int apply({required int currentScore, required int delta}) {
    return (currentScore + delta).clamp(0, maxBondScore);
  }
}
