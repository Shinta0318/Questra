import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/mission/mission_controller.dart';
import 'package:questra/features/mission/mission_model.dart';
import 'package:questra/features/mission/mission_providers.dart';
import 'package:questra/features/mission/mission_repository.dart';
import 'package:questra/features/quest/quest_guide_model.dart';
import 'package:questra/features/task/task_controller.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_offline_queue_repository.dart';
import 'package:questra/features/task/task_providers.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  final completed = QuestraTask(
    id: 'task-535',
    questId: 'quest-535',
    missionId: 'mission-535',
    title: '準備する',
    action: '必要な準備をする',
    doneCondition: '準備が終わった',
    status: TaskStatus.completed,
    completedAt: DateTime.utc(2026, 10, 4),
    version: 5,
  );

  test(
    'reopen response requires identity, next version and null completion',
    () {
      final reopened = confirmTaskReopen(completed, {
        'status': 'already_applied',
        'task_id': completed.id,
        'version': 6,
        'completed_at': null,
      });
      expect(reopened.status, TaskStatus.pending);
      expect(reopened.completedAt, isNull);
      expect(reopened.version, 6);
      expect(
        () => confirmTaskReopen(completed, {'status': 'conflict'}),
        throwsA(isA<TaskVersionConflictException>()),
      );
      expect(
        () => confirmTaskReopen(completed, {
          'status': 'reopened',
          'task_id': completed.id,
          'version': 7,
          'completed_at': null,
        }),
        throwsA(isA<TaskVersionConflictException>()),
      );
      expect(
        () => confirmTaskReopen(completed, {
          'status': 'reopened',
          'task_id': 'other',
          'version': 6,
          'completed_at': null,
        }),
        throwsStateError,
      );
    },
  );

  test('rejected remote reopen retains Mission confirmation', () async {
    final repository = _RemoteReopenRepository()..rejectReopen = true;
    await repository.save(completed);
    final container = await _container(repository);
    addTearDown(container.dispose);
    final controller = container.read(taskControllerProvider.notifier);
    await controller.loadForQuestIds(['quest-535']);

    expect(await controller.reopen(completed.id), isFalse);
    expect(
      container.read(taskControllerProvider).single.status,
      TaskStatus.completed,
    );
    expect(
      container.read(missionControllerProvider).single.successConfirmedAt,
      isNotNull,
    );
  });

  test(
    'acknowledged remote reopen clears local Mission confirmation',
    () async {
      final repository = _RemoteReopenRepository();
      await repository.save(completed);
      final container = await _container(repository);
      addTearDown(container.dispose);
      final controller = container.read(taskControllerProvider.notifier);
      await controller.loadForQuestIds(['quest-535']);

      expect(await controller.reopen(completed.id), isTrue);
      expect(
        container.read(taskControllerProvider).single.status,
        TaskStatus.pending,
      );
      expect(
        container.read(missionControllerProvider).single.successConfirmedAt,
        isNull,
      );
      expect(
        container.read(missionControllerProvider).single.status,
        MissionStatus.todo,
      );
    },
  );

  test('active dependent Task blocks reopening prerequisite', () async {
    final repository = InMemoryTaskRepository();
    await repository.save(completed);
    await repository.save(
      QuestraTask(
        questId: completed.questId,
        missionId: completed.missionId,
        title: '次のTask',
        action: '次の行動をする',
        doneCondition: '結果を残す',
        status: TaskStatus.inProgress,
        dependencyIds: [completed.id],
      ),
    );
    await expectLater(
      repository.reopenAtomically(completed, operationId: 'reopen-1'),
      throwsA(isA<TaskVersionConflictException>()),
    );
  });

  test('DB contract uses owner-scoped CAS and clears confirmation', () {
    final sql = File(
      '../../supabase/migrations/202610040002_task_reopen_atomic.sql',
    ).readAsStringSync();
    expect(sql, contains("v_task.owner_id <> v_actor"));
    expect(sql, contains('v_task.version <> p_expected_version'));
    expect(sql, contains('v_existing.result_version'));
    expect(sql, contains('success_confirmed_at = null'));
    expect(sql, contains("dependent.status in ('in_progress', 'completed')"));
  });
}

Future<ProviderContainer> _container(TaskRepository repository) async {
  final missionRepository = InMemoryMissionRepository();
  await missionRepository.save(_confirmedMission());
  return ProviderContainer(
    overrides: [
      taskRepositoryProvider.overrideWithValue(repository),
      taskOfflineQueueRepositoryProvider.overrideWithValue(
        InMemoryTaskOfflineQueueRepository(),
      ),
      missionRepositoryProvider.overrideWithValue(missionRepository),
      missionControllerProvider.overrideWith(_ConfirmedMissionController.new),
    ],
  );
}

class _RemoteReopenRepository extends InMemoryTaskRepository {
  bool rejectReopen = false;

  @override
  bool get supportsAtomicCompletion => true;

  @override
  Future<QuestraTask> reopenAtomically(
    QuestraTask task, {
    required String operationId,
  }) {
    if (rejectReopen) throw const TaskVersionConflictException();
    return super.reopenAtomically(task, operationId: operationId);
  }
}

class _ConfirmedMissionController extends MissionController {
  @override
  List<Mission> build() => [_confirmedMission()];
}

Mission _confirmedMission() => Mission(
  id: 'mission-535',
  questId: 'quest-535',
  questTitle: 'QST-535 Quest',
  title: '準備を整える',
  description: '準備を確認する',
  guideType: GuideType.route,
  difficulty: MissionDifficulty.easy,
  status: MissionStatus.completed,
  progressPercent: 100,
  successConfirmedAt: DateTime.utc(2026, 10, 4),
);
