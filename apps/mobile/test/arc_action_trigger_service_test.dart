import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_action_trigger_service.dart';
import 'package:questra/features/arc/arc_emotion_timeline_model.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  const service = ArcActionTriggerService();

  test('maps Quest creation to excited Arc copy', () {
    final decision = service.resolve(
      trigger: ArcActionTrigger.questCreated,
      questTitle: '富士山に登る',
    );

    expect(decision.emotion, ArcEmotion.excited);
    expect(decision.sourceType, ArcEmotionSourceType.questCreated);
    expect(decision.message, contains('富士山に登る'));
  });

  test('maps Mission completion to celebration', () {
    final decision = service.resolve(
      trigger: ArcActionTrigger.missionCompleted,
      missionTitle: '登山靴を買う',
    );

    expect(decision.emotion, ArcEmotion.celebrate);
    expect(decision.sourceType, ArcEmotionSourceType.missionCompleted);
    expect(decision.message, contains('達成'));
  });

  test('handles unauthenticated and save failure gently', () {
    final unauthenticated = service.resolve(
      trigger: ArcActionTrigger.unauthenticated,
      surface: 'Quest保存',
    );
    final failure = service.resolve(
      trigger: ArcActionTrigger.saveFailure,
      surface: 'Trail保存',
    );

    expect(unauthenticated.emotion, ArcEmotion.worried);
    expect(unauthenticated.message, contains('ログイン'));
    expect(failure.sourceType, ArcEmotionSourceType.saveFailure);
    expect(failure.message, contains('もう一度'));
  });

  test('maps reflection to supportive Trail copy', () {
    final decision = service.resolve(
      trigger: ArcActionTrigger.reflectionAdded,
      trailTitle: '朝の振り返り',
    );

    expect(decision.emotion, ArcEmotion.support);
    expect(decision.sourceType, ArcEmotionSourceType.reflectionAdded);
    expect(decision.message, contains('次の星'));
  });
}
