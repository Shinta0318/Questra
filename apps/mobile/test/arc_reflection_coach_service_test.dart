import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/arc/arc_reflection_coach_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/trail/trail_model.dart';
import 'package:questra/widgets/arc/arc_emotion.dart';

void main() {
  const service = ArcReflectionCoachService();

  test('builds Mission-aware reflection prompts', () {
    final mission = Mission(
      questId: 'quest-1',
      questTitle: 'Questraをローンチする',
      title: 'LPを10分見直す',
      description: '小さく改善する',
      guideType: GuideType.training,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    );
    final trail = Trail(
      missionId: mission.id,
      title: 'Mission完了',
      summary: 'LPを見直した',
      content: '改善点を見つけた',
      trailType: TrailType.missionRecord,
    );

    final coach = service.build(trail: trail, mission: mission);

    expect(coach.message, contains(mission.title));
    expect(coach.learningPrompt, contains('Mission'));
    expect(coach.nextMissionPrompt, contains('10分'));
    expect(coach.emotion, ArcEmotion.celebrate);
  });

  test('builds manual Trail prompts without Mission context', () {
    final trail = Trail(
      title: '朝の気づき',
      summary: '少し前進した',
      content: '考えがまとまった',
      trailType: TrailType.manualNote,
    );

    final coach = service.build(trail: trail);

    expect(coach.message, contains('気づき'));
    expect(coach.nextMissionPrompt, contains('小さな行動'));
    expect(coach.emotion, ArcEmotion.normal);
  });
}
