import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../arc_memory/arc_memory_model.dart';
import '../trail/trail_model.dart';

final stardustServiceProvider = Provider<StardustService>(
  (ref) => const StardustService(),
);

enum StardustEvent {
  questCreated,
  missionStarted,
  missionCompleted,
  taskCompleted,
  trailPosted,
  trailReflection,
  questCompleted,
}

extension StardustEventStorage on StardustEvent {
  String get storageKey => switch (this) {
    StardustEvent.questCreated => 'quest_created',
    StardustEvent.missionStarted => 'mission_started',
    StardustEvent.missionCompleted => 'mission_completed',
    StardustEvent.taskCompleted => 'task_completed',
    StardustEvent.trailPosted => 'trail_recorded',
    StardustEvent.trailReflection => 'trail_reflection_recorded',
    StardustEvent.questCompleted => 'quest_completed',
  };
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
        amount: 5,
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
        event: StardustEvent.missionStarted,
        amount: 0,
        reason: 'Mission作成だけではStardustを増やさない',
      ),
      ArcMemorySourceType.missionCompleted => const StardustAward(
        event: StardustEvent.missionCompleted,
        amount: 10,
        reason: 'Missionを完了した',
      ),
      _ => const StardustAward(
        event: StardustEvent.missionStarted,
        amount: 0,
        reason: 'Mission外のイベント',
      ),
    };
  }

  StardustAward forTrail(Trail trail) {
    if (trail.trailType == TrailType.arcReflection) {
      return const StardustAward(
        event: StardustEvent.trailReflection,
        amount: 3,
        reason: 'Trailを振り返った',
      );
    }
    return const StardustAward(
      event: StardustEvent.trailPosted,
      amount: 3,
      reason: 'Trailを残した',
    );
  }

  StardustAward forTaskCompletion() {
    return const StardustAward(
      event: StardustEvent.taskCompleted,
      amount: 2,
      reason: 'Taskを完了した',
    );
  }
}
