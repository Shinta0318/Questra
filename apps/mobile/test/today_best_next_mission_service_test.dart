import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/today_best_next_mission_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/core/estimation/effort_estimate.dart';

Mission mission(
  String id, {
  List<String> dependencies = const [],
  MissionPriority priority = MissionPriority.normal,
  bool today = false,
  MissionStatus status = MissionStatus.todo,
  int? effortMinutes,
}) => Mission(
  id: id,
  questId: 'q',
  questTitle: 'Quest',
  title: id,
  description: '記録したら完了です。',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: status,
  dependencyIds: dependencies,
  priority: priority,
  isToday: today,
  effortEstimate: effortMinutes == null
      ? null
      : EffortEstimate(
          difficultyBand: '標準',
          activeEffortMinutes: effortMinutes,
          calendarDays: 1,
          confidence: 0.8,
          rationale: 'テスト',
        ),
);

void main() {
  test('today recommendation honors dependencies before priority', () {
    final recommendation = TodayBestNextMissionService.recommend([
      mission(
        'blocked',
        dependencies: const ['done'],
        priority: MissionPriority.critical,
      ),
      mission('available', priority: MissionPriority.high),
    ]);
    expect(recommendation!.mission.id, 'available');
  });

  test('today recommendation prefers an action that fits available time', () {
    final recommendation = TodayBestNextMissionService.recommend([
      mission('long', priority: MissionPriority.critical, effortMinutes: 120),
      mission('short', priority: MissionPriority.high, effortMinutes: 30),
    ], availableMinutes: 30);
    expect(recommendation!.mission.id, 'short');
    expect(recommendation.reason, contains('30分'));
  });

  test('no mission is pushed on an explicitly unavailable day', () {
    expect(
      TodayBestNextMissionService.recommend([
        mission('candidate'),
      ], availableMinutes: 0),
      isNull,
    );
  });

  test('choose another excludes the current recommendation', () {
    final recommendation = TodayBestNextMissionService.recommend(
      [mission('first'), mission('second')],
      excludedMissionIds: const {'first'},
    );
    expect(recommendation!.mission.id, 'second');
  });

  test(
    'five minute mode keeps the selected mission and softens the wording',
    () {
      final recommendation = TodayBestNextMissionService.recommend([
        mission('small-step', effortMinutes: 60),
      ], fiveMinuteMissionId: 'small-step');
      expect(recommendation!.mission.id, 'small-step');
      expect(recommendation.reason, contains('5分だけ'));
    },
  );
}
