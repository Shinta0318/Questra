import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/progressive_route_reveal_service.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test(
    'route reveal keeps one today step and limits immediate next actions',
    () {
      final route = List.generate(
        7,
        (index) => ArcMissionCandidate(
          title: 'Mission $index',
          description: '記録したら完了です。',
          guideType: GuideType.route,
          difficulty: MissionDifficulty.easy,
          priority: index == 3
              ? MissionPriority.critical
              : MissionPriority.normal,
        ),
      );
      final reveal = ProgressiveRouteRevealService.organize(route);
      expect(reveal.today!.title, 'Mission 3');
      expect(reveal.next, hasLength(3));
      expect(reveal.future, hasLength(3));
    },
  );

  test('blocked high priority Mission is not revealed as today', () {
    const route = [
      ArcMissionCandidate(
        planKey: 'root',
        title: '条件を確認する',
        description: '条件を記録したら完了です。',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
      ),
      ArcMissionCandidate(
        planKey: 'blocked',
        title: '申請する',
        description: '申請したら完了です。',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.normal,
        priority: MissionPriority.critical,
        dependencyPlanKeys: ['root'],
      ),
    ];

    final reveal = ProgressiveRouteRevealService.organize(route);

    expect(reveal.today!.planKey, 'root');
    expect(reveal.next.single.planKey, 'blocked');
  });
}
