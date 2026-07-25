import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/adaptive_route_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest/quest_model.dart';

void main() {
  test('proposes a later target without mutating completed Missions', () {
    final now = DateTime(2026, 7, 25);
    final quest = Quest(
      title: 'Singapore',
      description: '',
      difficulty: QuestDifficulty.normal,
      status: QuestStatus.active,
      visibility: QuestVisibility.private,
      targetDate: DateTime(2026, 7, 30),
    );
    final completed = Mission(
      id: 'done',
      questId: quest.id,
      questTitle: quest.title,
      title: 'Passport',
      description: '',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.completed,
    );
    final pending = Mission(
      id: 'next',
      questId: quest.id,
      questTitle: quest.title,
      title: 'Book',
      description: '',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.normal,
      status: MissionStatus.todo,
      estimatedDurationDays: 20,
    );

    final proposal = AdaptiveRouteService.evaluate(
      quest: quest,
      missions: [completed, pending],
      now: now,
    );

    expect(proposal?.reason, RouteReplanReason.deadlineRisk);
    expect(proposal?.preservedMissionIds, ['done']);
    expect(proposal?.recommendedTargetDate, DateTime(2026, 8, 14));
  });
}
