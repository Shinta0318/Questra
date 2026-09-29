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
  test('late save success never restores a previous owner Task', () async {
    final repository = _DelayedTaskRepository();
    final queue = InMemoryTaskOfflineQueueRepository();
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final save = controller.addTask(_task('old-task'));
    await repository.requested.future;
    expect(container.read(taskControllerProvider).single.id, 'old-task');

    (container.read(authControllerProvider.notifier)
            as _SwitchableAuthController)
        .setOwner('owner-b');
    expect(container.read(taskControllerProvider), isEmpty);
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.idle,
    );
    await controller.addTask(_task('new-task'));

    repository.finish();
    await expectLater(save, throwsStateError);
    expect(container.read(taskControllerProvider).single.id, 'new-task');
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.saved,
    );
    expect((await queue.load('owner-a'))?.desired.single.id, 'old-task');
  });

  test(
    'late save failure cannot overwrite the next owner recovery state',
    () async {
      final repository = _DelayedTaskRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final save = controller.addTask(_task('old-task'));
      await repository.requested.future;
      (container.read(authControllerProvider.notifier)
              as _SwitchableAuthController)
          .setOwner('owner-b');
      await controller.addTask(_task('new-task'));
      repository.fail();

      await expectLater(save, throwsStateError);
      expect(container.read(taskControllerProvider).single.id, 'new-task');
      expect(
        container.read(taskMutationControllerProvider).status,
        TaskMutationStatus.saved,
      );
    },
  );

  test('late reorder success cannot merge old owner ordering', () async {
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
    await repository.requested.future;
    (container.read(authControllerProvider.notifier)
            as _SwitchableAuthController)
        .setOwner('owner-b');
    repository.finish();

    expect(await reorder, isFalse);
    expect(container.read(taskControllerProvider), isEmpty);
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.idle,
    );
  });
}

ProviderContainer _container(
  TaskRepository repository,
  TaskOfflineQueueRepository queue,
) => ProviderContainer(
  overrides: [
    authControllerProvider.overrideWith(_SwitchableAuthController.new),
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

class _SwitchableAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );

  void setOwner(String id) {
    state = AuthState(
      profile: UserProfile(id: id, email: '$id@example.invalid', nickname: id),
    );
  }
}

class _DelayedTaskRepository extends InMemoryTaskRepository {
  final requested = Completer<void>();
  final _release = Completer<void>();
  bool _firstCall = true;

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    if (_firstCall) {
      _firstCall = false;
      requested.complete();
      await _release.future;
    }
    return super.saveAll(tasks);
  }

  void finish() => _release.complete();

  void fail() => _release.completeError(StateError('network failed'));
}

class _DelayedReorderRepository extends InMemoryTaskRepository {
  final requested = Completer<void>();
  final _release = Completer<void>();

  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) async {
    if (!requested.isCompleted) requested.complete();
    await _release.future;
    return super.reorderMissionTasks(
      missionId,
      ordered,
      operationId: operationId,
    );
  }

  void finish() => _release.complete();
}
