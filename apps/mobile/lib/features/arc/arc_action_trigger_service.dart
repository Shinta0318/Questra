import '../../widgets/arc/arc_emotion.dart';
import 'arc_emotion_timeline_model.dart';

enum ArcActionTrigger {
  questCreated,
  questUpdated,
  missionCreated,
  missionCompleted,
  trailPosted,
  reflectionAdded,
  arcChatResponded,
  unauthenticated,
  saveFailure,
  inactiveConcern,
}

class ArcActionDecision {
  const ArcActionDecision({
    required this.emotion,
    required this.sourceType,
    required this.message,
  });

  final ArcEmotion emotion;
  final ArcEmotionSourceType sourceType;
  final String message;
}

class ArcActionTriggerService {
  const ArcActionTriggerService();

  ArcActionDecision resolve({
    required ArcActionTrigger trigger,
    String? questTitle,
    String? missionTitle,
    String? trailTitle,
    String? surface,
  }) {
    return switch (trigger) {
      ArcActionTrigger.questCreated => ArcActionDecision(
        emotion: ArcEmotion.excited,
        sourceType: ArcEmotionSourceType.questCreated,
        message: '新しいQuest「${_value(questTitle, 'このQuest')}」が星図に加わりました。',
      ),
      ArcActionTrigger.questUpdated => ArcActionDecision(
        emotion: ArcEmotion.support,
        sourceType: ArcEmotionSourceType.questUpdated,
        message: 'Quest「${_value(questTitle, 'このQuest')}」の航路が更新されました。',
      ),
      ArcActionTrigger.missionCreated => ArcActionDecision(
        emotion: ArcEmotion.support,
        sourceType: ArcEmotionSourceType.missionCreated,
        message: 'Mission「${_value(missionTitle, '次の一歩')}」が航路に加わりました。',
      ),
      ArcActionTrigger.missionCompleted => ArcActionDecision(
        emotion: ArcEmotion.celebrate,
        sourceType: ArcEmotionSourceType.missionCompleted,
        message: 'Mission「${_value(missionTitle, '今日の一歩')}」を達成しました。',
      ),
      ArcActionTrigger.trailPosted => ArcActionDecision(
        emotion: ArcEmotion.celebrate,
        sourceType: ArcEmotionSourceType.trailPosted,
        message: 'Trail「${_value(trailTitle, '今日の記録')}」が航路に残りました。',
      ),
      ArcActionTrigger.reflectionAdded => ArcActionDecision(
        emotion: ArcEmotion.support,
        sourceType: ArcEmotionSourceType.reflectionAdded,
        message: 'Trail「${_value(trailTitle, '振り返り')}」から、次の星の手がかりが見つかりました。',
      ),
      ArcActionTrigger.arcChatResponded => const ArcActionDecision(
        emotion: ArcEmotion.support,
        sourceType: ArcEmotionSourceType.arcChat,
        message: 'Arc Chatで今日の航路を一緒に読みました。',
      ),
      ArcActionTrigger.unauthenticated => ArcActionDecision(
        emotion: ArcEmotion.worried,
        sourceType: ArcEmotionSourceType.unauthenticated,
        message: '${_value(surface, 'この操作')}にはログインが必要でした。',
      ),
      ArcActionTrigger.saveFailure => ArcActionDecision(
        emotion: ArcEmotion.worried,
        sourceType: ArcEmotionSourceType.saveFailure,
        message: '${_value(surface, '保存')}で星図が少し揺れました。少し時間を置いて、もう一度試しましょう。',
      ),
      ArcActionTrigger.inactiveConcern => const ArcActionDecision(
        emotion: ArcEmotion.worried,
        sourceType: ArcEmotionSourceType.concern,
        message: '航路が少し静かです。今日は記録できる一歩だけ選びましょう。',
      ),
    };
  }

  String _value(String? value, String fallback) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return fallback;
    }
    return trimmed;
  }
}
