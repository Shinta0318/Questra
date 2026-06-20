import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_expression_engine.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/widgets/arc/arc_asset_paths.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  const engine = ArcExpressionEngine();

  test('resolves an empty journey to a lonely Arc expression', () {
    final decision = engine.resolveJourney(
      quests: const [],
      missions: const [],
      trails: const [],
    );

    expect(decision.emotion, ArcEmotion.lonely);
    expect(decision.assetPath, ArcAssetPaths.lonely);
  });

  test('resolves strong Quest progress to a happy Arc expression', () {
    final decision = engine.resolve(
      ArcExpressionContext(
        quest: Quest(
          title: 'Launch the first Arc path',
          description: 'Prepare the next journey layer.',
          difficulty: QuestDifficulty.normal,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
          progress: 0.9,
        ),
      ),
    );

    expect(decision.emotion, ArcEmotion.excited);
    expect(decision.assetPath, ArcAssetPaths.excited);
  });

  test('resolves overdue active Quest to a concerned Arc expression', () {
    final decision = engine.resolve(
      ArcExpressionContext(
        quest: Quest(
          title: 'Return to training',
          description: 'Pick up the stalled practice loop.',
          difficulty: QuestDifficulty.hard,
          status: QuestStatus.active,
          visibility: QuestVisibility.private,
          progress: 0.2,
          targetDate: DateTime(2026),
        ),
        now: DateTime(2026, 6, 19),
      ),
    );

    expect(decision.emotion, ArcEmotion.worried);
    expect(decision.assetPath, ArcAssetPaths.worried);
  });

  test('resolves Mission focus to a cheering support expression', () {
    final decision = engine.resolve(
      ArcExpressionContext(
        mission: Mission(
          questId: 'quest-1',
          questTitle: 'Quest',
          title: 'Take the next small step',
          description: 'Move today.',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          status: MissionStatus.todo,
        ),
      ),
    );

    expect(decision.emotion, ArcEmotion.support);
    expect(decision.assetPath, ArcAssetPaths.support);
  });

  test('resolves Reflection context to support expression', () {
    final reflection = Trail(
      title: 'Reflection',
      summary: 'Learned one thing.',
      content: 'Next Mission is visible.',
      trailType: TrailType.arcReflection,
    );

    final decision = engine.resolve(
      ArcExpressionContext(
        trail: reflection,
        reflection: reflection,
        moment: ArcExpressionMoment.trailReflection,
      ),
    );

    expect(decision.emotion, ArcEmotion.support);
    expect(decision.reason, 'reflection context');
  });

  test('resolves high Bond to celebration expression', () {
    final decision = engine.resolve(
      const ArcExpressionContext(
        bondScore: 90,
        moment: ArcExpressionMoment.bondGrowth,
      ),
    );

    expect(decision.emotion, ArcEmotion.celebrate);
    expect(decision.assetPath, ArcAssetPaths.celebrate);
  });
}
