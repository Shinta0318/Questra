import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/task/task_availability_service.dart';
import 'package:questra/features/task/task_model.dart';

void main() {
  const service = TaskAvailabilityService();

  test('unresolved dependency blocks Task start and completion', () {
    final target = _task('target', dependencies: const ['before']);
    final state = service.evaluate(target, [target]);

    expect(state.canStart, isFalse);
    expect(state.canComplete, isFalse);
    expect(state.blockingDependencyIds, ['before']);
  });

  test('completed dependency unlocks a pending Task', () {
    final before = _task('before', status: TaskStatus.completed);
    final target = _task('target', dependencies: const ['before']);
    final state = service.evaluate(target, [before, target]);

    expect(state.canStart, isTrue);
    expect(state.canComplete, isFalse);
  });

  test('only an in-progress Task can be completed', () {
    final task = _task('target', status: TaskStatus.inProgress);
    final state = service.evaluate(task, [task]);

    expect(state.canStart, isFalse);
    expect(state.canComplete, isTrue);
  });

  test('completed Task can be reopened', () {
    final task = _task('target', status: TaskStatus.completed);
    final state = service.evaluate(task, [task]);

    expect(state.canReopen, isTrue);
  });
}

QuestraTask _task(
  String id, {
  TaskStatus status = TaskStatus.pending,
  List<String> dependencies = const [],
}) => QuestraTask(
  id: id,
  questId: 'quest-1',
  missionId: 'mission-1',
  title: 'Task $id',
  action: '具体的な行動を実行する',
  doneCondition: '実行結果を確認できる',
  status: status,
  dependencyIds: dependencies,
);
