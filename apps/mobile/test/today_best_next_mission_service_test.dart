import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/today_best_next_mission_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

Mission mission(
  String id, {
  List<String> dependencies = const [],
  MissionPriority priority = MissionPriority.normal,
  bool today = false,
  MissionStatus status = MissionStatus.todo,
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
}
