import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'durable Task retry keeps CAS version, origin, and mutation kind',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final queue = PersistedTaskOfflineQueueRepository();
      final mutation = PendingTaskMutation(
        ownerId: 'owner-a',
        idempotencyKey: 'reorder-1',
        desired: [_task('first').copyWith(version: 7)],
        previous: [_task('first').copyWith(version: 7)],
        kind: TaskMutationKind.reorder,
      );
      await queue.save('owner-a', mutation);

      final restored = await PersistedTaskOfflineQueueRepository().load(
        'owner-a',
      );
      expect(restored?.kind, TaskMutationKind.reorder);
      expect(restored?.desired.single.version, 7);
      expect(restored?.desired.single.origin, TaskOrigin.copied);
      expect(restored?.previous.single.version, 7);
    },
  );

  test('legacy retry derives origin and defaults missing CAS version', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final queue = PersistedTaskOfflineQueueRepository(storage: storage);
    await queue.save(
      'owner-a',
      PendingTaskMutation(
        ownerId: 'owner-a',
        idempotencyKey: 'legacy-save',
        desired: [
          QuestraTask(
            id: 'legacy',
            questId: 'quest',
            missionId: 'mission',
            title: '準備する',
            action: '必要な準備をする',
            doneCondition: '準備が完了した',
            generatedBy: TaskGeneratedBy.arc,
          ),
        ],
        previous: const [],
      ),
    );
    final key =
        'questra_task_offline_queue_v2_${base64Url.encode(utf8.encode('owner-a'))}';
    final payload =
        jsonDecode((await storage.read(key: key))!) as Map<String, dynamic>;
    payload.remove('kind');
    (payload['desired'] as List).single.remove('taskVersion');
    (payload['desired'] as List).single.remove('origin');
    await storage.write(key: key, value: jsonEncode(payload));

    final restored = await queue.load('owner-a');
    expect(restored?.kind, TaskMutationKind.save);
    expect(restored?.desired.single.version, 1);
    expect(restored?.desired.single.origin, TaskOrigin.arcSuggestion);
  });

  test('reorder retry uses reorder RPC path, not create-only save', () async {
    final repository = _FailFirstReorderRepository();
    final queue = InMemoryTaskOfflineQueueRepository();
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = _task('first');
    final second = _task('second').copyWith(orderIndex: 1);
    await controller.addTasks([first, second]);

    expect(
      await controller.reorderMissionTasks('mission', [second, first]),
      isFalse,
    );
    expect((await queue.load('owner-a'))?.kind, TaskMutationKind.reorder);
    expect(await controller.retryPending(), isTrue);
    expect(repository.reorderCalls, 2);
    expect(repository.saveCalls, 2);
    expect(await queue.load('owner-a'), isNull);
    expect(controller.forMission('mission').map((task) => task.id), [
      'second',
      'first',
    ]);
  });

  test('journal cleanup failure cannot undo an already saved Task', () async {
    final repository = _FailFirstReorderRepository()..failReorder = false;
    final queue = _FailFirstClearQueue();
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final saved = await controller.addTask(_task('first'));
    expect(saved.id, 'first');
    expect(container.read(taskControllerProvider).single.id, 'first');
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.cleanupPending,
    );
    expect((await queue.load('owner-a'))?.desired.single.id, 'first');
    await expectLater(controller.addTask(_task('second')), throwsStateError);
    expect(repository.saveCalls, 1);

    expect(await controller.retryPending(), isTrue);
    expect(await queue.load('owner-a'), isNull);
    expect(repository.saveCalls, 1);
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.saved,
    );
    await controller.addTask(_task('second'));
    expect(repository.saveCalls, 2);
  });

  test('journal cleanup failure cannot undo an accepted reorder', () async {
    final repository = _FailFirstReorderRepository()..failReorder = false;
    final queue = _FailFirstClearQueue()..failClear = false;
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    final first = _task('first');
    final second = _task('second').copyWith(orderIndex: 1);
    await controller.addTasks([first, second]);
    queue.failClear = true;

    expect(
      await controller.reorderMissionTasks('mission', [second, first]),
      isTrue,
    );
    expect(controller.forMission('mission').map((task) => task.id), [
      'second',
      'first',
    ]);
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.cleanupPending,
    );
    expect((await queue.load('owner-a'))?.kind, TaskMutationKind.reorder);
    expect(await controller.retryPending(), isTrue);
    expect(repository.reorderCalls, 1);
    expect(await queue.load('owner-a'), isNull);
  });

  test('late queue cleanup does not show the prior owner save', () async {
    final repository = _FailFirstReorderRepository()..failReorder = false;
    final queue = _DelayedClearQueue();
    final container = _container(repository, queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final save = controller.addTask(_task('first'));
    await queue.clearStarted.future;
    (container.read(authControllerProvider.notifier) as _OwnerFixture).setOwner(
      'owner-b',
    );
    queue.finishClear();
    await expectLater(save, throwsStateError);
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
    authControllerProvider.overrideWith(_OwnerFixture.new),
    taskRepositoryProvider.overrideWithValue(repository),
    taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
  ],
);

QuestraTask _task(String id) => QuestraTask(
  id: id,
  questId: 'quest',
  missionId: 'mission',
  title: 'Task $id',
  action: 'Task $id を行う',
  doneCondition: '結果を記録する',
  origin: TaskOrigin.copied,
);

class _OwnerFixture extends AuthController {
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

class _FailFirstReorderRepository extends InMemoryTaskRepository {
  bool failReorder = true;
  int reorderCalls = 0;
  int saveCalls = 0;

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) {
    saveCalls++;
    return super.saveAll(tasks);
  }

  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) async {
    reorderCalls++;
    if (failReorder) {
      failReorder = false;
      throw StateError('temporary failure');
    }
    return super.reorderMissionTasks(
      missionId,
      ordered,
      operationId: operationId,
    );
  }
}

class _FailFirstClearQueue extends InMemoryTaskOfflineQueueRepository {
  bool failClear = true;

  @override
  Future<void> clear(String ownerId) async {
    if (failClear) {
      failClear = false;
      throw StateError('secure storage unavailable');
    }
    await super.clear(ownerId);
  }
}

class _DelayedClearQueue extends InMemoryTaskOfflineQueueRepository {
  final clearStarted = Completer<void>();
  final _release = Completer<void>();

  @override
  Future<void> clear(String ownerId) async {
    clearStarted.complete();
    await _release.future;
    await super.clear(ownerId);
  }

  void finishClear() => _release.complete();
}
