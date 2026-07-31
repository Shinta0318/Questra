import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_regeneration_intent.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test('completed Mission cannot enter regeneration flow', () {
    final mission = Mission(
      questId: 'quest',
      questTitle: 'Quest',
      title: '確認する',
      description: '記録したら完了です。',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    );
    final request = MissionRegenerationRequest(
      mission: mission,
      intent: MissionRegenerationIntent.smaller,
    );
    expect(request.canRegenerate, isFalse);
  });
}
