import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/gentle_recovery_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test('recovery avoids failure framing and offers a five minute step', () {
    final mission = Mission(
      questId: 'q',
      questTitle: 'Quest',
      title: '練習する',
      description: '記録したら完了です。',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
    );
    final suggestion = GentleRecoveryService.suggest(
      mission: mission,
      inactiveDays: 20,
    );
    expect(suggestion.question, isNot(contains('失敗')));
    expect(suggestion.actions, contains(GentleRecoveryAction.fiveMinuteStep));
  });
}
