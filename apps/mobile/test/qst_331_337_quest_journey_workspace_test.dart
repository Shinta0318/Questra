import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/quest_journey/quest_journey_contract.dart';
import 'package:questra/features/quest_journey/quest_journey_quality_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  group('QST-331 outcome progress contract', () {
    test('Task count cannot inflate Quest progress', () {
      final missions = [
        _mission('m1', status: MissionStatus.completed, weight: 1),
        _mission('m2', weight: 3),
      ];
      final snapshot = const QuestJourneyProgressService().calculate(missions);

      expect(snapshot.completedMissions, 1);
      expect(snapshot.totalMissions, 2);
      expect(snapshot.percent, 25);
    });
  });

  group('QST-334 Focus selection', () {
    test('returns at most three dependency-ready Tasks', () {
      final missions = [_mission('m1'), _mission('m2', order: 2)];
      final tasks = [
        _task('done', 'm1', status: TaskStatus.completed, order: 0),
        _task('doing', 'm1', status: TaskStatus.inProgress, order: 1),
        _task('next', 'm1', dependencies: const ['done'], order: 2),
        _task('blocked', 'm1', dependencies: const ['missing'], order: 3),
        _task('later', 'm2', status: TaskStatus.deferred, order: 0),
        _task('third', 'm2', order: 1),
        _task('fourth', 'm2', order: 2),
      ];

      final selected = const QuestFocusSelectionService().select(
        tasks: tasks,
        missions: missions,
      );

      expect(selected.map((task) => task.id), ['doing', 'next', 'third']);
    });
  });

  group('QST-335 partial replanning quality', () {
    test('repairs only failed unfinished Tasks in the selected Mission', () {
      final tasks = [
        _task('keep-complete', 'm1', status: TaskStatus.completed),
        _task('repair', 'm1'),
        _task('sibling', 'm2'),
      ];

      final repairable = const QuestJourneyQualityService().repairableTaskIds(
        missionId: 'm1',
        tasks: tasks,
        failedTaskIds: const ['keep-complete', 'repair', 'sibling'],
      );

      expect(repairable, {'repair'});
    });

    test('detects duplicate Tasks and dependency cycles', () {
      final tasks = [
        _task('a', 'm1', title: '候補を比較する', dependencies: const ['b']),
        _task('b', 'm1', title: '候補を比較します', dependencies: const ['a']),
      ];

      final issues = const QuestJourneyQualityService().inspect(
        missions: [],
        tasks: tasks,
      );

      expect(
        issues.any(
          (issue) => issue.code == JourneyQualityIssueCode.duplicateTask,
        ),
        isTrue,
      );
      expect(
        issues.any(
          (issue) => issue.code == JourneyQualityIssueCode.dependencyCycle,
        ),
        isTrue,
      );
    });
  });

  test('QST-336 maps Arc generation to an explicit origin', () {
    final task = _task('arc', 'm1', generatedBy: TaskGeneratedBy.arc);
    expect(task.origin, TaskOrigin.arcSuggestion);
    expect(task.origin.label, 'Arcから追加');
  });
}

Mission _mission(
  String id, {
  MissionStatus status = MissionStatus.todo,
  int order = 0,
  double weight = 1,
}) =>
    Mission(
      id: id,
      questId: 'q1',
      questTitle: 'Quest',
      title: 'Mission $id',
      description: '中間成果を作る',
      guideType: GuideType.route,
      difficulty: MissionDifficulty.normal,
      status: status,
      orderIndex: order,
      sortOrder: order,
      weight: weight,
      successCondition: '成果を確認できたら完了',
    );

QuestraTask _task(
  String id,
  String missionId, {
  String title = 'Task',
  TaskStatus status = TaskStatus.pending,
  List<String> dependencies = const [],
  int order = 0,
  TaskGeneratedBy generatedBy = TaskGeneratedBy.user,
}) =>
    QuestraTask(
      id: id,
      questId: 'q1',
      missionId: missionId,
      title: title,
      action: title,
      doneCondition: '実行を確認したら完了',
      status: status,
      dependencyIds: dependencies,
      orderIndex: order,
      generatedBy: generatedBy,
    );
