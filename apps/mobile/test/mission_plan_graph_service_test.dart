import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_plan_graph_service.dart';
import 'package:questra/features/quest/arc_quest_guide_service.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  ArcMissionCandidate candidate(
    String key, {
    String? parent,
    List<String> dependencies = const [],
  }) {
    return ArcMissionCandidate(
      planKey: key,
      title: key,
      description: '$keyができたら完了です。',
      parentPlanKey: parent,
      dependencyPlanKeys: dependencies,
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
    );
  }

  test('removes missing, self, and cyclic graph references', () {
    final result = MissionPlanGraphService.normalize([
      candidate('a', parent: 'b', dependencies: ['missing', 'a']),
      candidate('b', parent: 'a', dependencies: ['c']),
      candidate('c', dependencies: ['b']),
    ]);

    expect(result, hasLength(3));
    expect(result.first.dependencyPlanKeys, isEmpty);
    expect(result[1].parentPlanKey, isNull);
    expect(result[2].dependencyPlanKeys, isEmpty);
  });

  test('keeps a valid parent and dependency chain', () {
    final result = MissionPlanGraphService.normalize([
      candidate('a'),
      candidate('b', parent: 'a', dependencies: ['a']),
      candidate('c', dependencies: ['b']),
    ]);

    expect(result[1].parentPlanKey, 'a');
    expect(result[2].dependencyPlanKeys, ['b']);
  });
}
