import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/core/performance/grouped_collection_index.dart';
import 'package:questra/core/performance/performance_limits.dart';

void main() {
  test('long route index scans each Task once and serves grouped lookups', () {
    final tasks = List.generate(
      12000,
      (index) => _FixtureTask('mission-${index % 80}', index),
      growable: false,
    );
    GroupedCollectionIndex<String, _FixtureTask>.build(
      tasks,
      keyOf: (task) => task.missionId,
    );

    final samples = <int>[];
    late GroupedCollectionIndex<String, _FixtureTask> index;
    for (var run = 0; run < 5; run += 1) {
      var visitedThisRun = 0;
      final watch = Stopwatch()..start();
      index = GroupedCollectionIndex<String, _FixtureTask>.build(
        tasks.map((task) {
          visitedThisRun += 1;
          return task;
        }),
        keyOf: (task) => task.missionId,
      );
      watch.stop();
      expect(visitedThisRun, 12000);
      samples.add(watch.elapsedMilliseconds);
    }
    samples.sort();
    final medianBuildMilliseconds = samples[samples.length ~/ 2];

    expect(index.itemCount, 12000);
    expect(index.groupCount, 80);
    expect(index.valuesFor('mission-4'), hasLength(150));
    expect(
      medianBuildMilliseconds,
      lessThan(QuestraPerformanceLimits.longRouteIndexBuildBudgetMs),
      reason:
          '12,000 Task fixture index exceeded the median host regression budget: $samples',
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
