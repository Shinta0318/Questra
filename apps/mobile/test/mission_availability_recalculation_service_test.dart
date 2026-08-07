import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/estimation/effort_estimate.dart';
import 'package:questra/features/mission/mission_availability_recalculation_service.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

Mission sampleMission({MissionStatus status = MissionStatus.todo}) => Mission(
  questId: 'q',
  questTitle: 'Quest',
  title: '具体的な一歩',
  description: '成果を記録する',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: status,
  estimatedDurationDays: 7,
  effortEstimate: const EffortEstimate(
    difficultyBand: '標準',
    activeEffortMinutes: 120,
    calendarDays: 7,
    confidence: 0.8,
    rationale: 'test',
  ),
);

void main() {
  const service = MissionAvailabilityRecalculationService();

  test('recalculates an open Mission from weekly availability', () {
    final updated = service.recalculate(
      sampleMission(),
      previousWeeklyMinutes: 60,
      nextWeeklyMinutes: 120,
    );
    expect(updated.estimatedDurationDays, 7);
  });

  test('never rewrites a completed Mission estimate', () {
    final mission = sampleMission(status: MissionStatus.completed);
    final updated = service.recalculate(
      mission,
      previousWeeklyMinutes: 60,
      nextWeeklyMinutes: 600,
    );
    expect(updated.estimatedDurationDays, mission.estimatedDurationDays);
  });
}
