import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_journey_context.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';

void main() {
  test('builds guidance from active Quest and latest Trail', () {
    final context = ArcJourneyContext.fromJourney(
      quests: [_quest(title: 'Betaへ進む', progress: 0.6)],
      trails: [
        Trail(
          title: '朝の前進',
          summary: '一歩進んだ',
          content: '次のMissionが見えた',
          trailType: TrailType.manualNote,
          createdAt: DateTime(2026, 6, 20),
        ),
      ],
    );

    expect(context.focusQuestTitle, 'Betaへ進む');
    expect(context.latestTrailTitle, '朝の前進');
    expect(context.guidance, contains('最新のTrail'));
    expect(context.guidance, contains('小さなMission'));
  });

  test('uses Quest-first guidance without Trail context', () {
    final context = ArcJourneyContext.fromJourney(
      quests: [_quest(title: 'Arcを磨く', progress: 0.4)],
      trails: const [],
    );

    expect(context.guidance, contains('Quest'));
    expect(context.guidance, contains('Trail'));
  });

  test('uses quiet start guidance for empty journeys', () {
    final context = ArcJourneyContext.fromJourney(
      quests: const [],
      trails: const [],
    );

    expect(context.guidance, contains('Quest'));
    expect(context.guidance, contains('Mission'));
  });
}

Quest _quest({required String title, required double progress}) {
  return Quest(
    title: title,
    description: '航路を進める',
    difficulty: QuestDifficulty.normal,
    status: QuestStatus.active,
    visibility: QuestVisibility.private,
    progress: progress,
  );
}
