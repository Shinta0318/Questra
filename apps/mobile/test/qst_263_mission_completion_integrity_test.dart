import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test(
    'Mission confirmation can be cleared when required Task is reopened',
    () {
      final confirmed = Mission(
        id: 'mission-1',
        questId: 'quest-1',
        questTitle: '旅に出る',
        title: '旅程を決める',
        description: '旅程を確定する',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
        status: MissionStatus.completed,
        progressPercent: 100,
        successConfirmedAt: DateTime(2026, 8, 8),
      );

      final rolledBack = confirmed.copyWith(
        status: MissionStatus.todo,
        progressPercent: 50,
        clearSuccessConfirmedAt: true,
      );

      expect(rolledBack.status, MissionStatus.todo);
      expect(rolledBack.progressPercent, 50);
      expect(rolledBack.successConfirmedAt, isNull);
    },
  );
}
