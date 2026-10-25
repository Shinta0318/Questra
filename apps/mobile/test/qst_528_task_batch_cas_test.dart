import 'dart:io';

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
  TestWidgetsFlutterBinding.ensureInitialized();

  test('remote write surface requires RPCs and revokes direct mutation', () {
    final sql = File(
      '../../supabase/migrations/202609300003_task_batch_cas_and_restore.sql',
    ).readAsStringSync();
    final repository = File(
      'lib/features/task/task_repository.dart',
    ).readAsStringSync();
    expect(
      sql,
      contains(
        'revoke insert, update, delete on public.tasks from authenticated',
      ),
    );
    expect(
      sql,
      contains('create or replace function public.create_tasks_if_absent'),
    );
    expect(sql, contains('p_expected_versions jsonb'));
    expect(sql, contains("(v_item->>'version')::integer is distinct from 1"));
    expect(sql, contains('for update of m'));
    expect(sql, contains('count(*) from public.tasks where mission_id = p_mission_id'));
    expect(
      sql,
      contains(
        'drop function if exists public.reorder_mission_tasks(uuid, uuid[], text)',
      ),
    );
    expect(sql, isNot(contains('restore_task_batch')));
    expect(repository, contains("'create_tasks_if_absent'"));
    expect(repository, isNot(contains('.upsert(tasks.map')));
    expect(repository, contains('throw UnsupportedError'));
  });

  QuestraTask task(String id) => QuestraTask(
    id: id,
    questId: 'quest',
    questTitle: '富士山に登る',
    missionId: 'mission',
    missionTitle: '装備を整える',
    title: '準備 $id',
    action: '必要なものを調べる',
    doneCondition: '結果を記録する',
  );

  test(
    'route recovery replaces the current set without resetting versions',
    () async {
      final repository = InMemoryTaskRepository();
      final before = [task('first'), task('second')];
      await repository.saveAll(before);
      await repository.updateWithVersion(
        before.first.copyWith(status: TaskStatus.cancelled),
        operationId: 'cancel-first',
      );
      await repository.save(task('route-added'));
      final current = await repository.findByQuestIds(['quest']);

      final restored = await repository.replaceQuestTasks(
        'quest',
        current,
        before,
      );
      expect(restored.map((item) => item.id), ['first', 'second']);
      expect(restored.first.version, 3);
      expect(restored.last.version, 2);
      expect(restored.first.status, TaskStatus.pending);
      expect(
        (await repository.findByQuestIds(['quest'])).map((item) => item.id),
        ['first', 'second'],
      );
    },
  );

  test('stale recovery rejects all changes, including removal', () async {
    final repository = InMemoryTaskRepository();
    final before = [task('first'), task('second')];
    await repository.saveAll(before);
    final expected = await repository.findByQuestIds(['quest']);
    await repository.updateWithVersion(
      before.first.copyWith(title: '別の端末で変更'),
      operationId: 'remote-edit',
    );
    await repository.save(task('route-added'));
    await expectLater(
      repository.replaceQuestTasks('quest', expected, before),
      throwsA(isA<TaskVersionConflictException>()),
    );
    final after = await repository.findByQuestIds(['quest']);
    expect(after.length, 3);
    expect(after.firstWhere((item) => item.id == 'first').title, '別の端末で変更');
    expect(after.any((item) => item.id == 'route-added'), isTrue);
  });

  test('missing original Task cannot be silently recreated', () async {
    final repository = InMemoryTaskRepository();
    final before = [task('first')];
    await repository.saveAll(before);
    await expectLater(
      repository.replaceQuestTasks('quest', const [], before),
      throwsA(isA<TaskVersionConflictException>()),
    );
    expect((await repository.findByQuestIds(['quest'])).single.id, 'first');
  });

  test('reorder rejects an incomplete local Mission Task list', () async {
    final repository = InMemoryTaskRepository();
    final queue = InMemoryTaskOfflineQueueRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_TaskOwnerFixture.new),
        taskRepositoryProvider.overrideWithValue(repository),
        taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    final first = task('first');
    final second = task('second').copyWith(orderIndex: 1);
    await controller.addTasks([first, second]);

    expect(await controller.reorderMissionTasks('mission', [first]), isFalse);
    expect(
      container.read(taskControllerProvider).map((item) => item.id),
      ['first', 'second'],
    );
  });

  test('stale reorder clears retry queue and asks for current state', () async {
    final repository = _ConflictReorderRepository();
    final queue = InMemoryTaskOfflineQueueRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(_TaskOwnerFixture.new),
        taskRepositoryProvider.overrideWithValue(repository),
        taskOfflineQueueRepositoryProvider.overrideWithValue(queue),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    final first = task('first');
    final second = task('second').copyWith(orderIndex: 1);
    await controller.addTasks([first, second]);

    expect(
      await controller.reorderMissionTasks('mission', [second, first]),
      isFalse,
    );
    expect(
      container.read(taskMutationControllerProvider).status,
      TaskMutationStatus.conflict,
    );
    expect(await queue.load('owner-a'), isNull);
    expect(container.read(taskControllerProvider).first.id, 'first');
  });
}

class _TaskOwnerFixture extends AuthController {
  @override
  AuthState build() => const AuthState(
    profile: UserProfile(
      id: 'owner-a',
      email: 'owner-a@example.invalid',
      nickname: 'A',
    ),
  );
}

class _ConflictReorderRepository extends InMemoryTaskRepository {
  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) async => throw const TaskVersionConflictException();
}
