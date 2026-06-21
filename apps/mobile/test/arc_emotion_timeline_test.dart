import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_emotion_timeline_model.dart';
import 'package:questra/features/arc/arc_emotion_timeline_repository.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  test('maps emotion timeline source type storage and labels', () {
    expect(
      arcEmotionSourceTypeFromStorage('mission_completed'),
      ArcEmotionSourceType.missionCompleted,
    );
    expect(ArcEmotionSourceType.trailPosted.label, 'Trail記録');
    expect(arcEmotionFromStorage('celebrate'), ArcEmotion.celebrate);
  });

  test('in-memory repository returns latest events first', () async {
    final repository = InMemoryArcEmotionTimelineRepository();
    final older = ArcEmotionEvent(
      emotion: ArcEmotion.support,
      sourceType: ArcEmotionSourceType.trailPosted,
      reason: 'Trailを残した',
      createdAt: DateTime(2026, 6, 21, 8),
    );
    final newer = ArcEmotionEvent(
      emotion: ArcEmotion.celebrate,
      sourceType: ArcEmotionSourceType.missionCompleted,
      reason: 'Missionを達成した',
      createdAt: DateTime(2026, 6, 21, 9),
    );

    await repository.save(ownerId: 'user-1', event: older);
    await repository.save(ownerId: 'user-1', event: newer);
    await repository.save(
      ownerId: 'user-2',
      event: ArcEmotionEvent(
        emotion: ArcEmotion.worried,
        sourceType: ArcEmotionSourceType.concern,
        reason: '別ユーザー',
      ),
    );

    final events = await repository.findByUser('user-1');

    expect(events, hasLength(2));
    expect(events.first.id, newer.id);
    expect(events.last.id, older.id);
  });

  test('in-memory repository respects limit', () async {
    final repository = InMemoryArcEmotionTimelineRepository();
    for (var index = 0; index < 5; index++) {
      await repository.save(
        ownerId: 'user-1',
        event: ArcEmotionEvent(
          emotion: ArcEmotion.normal,
          sourceType: ArcEmotionSourceType.arcChat,
          reason: 'event $index',
          createdAt: DateTime(2026, 6, 21, 9, index),
        ),
      );
    }

    final events = await repository.findByUser('user-1', limit: 3);

    expect(events, hasLength(3));
    expect(events.first.reason, 'event 4');
  });
}
