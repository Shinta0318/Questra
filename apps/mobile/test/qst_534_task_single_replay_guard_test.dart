import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:questra/features/task/task_model.dart';
import 'package:questra/features/task/task_repository.dart';

void main() {
  final task = QuestraTask(
    id: 'task-1',
    questId: 'quest-1',
    missionId: 'mission-1',
    title: '準備する',
    action: '必要なことを調べる',
    doneCondition: '調査結果を残す',
  );

  test('single update replay accepts only the immediate successor version', () {
    expect(
      confirmVersionedTaskUpdate(task, {
        'status': 'already_applied',
        'version': 2,
      }).version,
      2,
    );
    expect(
      () => confirmVersionedTaskUpdate(task, {
        'status': 'already_applied',
        'version': 3,
      }),
      throwsA(isA<TaskVersionConflictException>()),
    );
    expect(
      () => confirmVersionedTaskUpdate(task, {'status': 'applied'}),
      throwsStateError,
    );
  });

  test('completion replay requires identity, version and completion time', () {
    final response = {
      'task_id': task.id,
      'status': 'completed',
      'version': 2,
      'completed_at': '2026-10-04T00:00:00Z',
      'already_applied': true,
    };
    final completed = confirmTaskCompletion(task, response);
    expect(completed.status, TaskStatus.completed);
    expect(completed.version, 2);
    expect(completed.completedAt, DateTime.utc(2026, 10, 4));
    expect(
      () => confirmTaskCompletion(task, {...response, 'version': 3}),
      throwsA(isA<TaskVersionConflictException>()),
    );
    expect(
      () => confirmTaskCompletion(task, {...response, 'task_id': 'other'}),
      throwsStateError,
    );
    expect(
      () => confirmTaskCompletion(task, {...response, 'completed_at': null}),
      throwsStateError,
    );
    expect(
      () => confirmTaskCompletion(task, {'status': 'conflict'}),
      throwsA(isA<TaskVersionConflictException>()),
    );
  });

  test('DB contract tracks completion identity and rejects stale replays', () {
    final sql = File(
      '../../supabase/migrations/202610040001_task_single_replay_guard.sql',
    ).readAsStringSync();
    expect(sql, contains('create table public.task_completion_operations'));
    expect(
      sql,
      contains('v_task.version is distinct from v_existing.result_version'),
    );
    expect(
      sql,
      contains(
        "return jsonb_build_object('status', 'conflict', 'version', v_task.version)",
      ),
    );
    expect(sql, contains('v_existing.expected_version <> p_expected_version'));
    expect(sql, contains('revoke all on public.task_completion_operations'));
  });
}
