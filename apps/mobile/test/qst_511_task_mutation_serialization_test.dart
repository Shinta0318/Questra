import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    'same-owner saves are serialized before durable queue replacement',
    () async {
      final repository = _FirstSaveDelayedRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final first = controller.addTask(_task('first'));
      await repository.firstRequested.future;
      final second = controller.addTask(_task('second'));
      await Future<void>.delayed(Duration.zero);

      expect(repository.calls, 1);
      expect((await queue.load('owner-a'))?.desired.single.id, 'first');
      repository.finishFirst();
      await Future.wait([first, second]);

      expect(repository.calls, 2);
      expect(
        container.read(taskControllerProvider).map((task) => task.id),
        containsAll(['first', 'second']),
      );
      expect(await queue.load('owner-a'), isNull);
    },
  );

  test(
    'failed first save retains its retry and rejects queued write',
    () async {
      final repository = _FirstSaveDelayedRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final first = controller.addTask(_task('first'));
      final firstFailure = expectLater(first, throwsStateError);
      await repository.firstRequested.future;
      final second = controller.addTask(_task('second'));
      final secondFailure = expectLater(second, throwsStateError);
      repository.failFirst();

      await Future.wait([firstFailure, secondFailure]);
      expect(repository.calls, 1);
      expect(container.read(taskControllerProvider), isEmpty);
      expect((await queue.load('owner-a'))?.desired.single.id, 'first');
      final mutation = container.read(taskMutationControllerProvider);
      expect(mutation.status, TaskMutationStatus.failed);
      expect(mutation.pending?.desired.single.id, 'first');
      expect(await controller.retryPending(), isTrue);
      expect(await queue.load('owner-a'), isNull);
      await controller.addTask(_task('second'));
      expect(
        container.read(taskControllerProvider).map((task) => task.id),
        containsAll(['first', 'second']),
      );
    },
  );

  test('reorder and later save share the same owner queue', () async {
    final repository = _DelayedReorderRepository();
    final queue = InMemoryTaskOfflineQueueRepository();
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = _task('first');
    final second = _task('second').copyWith(orderIndex: 1);
    await controller.addTasks([first, second]);

    final reorder = controller.reorderMissionTasks('mission-a', [
      second,
      first,
    ]);
    await repository.reorderRequested.future;
    final laterSave = controller.addTask(_task('third'));
    await Future<void>.delayed(Duration.zero);

    expect(repository.saveCalls, 1);
    expect(
      (await queue.load('owner-a'))?.desired.map((task) => task.id),
      containsAll(['first', 'second']),
    );
    repository.finishReorder();
    expect(await reorder, isTrue);
    await laterSave;
    expect(repository.saveCalls, 3);
    expect(container.read(taskControllerProvider).length, 3);
    expect(await queue.load('owner-a'), isNull);
  });
}

ProviderContainer _container(
  TaskRepository repository,
  TaskOfflineQueueRepository queue,
) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_AuthFixture.new),
    taskRepositoryProvider.overrideWithValue(repository),
    taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
  ],
);

QuestraTask _task(String id) => QuestraTask(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: '旅行日程を確認する',
  action: '同行者と旅行日程を確認する',
  doneCondition: '同行者と候補日が一致している',
);

class _AuthFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
}

class _FirstSaveDelayedRepository extends InMemoryTaskRepository {
  final firstRequested = Completer<void>();
  final _releaseFirst = Completer<void>();
  int calls = 0;

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    calls++;
    if (calls == 1) {
      firstRequested.complete();
      await _releaseFirst.future;
    }
    return super.saveAll(tasks);
  }

  void finishFirst() => _releaseFirst.complete();
  void failFirst() => _releaseFirst.completeError(StateError('network failed'));
}

class _DelayedReorderRepository extends InMemoryTaskRepository {
  final reorderRequested = Completer<void>();
  final _releaseReorder = Completer<void>();
  int saveCalls = 0;

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    saveCalls++;
    return super.saveAll(tasks);
  }

  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) async {
    reorderRequested.complete();
    await _releaseReorder.future;
    return super.reorderMissionTasks(
      missionId,
      ordered,
      operationId: operationId,
    );
  }

  void finishReorder() => _releaseReorder.complete();
}
