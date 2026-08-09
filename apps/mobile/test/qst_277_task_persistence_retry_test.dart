import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    'failed creation keeps the draft and retries with the same Task id',
    () async {
      final repository = _FlakyTaskRepository(failuresRemaining: 1);
      final container = ProviderContainer(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      final task = _task('task-retry');

      await expectLater(controller.addTask(task), throwsStateError);

      expect(container.read(taskControllerProvider), isEmpty);
      final failed = container.read(taskMutationControllerProvider);
      expect(failed.status, TaskMutationStatus.failed);
      expect(failed.pending?.desired.single.id, task.id);
      expect(failed.canRetry, isTrue);

      expect(await controller.retryPending(), isTrue);

      expect(container.read(taskControllerProvider).single.id, task.id);
      expect(repository.saveCalls, 2);
      expect(repository.persisted.keys, [task.id]);
      expect(
        container.read(taskMutationControllerProvider).status,
        TaskMutationStatus.saved,
      );
    },
  );

  test(
    'failed status update rolls back UI and preserves desired progress',
    () async {
      final repository = _FlakyTaskRepository();
      final container = ProviderContainer(
        overrides: [taskRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await controller.addTask(_task('task-progress'));
      repository.failuresRemaining = 1;

      expect(await controller.start('task-progress'), isFalse);

      expect(
        container.read(taskControllerProvider).single.status,
        TaskStatus.pending,
      );
      expect(
        container
            .read(taskMutationControllerProvider)
            .pending
            ?.desired
            .single
            .status,
        TaskStatus.inProgress,
      );

      expect(await controller.retryPending(), isTrue);
      expect(
        container.read(taskControllerProvider).single.status,
        TaskStatus.inProgress,
      );
    },
  );

  test('network failures are exposed as an offline pending state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final mutation = PendingTaskMutation(
      ownerId: 'local-preview',
      idempotencyKey: 'task-upsert:offline',
      desired: [_task('offline')],
      previous: const [],
    );

    container
        .read(taskMutationControllerProvider.notifier)
        .failed(mutation, StateError('XMLHttpRequest error'));

    final state = container.read(taskMutationControllerProvider);
    expect(state.status, TaskMutationStatus.offlinePending);
    expect(state.message, contains('変更内容は保持'));
  });
}

QuestraTask _task(String id) => QuestraTask(
  id: id,
  questId: 'quest-1',
  missionId: 'mission-1',
  title: '必要な情報を確認する',
  action: '公式情報を一つ確認して要点を記録する',
  doneCondition: '確認元と要点が記録されている',
);

class _FlakyTaskRepository extends InMemoryTaskRepository {
  _FlakyTaskRepository({this.failuresRemaining = 0});

  int failuresRemaining;
  int saveCalls = 0;
  final Map<String, QuestraTask> persisted = {};

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    saveCalls++;
    if (failuresRemaining > 0) {
      failuresRemaining--;
      throw StateError('temporary failure');
    }
    final saved = await super.saveAll(tasks);
    for (final task in saved) {
      persisted[task.id] = task;
    }
    return saved;
  }
}
