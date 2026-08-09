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
  test('再起動後に同じユーザーの未送信Taskだけを復元して再試行する', () async {
    final queue = InMemoryTaskOfflineQueueRepository();
    final pending = PendingTaskMutation(
      ownerId: 'owner-a',
      idempotencyKey: 'task-upsert:task-1',
      desired: [_task()],
      previous: const [],
      attempts: 1,
    );
    await queue.save('owner-a', pending);

    final firstProcess = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAAuthController.new),
        taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
        taskRepositoryProvider.overrideWithValue(InMemoryTaskRepository()),
      ],
    );
    addTearDown(firstProcess.dispose);
    firstProcess.read(taskControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    final restored = firstProcess.read(taskMutationControllerProvider);
    expect(restored.status, TaskMutationStatus.offlinePending);
    expect(restored.pending?.ownerId, 'owner-a');
    expect(restored.pending?.desired.single.id, 'task-1');

    expect(
      await firstProcess.read(taskControllerProvider.notifier).retryPending(),
      isTrue,
    );
    expect(await queue.load('owner-a'), isNull);
    expect(
      await firstProcess.read(taskControllerProvider.notifier).retryPending(),
      isFalse,
    );
    expect(
      await firstProcess
          .read(taskRepositoryProvider)
          .findByMission('mission-1'),
      hasLength(1),
    );
  });

  test('別ユーザーへ切り替えても保留中Taskは公開されない', () async {
    final queue = InMemoryTaskOfflineQueueRepository();
    await queue.save(
      'owner-a',
      PendingTaskMutation(
        ownerId: 'owner-a',
        idempotencyKey: 'task-upsert:private-task',
        desired: [_task()],
        previous: const [],
      ),
    );
    final secondUserProcess = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerBAuthController.new),
        taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(secondUserProcess.dispose);
    secondUserProcess.read(taskControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      secondUserProcess.read(taskMutationControllerProvider).pending,
      isNull,
    );
    expect(await queue.load('owner-a'), isNotNull);
  });

  test('期限切れの未送信Taskはfail closedで削除する', () async {
    final now = DateTime.utc(2026, 8, 9);
    final queue = InMemoryTaskOfflineQueueRepository(clock: () => now);
    await queue.save(
      'owner-a',
      PendingTaskMutation(
        ownerId: 'owner-a',
        idempotencyKey: 'task-upsert:expired-task',
        desired: [_task()],
        previous: const [],
        queuedAt: now.subtract(const Duration(days: 8)),
      ),
    );

    expect(await queue.load('owner-a'), isNull);
    expect(await queue.load('owner-a'), isNull);
  });

  test('ユーザーが破棄した未送信Taskは永続Queueから消える', () async {
    final queue = InMemoryTaskOfflineQueueRepository();
    await queue.save(
      'owner-a',
      PendingTaskMutation(
        ownerId: 'owner-a',
        idempotencyKey: 'task-upsert:discard-task',
        desired: [_task()],
        previous: const [],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_OwnerAAuthController.new),
        taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(container.dispose);
    container.read(taskControllerProvider);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    await container.read(taskControllerProvider.notifier).discardPending();

    expect(await queue.load('owner-a'), isNull);
    expect(container.read(taskMutationControllerProvider).pending, isNull);
  });
}

QuestraTask _task() => QuestraTask(
  id: 'task-1',
  questId: 'quest-1',
  missionId: 'mission-1',
  questTitle: '非公開Quest',
  missionTitle: '準備する',
  title: '確認する',
  action: '必要な情報を確認する',
  doneCondition: '確認結果が記録されている',
);

class _OwnerAAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
}

class _OwnerBAuthController extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-b',
      email: 'owner-b@example.invalid',
      nickname: 'B',
    ),
  );
}
