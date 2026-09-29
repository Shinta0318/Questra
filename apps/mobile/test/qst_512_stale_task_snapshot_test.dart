import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_mutation_banner.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test('start after reschedule retains the latest scheduled date', () async {
    final queue = _DelayedQueue();
    final container = _container(InMemoryTaskRepository(), queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.addTask(_task('task'));

    final date = DateTime(2027, 8, 12);
    queue.blockNext();
    final reschedule = controller.reschedule('task', date);
    await queue.requested.future;
    final start = controller.start('task');
    queue.release();

    expect(await reschedule, isTrue);
    expect(await start, isTrue);
    final saved = container.read(taskControllerProvider).single;
    expect(saved.status, TaskStatus.inProgress);
    expect(saved.scheduledDate, date);
  });

  test('dependency is evaluated after the preceding completion', () async {
    final queue = _DelayedQueue();
    final container = _container(InMemoryTaskRepository(), queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.addTasks([
      _task('first', status: TaskStatus.inProgress),
      _task('next', dependencyIds: const ['first']),
    ]);

    queue.blockNext();
    final completion = controller.complete('first');
    await queue.requested.future;
    final start = controller.start('next');
    queue.release();

    expect(await completion, isTrue);
    expect(await start, isTrue);
    expect(
      container
          .read(taskControllerProvider)
          .where((task) => task.id == 'next')
          .single
          .status,
      TaskStatus.inProgress,
    );
  });

  test(
    'stale full Task update is rejected without changing saved fields',
    () async {
      final queue = _DelayedQueue();
      final container = _container(InMemoryTaskRepository(), queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await controller.addTask(_task('task'));
      final stale = container.read(taskControllerProvider).single;

      final date = DateTime(2027, 8, 12);
      queue.blockNext();
      final reschedule = controller.reschedule('task', date);
      await queue.requested.future;
      final update = controller.updateTask(stale.copyWith(orderIndex: 7));
      queue.release();

      expect(await reschedule, isTrue);
      expect(await update, isFalse);
      final saved = container.read(taskControllerProvider).single;
      expect(saved.scheduledDate, date);
      expect(saved.orderIndex, 0);
      expect(
        container.read(taskMutationControllerProvider).status,
        TaskMutationStatus.conflict,
      );
      expect(container.read(taskMutationControllerProvider).pending, isNull);
      expect(await controller.retryPending(), isFalse);
    },
  );

  test('reorder cannot be undone by a stale full Task update', () async {
    final repository = _DelayedReorderRepository();
    final container = _container(
      repository,
      InMemoryTaskOfflineQueueRepository(),
    );
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.addTasks([
      _task('first'),
      _task('second').copyWith(orderIndex: 1),
    ]);
    final before = container
        .read(taskControllerProvider)
        .singleWhere((task) => task.id == 'second');

    final reorder = controller.reorderMissionTasks('mission-a', [
      before,
      container
          .read(taskControllerProvider)
          .singleWhere((task) => task.id == 'first'),
    ]);
    await repository.requested.future;
    final update = controller.updateTask(
      before.copyWith(scheduledDate: DateTime(2027, 8, 12)),
    );
    repository.release();

    expect(await reorder, isTrue);
    expect(await update, isFalse);
    final second = container
        .read(taskControllerProvider)
        .singleWhere((task) => task.id == 'second');
    expect(second.orderIndex, 0);
    expect(second.scheduledDate, isNull);
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.conflict,
    );
  });

  test('reorder after a queued reschedule keeps the latest date', () async {
    final queue = _DelayedQueue();
    final container = _container(InMemoryTaskRepository(), queue);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    await controller.addTasks([
      _task('first'),
      _task('second').copyWith(orderIndex: 1),
    ]);
    final ordered = container.read(taskControllerProvider);
    final date = DateTime(2027, 8, 12);

    queue.blockNext();
    final reschedule = controller.reschedule('second', date);
    await queue.requested.future;
    final reorder = controller.reorderMissionTasks('mission-a', [
      ordered.singleWhere((task) => task.id == 'second'),
      ordered.singleWhere((task) => task.id == 'first'),
    ]);
    queue.release();

    expect(await reschedule, isTrue);
    expect(await reorder, isTrue);
    final second = container
        .read(taskControllerProvider)
        .singleWhere((task) => task.id == 'second');
    expect(second.orderIndex, 0);
    expect(second.scheduledDate, date);
  });

  testWidgets('conflict banner names the action and can be dismissed', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskMutationBanner(
            state: const TaskMutationState(
              status: TaskMutationStatus.conflict,
              message: 'Taskが先に更新されました。最新の内容を確認してください。',
            ),
            onRetry: () async {},
            onDiscard: () async {},
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.textContaining('Taskが先に更新されました'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);
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

QuestraTask _task(
  String id, {
  TaskStatus status = TaskStatus.pending,
  List<String> dependencyIds = const [],
}) => QuestraTask(
  id: id,
  questId: 'quest-a',
  missionId: 'mission-a',
  title: '旅行日程を確認する',
  action: '同行者と旅行日程を確認する',
  doneCondition: '同行者と候補日が一致している',
  status: status,
  dependencyIds: dependencyIds,
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

class _DelayedQueue extends InMemoryTaskOfflineQueueRepository {
  final requested = Completer<void>();
  final _release = Completer<void>();
  bool _blockNext = false;

  void blockNext() => _blockNext = true;
  void release() => _release.complete();

  @override
  Future<void> save(String ownerId, PendingTaskMutation mutation) async {
    if (_blockNext) {
      _blockNext = false;
      requested.complete();
      await _release.future;
    }
    await super.save(ownerId, mutation);
  }
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
    requested.complete();
    await _release.future;
    return super.reorderMissionTasks(
      missionId,
      ordered,
      operationId: operationId,
    );
  }

  void release() => _release.complete();
}
