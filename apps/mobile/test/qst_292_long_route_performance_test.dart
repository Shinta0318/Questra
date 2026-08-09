import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/grouped_collection_index.dart';
import 'package:questra/core/performance/performance_limits.dart';

void main() {
  test('long route index scans each Task once and serves grouped lookups', () {
    var visited = 0;
    final tasks = Iterable.generate(12000, (index) {
      visited += 1;
      return _FixtureTask('mission-${index % 80}', index);
    });
    final watch = Stopwatch()..start();

    final index = GroupedCollectionIndex<String, _FixtureTask>.build(
      tasks,
      keyOf: (task) => task.missionId,
    );
    final buildMilliseconds = watch.elapsedMilliseconds;

    expect(visited, 12000);
    expect(index.itemCount, 12000);
    expect(index.groupCount, 80);
    expect(index.valuesFor('mission-4'), hasLength(150));
    expect(visited, 12000, reason: 'group lookup must not rescan the source');
    expect(
      buildMilliseconds,
      lessThan(QuestraPerformanceLimits.longRouteIndexBuildBudgetMs),
      reason: '12,000 Task fixture index exceeded the host regression budget',
    );
  });

  test(
    'repository and Quest detail keep long route reads and builds bounded',
    () {
      final repository = File(
        'lib/features/task/task_repository.dart',
      ).readAsStringSync();
      final detail = File(
        'lib/features/quest/quest_detail_screen.dart',
      ).readAsStringSync();

      expect(repository, contains('QuestraPerformanceLimits.taskListLimit'));
      expect(
        repository,
        contains('QuestraPerformanceLimits.taskPerMissionListLimit'),
      );
      expect(
        detail,
        contains('QuestraPerformanceLimits.questDetailMissionPreviewLimit'),
      );
      expect(detail, contains('GroupedCollectionIndex<String, QuestraTask>'));
    },
  );
}

class _FixtureTask {
  const _FixtureTask(this.missionId, this.order);

  final String missionId;
  final int order;
}
