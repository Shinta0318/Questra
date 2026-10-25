import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/auth/auth_controller.dart';
import 'package:questra/features/auth/auth_state.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_mutation_state.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  test(
    'CAS conflict replaces stale Task with the remote Mission state',
    () async {
      final repository = _VersionedTaskRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = await _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final original = await controller.addTask(_task());
      await controller.addTask(
        _task(id: 'unrelated', missionId: 'other-mission'),
      );
      await repository.updateWithVersion(
        original.copyWith(title: '別の端末で変更したTask'),
        operationId: 'remote-edit',
      );

      expect(await controller.start(original.id), isFalse);
      final current = container
          .read(taskControllerProvider)
          .firstWhere((task) => task.id == original.id);
      expect(current.title, '別の端末で変更したTask');
      expect(current.version, 2);
      expect(current.status, TaskStatus.pending);
      expect(
        container
            .read(taskControllerProvider)
            .firstWhere((task) => task.id == 'unrelated')
            .missionId,
        'other-mission',
      );
      expect(
        container.read(taskMutationControllerProvider).status,
        TaskMutationStatus.conflict,
      );
      expect(
        container.read(taskMutationControllerProvider).message,
        contains('最新の内容を確認'),
      );
      expect(await queue.load('owner-a'), isNull);
    },
  );

  test(
    'refresh failure tells the user that the displayed Task may be stale',
    () async {
      final repository = _VersionedTaskRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = await _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final original = await controller.addTask(_task());
      await repository.updateWithVersion(
        original.copyWith(title: '別の端末で変更したTask'),
        operationId: 'remote-edit',
      );
      repository.failReads = true;

      expect(await controller.start(original.id), isFalse);
      expect(
        container.read(taskControllerProvider).single.title,
        original.title,
      );
      expect(
        container.read(taskMutationControllerProvider).message,
        contains('最新の内容を読み込めませんでした'),
      );
      expect(await queue.load('owner-a'), isNull);
    },
  );

  test(
    'failed conflict cleanup retains the retry record and blocks writes',
    () async {
      final repository = _VersionedTaskRepository();
      final queue = _FailClearQueue();
      final container = await _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final original = await controller.addTask(_task());
      await repository.updateWithVersion(
        original.copyWith(title: '別の端末で変更したTask'),
        operationId: 'remote-edit',
      );
      queue.failClear = true;

      expect(await controller.start(original.id), isFalse);
      expect(container.read(taskMutationControllerProvider).canRetry, isTrue);
      expect(await queue.load('owner-a'), isNotNull);
      await expectLater(
        controller.addTask(_task(id: 'second')),
        throwsStateError,
      );
      await controller.discardPending();
      expect(await queue.load('owner-a'), isNull);
    },
  );

  test(
    'late conflict refresh cannot display the previous owner Task',
    () async {
      final repository = _VersionedTaskRepository();
      final queue = InMemoryTaskOfflineQueueRepository();
      final container = await _container(repository, queue);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final original = await controller.addTask(_task());
      await repository.updateWithVersion(
        original.copyWith(title: '別の端末で変更したTask'),
        operationId: 'remote-edit',
      );
      repository.delayReads = true;

      final start = controller.start(original.id);
      await repository.readStarted.future;
      (container.read(authControllerProvider.notifier) as _OwnerFixture)
          .setOwner('owner-b');
      repository.finishRead();
      expect(await start, isFalse);
      expect(container.read(taskControllerProvider), isEmpty);
      expect(
        container.read(taskMutationControllerProvider).status,
        TaskMutationStatus.idle,
      );
    },
  );
}

Future<ProviderContainer> _container(
  TaskRepository repository,
  TaskOfflineQueueRepository queue,
) async {
  final missions = InMemoryMissionRepository();
  for (final id in ['mission', 'other-mission']) {
    await missions.save(
      Mission(
        id: id,
        questId: 'quest',
        questTitle: '準備のQuest',
        title: '準備する',
        description: '必要な準備をする',
        guideType: GuideType.route,
        difficulty: MissionDifficulty.easy,
        status: MissionStatus.todo,
      ),
    );
  }
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(_OwnerFixture.new),
      missionRepositoryProvider.overrideWithValue(missions),
      taskRepositoryProvider.overrideWithValue(repository),
      taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
    ],
  );
}

QuestraTask _task({String id = 'first', String missionId = 'mission'}) =>
    QuestraTask(
      id: id,
      questId: 'quest',
      missionId: missionId,
      title: '準備する',
      action: '必要な準備をする',
      doneCondition: '準備が終わった',
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

class _VersionedTaskRepository extends InMemoryTaskRepository {
  bool failReads = false;
  bool delayReads = false;
  final readStarted = Completer<void>();
  final _releaseRead = Completer<void>();

  @override
  bool get supportsAtomicCompletion => true;

  @override
  Future<List<QuestraTask>> findByMission(
    String missionId, {
    int limit = 50,
  }) async {
    if (failReads) throw StateError('network unavailable');
    if (delayReads) {
      readStarted.complete();
      await _releaseRead.future;
    }
    return super.findByMission(missionId, limit: limit);
  }

  void finishRead() => _releaseRead.complete();
}

class _FailClearQueue extends InMemoryTaskOfflineQueueRepository {
  bool failClear = false;

  @override
  Future<void> clear(String ownerId) async {
    if (failClear) {
      failClear = false;
      throw StateError('local journal unavailable');
    }
    await super.clear(ownerId);
  }
}
