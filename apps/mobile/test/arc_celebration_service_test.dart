import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_celebration_service.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  const service = ArcCelebrationService();

  test('builds a Mission completion celebration', () {
    final moment = service.build(
      event: ArcCelebrationEvent.missionCompleted,
      subject: '朝の準備',
    );

    expect(moment.emotion, ArcEmotion.celebrate);
    expect(moment.title, 'Mission達成');
    expect(moment.message, contains('朝の準備'));
    expect(moment.reason, 'celebration event');
  });

  test('builds a Trail reflection celebration', () {
    final moment = service.build(
      event: ArcCelebrationEvent.trailReflection,
      subject: '最初のTrail',
    );

    expect(moment.emotion, ArcEmotion.celebrate);
    expect(moment.title, 'Reflection保存');
    expect(moment.message, contains('次のMission'));
  });

  test('builds a Quest progress celebration', () {
    final moment = service.build(
      event: ArcCelebrationEvent.questProgress,
      subject: 'Arc体験を磨く',
    );

    expect(moment.emotion, ArcEmotion.celebrate);
    expect(moment.title, 'Quest進行中');
    expect(moment.message, contains('Arc体験を磨く'));
  });
}
