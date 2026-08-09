import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_progress_service.dart';

void main() {
  const service = TaskProgressService();

  test('Mission progress is derived from required Tasks only', () {
    final snapshot = service.forMission([
      _task('a', status: TaskStatus.completed),
      _task('b'),
      _task('optional', required: false),
    ]);

    expect(snapshot.completed, 1);
    expect(snapshot.total, 2);
    expect(snapshot.percent, 50);
    expect(snapshot.allRequiredCompleted, isFalse);
  });

  test('today recommendation respects dependencies and available time', () {
    final tasks = [
      _task('done', status: TaskStatus.completed),
      _task('too-long', dependencies: const ['done'], minutes: 90),
      _task('ready', dependencies: const ['done'], minutes: 20),
      _task('blocked', dependencies: const ['missing'], minutes: 5),
    ];

    expect(service.recommendToday(tasks, availableMinutes: 30)?.id, 'ready');
  });

  test('no Task cannot complete a Mission', () {
    final snapshot = service.forMission(const []);

    expect(snapshot.percent, 0);
    expect(snapshot.allRequiredCompleted, isFalse);
  });

  test('optional-only Tasks allow outcome review without blocking', () {
    final snapshot = service.forMission([_task('optional', required: false)]);

    expect(snapshot.hasOptionalTasksOnly, isTrue);
    expect(snapshot.percent, 100);
    expect(snapshot.allRequiredCompleted, isTrue);
  });
}

QuestraTask _task(
  String id, {
  TaskStatus status = TaskStatus.pending,
  bool required = true,
  List<String> dependencies = const [],
  int? minutes,
}) => QuestraTask(
  id: id,
  questId: 'quest-1',
  missionId: 'mission-1',
  title: 'Task $id',
  action: '具体的な行動を実行する',
  doneCondition: '実行結果を確認できる',
  status: status,
  required: required,
  dependencyIds: dependencies,
  estimatedEffortMinutes: minutes,
);
