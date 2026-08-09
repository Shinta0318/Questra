import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';

void main() {
  test('legacy progress-only Mission completion APIs are removed', () {
    final source = File(
      'lib/features/mission/mission_controller.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('void updateProgress(')));
    expect(source, isNot(contains('Mission? completeMission(')));
  });

  test('100 percent progress cannot bypass required Task completion', () {
    final container = ProviderContainer(
      overrides: [
        missionControllerProvider.overrideWith(Qst272MissionController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(missionControllerProvider.notifier);

    controller.applyTaskProgress(
      'mission-qst272',
      progressPercent: 100,
      allRequiredTasksCompleted: true,
    );
    expect(
      controller.confirmMissionSuccess(
        'mission-qst272',
        allRequiredTasksCompleted: false,
      ),
      isFalse,
    );
    expect(
      container.read(missionControllerProvider).single.status,
      MissionStatus.todo,
    );
  });

  test('Mission completes after Task completion and outcome confirmation', () {
    final container = ProviderContainer(
      overrides: [
        missionControllerProvider.overrideWith(Qst272MissionController.new),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(missionControllerProvider.notifier);

    controller.applyTaskProgress(
      'mission-qst272',
      progressPercent: 100,
      allRequiredTasksCompleted: true,
    );
    expect(
      controller.confirmMissionSuccess(
        'mission-qst272',
        allRequiredTasksCompleted: true,
      ),
      isTrue,
    );
    final completed = container.read(missionControllerProvider).single;
    expect(completed.status, MissionStatus.completed);
    expect(completed.successConfirmedAt, isNotNull);
  });
}

class Qst272MissionController extends MissionController {
  @override
  List<Mission> build() => [
    Mission(
      id: 'mission-qst272',
      questId: 'quest-qst272',
      questTitle: 'QST-272 Quest',
      title: '検証可能な成果を整える',
      description: 'Task完了後に成果を確認する',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.easy,
      status: MissionStatus.todo,
      hierarchyRole: 'outcome',
      successCondition: '必要な成果を確認できる',
      expectedOutcome: '成果が利用できる',
    ),
  ];
}
