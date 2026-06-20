import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../trail/trail_model.dart';

final stardustServiceProvider = Provider<StardustService>(
  (ref) => const StardustService(),
);

enum StardustEvent {
  questCreated,
  missionCreated,
  missionCompleted,
  trailPosted,
  trailReflection,
  arcConversation,
}

class StardustAward {
  const StardustAward({
    required this.event,
    required this.amount,
    required this.reason,
  });

  final StardustEvent event;
  final int amount;
  final String reason;
}

class StardustState {
  const StardustState({
    required this.balance,
    required this.label,
    required this.description,
  });

  final int balance;
  final String label;
  final String description;
}

class StardustService {
  const StardustService();

  StardustState resolve(int balance) {
    final safeBalance = balance < 0 ? 0 : balance;
    return StardustState(
      balance: safeBalance,
      label: safeBalance >= 100 ? '星屑の航路' : '集まりはじめた星屑',
      description: safeBalance == 0
          ? 'QuestやTrailを進めると、活動のしるしとしてStardustが少しずつ集まります。'
          : 'Stardustは、あなたが航路に残した行動のしるしです。',
    );
  }

  StardustAward forQuest(ArcMemorySourceType sourceType) {
    if (sourceType == ArcMemorySourceType.questCreated) {
      return const StardustAward(
        event: StardustEvent.questCreated,
        amount: 10,
        reason: 'Questを始めた',
      );
    }
    return const StardustAward(
      event: StardustEvent.questCreated,
      amount: 0,
      reason: 'Quest更新ではStardustを増やさない',
    );
  }

  StardustAward forMission(ArcMemorySourceType sourceType) {
    return switch (sourceType) {
      ArcMemorySourceType.missionCreated => const StardustAward(
        event: StardustEvent.missionCreated,
        amount: 3,
        reason: 'Missionを作った',
      ),
      ArcMemorySourceType.missionCompleted => const StardustAward(
        event: StardustEvent.missionCompleted,
        amount: 8,
        reason: 'Missionを完了した',
      ),
      _ => const StardustAward(
        event: StardustEvent.missionCreated,
        amount: 0,
        reason: 'Mission外のイベント',
      ),
    };
  }

  StardustAward forTrail(Trail trail) {
    if (trail.trailType == TrailType.arcReflection) {
      return const StardustAward(
        event: StardustEvent.trailReflection,
        amount: 10,
        reason: 'Trailを振り返った',
      );
    }
    return const StardustAward(
      event: StardustEvent.trailPosted,
      amount: 6,
      reason: 'Trailを残した',
    );
  }

  StardustAward forArcConversation() {
    return const StardustAward(
      event: StardustEvent.arcConversation,
      amount: 1,
      reason: 'Arcと相談した',
    );
  }
}
