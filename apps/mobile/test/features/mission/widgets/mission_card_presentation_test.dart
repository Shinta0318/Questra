import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/widgets/mission_card_presentation.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  Mission mission({
    MissionStatus status = MissionStatus.todo,
    List<String> dependencies = const [],
    int progress = 0,
  }) => Mission(
    id: 'mission-1',
    questId: 'quest-1',
    questTitle: '旅に出る',
    title: '旅程を決める',
    description: '旅程が確定している',
    guideType: GuideType.route,
    difficulty: MissionDifficulty.easy,
    status: status,
    progressPercent: progress,
    dependencyIds: dependencies,
  );

  QuestraTask task(String id, TaskStatus status, {int order = 0}) =>
      QuestraTask(
        id: id,
        questId: 'quest-1',
        missionId: 'mission-1',
        title: 'Task $id',
        action: '具体的な行動をする',
        doneCondition: '結果を確認できる',
        status: status,
        orderIndex: order,
      );

  test('必須Taskの完了数から進捗を計算する', () {
    final state = MissionCardPresentation.resolve(
      mission: mission(progress: 90),
      tasks: [
        task('1', TaskStatus.completed),
        task('2', TaskStatus.ready, order: 1),
      ],
      completedMissionIds: const {},
    );

    expect(state.completedTasks, 1);
    expect(state.totalTasks, 2);
    expect(state.progress, 0.5);
    expect(state.primaryAction, MissionCardPrimaryAction.startNextTask);
    expect(state.primaryLabel, '次のTaskを始める');
  });

  test('進行中Taskがあれば続きからを優先する', () {
    final state = MissionCardPresentation.resolve(
      mission: mission(),
      tasks: [
        task('1', TaskStatus.ready),
        task('2', TaskStatus.inProgress, order: 1),
      ],
      completedMissionIds: const {},
    );

    expect(state.nextTask?.id, '2');
    expect(state.primaryAction, MissionCardPrimaryAction.resumeTask);
  });

  test('未完了の前提Missionがあれば前提確認を表示する', () {
    final state = MissionCardPresentation.resolve(
      mission: mission(dependencies: const ['mission-0']),
      tasks: [task('1', TaskStatus.ready)],
      completedMissionIds: const {},
    );

    expect(state.primaryAction, MissionCardPrimaryAction.viewDependencies);
    expect(state.statusLabel, '前提待ち');
  });

  test('全必須Task完了後は完了内容へ誘導する', () {
    final state = MissionCardPresentation.resolve(
      mission: mission(),
      tasks: [task('1', TaskStatus.completed)],
      completedMissionIds: const {},
    );

    expect(state.progress, 1);
    expect(state.primaryAction, MissionCardPrimaryAction.viewCompleted);
  });

  test('Task未作成時だけMission進捗へフォールバックする', () {
    final state = MissionCardPresentation.resolve(
      mission: mission(progress: 40),
      tasks: const [],
      completedMissionIds: const {},
    );

    expect(state.progress, 0.4);
    expect(state.primaryAction, MissionCardPrimaryAction.viewTasks);
  });
}
