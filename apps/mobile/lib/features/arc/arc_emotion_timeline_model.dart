import 'package:uuid/uuid.dart';

import '../../widgets/arc/arc_emotion.dart';

const _uuid = Uuid();

enum ArcEmotionSourceType {
  questCreated,
  questUpdated,
  missionCreated,
  missionCompleted,
  trailPosted,
  reflectionAdded,
  arcChat,
  concern,
  unauthenticated,
  saveFailure,
}

class ArcEmotionEvent {
  ArcEmotionEvent({
    String? id,
    required this.emotion,
    required this.sourceType,
    required this.reason,
    this.sourceId,
    this.questId,
    this.missionId,
    this.trailId,
    DateTime? createdAt,
  }) : id = id ?? _uuid.v4(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final ArcEmotion emotion;
  final ArcEmotionSourceType sourceType;
  final String reason;
  final String? sourceId;
  final String? questId;
  final String? missionId;
  final String? trailId;
  final DateTime createdAt;
}

extension ArcEmotionSourceTypeStorage on ArcEmotionSourceType {
  String get storageKey {
    return switch (this) {
      ArcEmotionSourceType.questCreated => 'quest_created',
      ArcEmotionSourceType.questUpdated => 'quest_updated',
      ArcEmotionSourceType.missionCreated => 'mission_created',
      ArcEmotionSourceType.missionCompleted => 'mission_completed',
      ArcEmotionSourceType.trailPosted => 'trail_posted',
      ArcEmotionSourceType.reflectionAdded => 'reflection_added',
      ArcEmotionSourceType.arcChat => 'arc_chat',
      ArcEmotionSourceType.concern => 'concern',
      ArcEmotionSourceType.unauthenticated => 'unauthenticated',
      ArcEmotionSourceType.saveFailure => 'save_failure',
    };
  }

  String get label {
    return switch (this) {
      ArcEmotionSourceType.questCreated => 'Quest開始',
      ArcEmotionSourceType.questUpdated => 'Quest更新',
      ArcEmotionSourceType.missionCreated => 'Mission作成',
      ArcEmotionSourceType.missionCompleted => 'Mission達成',
      ArcEmotionSourceType.trailPosted => 'Trail記録',
      ArcEmotionSourceType.reflectionAdded => 'Reflection',
      ArcEmotionSourceType.arcChat => 'Arc Chat',
      ArcEmotionSourceType.concern => '気がかり',
      ArcEmotionSourceType.unauthenticated => '未ログイン',
      ArcEmotionSourceType.saveFailure => '保存失敗',
    };
  }
}

ArcEmotionSourceType arcEmotionSourceTypeFromStorage(String value) {
  return ArcEmotionSourceType.values.firstWhere(
    (sourceType) => sourceType.storageKey == value,
    orElse: () => ArcEmotionSourceType.arcChat,
  );
}

ArcEmotion arcEmotionFromStorage(String value) {
  return ArcEmotion.values.firstWhere(
    (emotion) => emotion.name == value,
    orElse: () => ArcEmotion.normal,
  );
}
