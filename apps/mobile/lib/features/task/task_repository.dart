import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;
import 'package:uuid/uuid.dart';

import '../../core/performance/performance_limits.dart';
import 'task_model.dart';

const _taskColumns =
    'id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,estimated_effort_minutes,status,required,order_index,dependency_ids,scheduled_date,due_date,completed_at,verification_type,generated_by,origin,version,generation_version,created_at,updated_at,missions!inner(title,route_state,quests!inner(title))';

abstract interface class TaskRepository {
  bool get supportsAtomicCompletion;
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.taskListLimit,
  });
  Future<List<QuestraTask>> findByMission(
    String missionId, {
    int limit = QuestraPerformanceLimits.taskPerMissionListLimit,
  });
  Future<QuestraTask> save(QuestraTask task);
  Future<QuestraTask> updateWithVersion(
    QuestraTask task, {
    required String operationId,
  });
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks);
  Future<List<QuestraTask>> replaceQuestTasks(
    String questId,
    List<QuestraTask> expectedCurrent,
    List<QuestraTask> snapshot,
  );
  Future<QuestraTask> completeAtomically(
    QuestraTask task, {
    required String operationId,
  });
  Future<QuestraTask> reopenAtomically(
    QuestraTask task, {
    required String operationId,
  });
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  });
  Future<void> delete(String taskId);
}

class InMemoryTaskRepository implements TaskRepository {
  final List<QuestraTask> _tasks = [];

  @override
  bool get supportsAtomicCompletion => false;

  @override
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.taskListLimit,
  }) async {
    final ids = questIds.toSet();
    return (_tasks.where((task) => ids.contains(task.questId)).toList()
          ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<List<QuestraTask>> findByMission(
    String missionId, {
    int limit = QuestraPerformanceLimits.taskPerMissionListLimit,
  }) async =>
      (_tasks.where((task) => task.missionId == missionId).toList()
            ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)))
          .take(limit)
          .toList(growable: false);

  @override
  Future<QuestraTask> save(QuestraTask task) async {
    _tasks.removeWhere((item) => item.id == task.id);
    _tasks.add(task);
    return task;
  }

  @override
  Future<QuestraTask> updateWithVersion(
    QuestraTask task, {
    required String operationId,
  }) async {
    final current = _tasks.where((item) => item.id == task.id).firstOrNull;
    if (current == null || current.version != task.version) {
      throw const TaskVersionConflictException();
    }
    return save(task.copyWith(version: task.version + 1));
  }

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    for (final task in tasks) {
      _tasks.removeWhere((item) => item.id == task.id);
      _tasks.add(task);
    }
    return List.unmodifiable(tasks);
  }

  @override
  Future<List<QuestraTask>> replaceQuestTasks(
    String questId,
    List<QuestraTask> expectedCurrent,
    List<QuestraTask> snapshot,
  ) async {
    final current = _tasks.where((task) => task.questId == questId).toList();
    final expected = {
      for (final task in expectedCurrent) task.id: task.version,
    };
    if (current.length != expected.length ||
        current.any((task) => expected[task.id] != task.version) ||
        snapshot.any(
          (task) =>
              task.questId != questId ||
              !expected.containsKey(task.id) ||
              task.missionId !=
                  current.where((item) => item.id == task.id).first.missionId,
        )) {
      throw const TaskVersionConflictException();
    }
    final saved = [
      for (final task in snapshot)
        task.copyWith(version: expected[task.id]! + 1),
    ];
    _tasks.removeWhere((task) => task.questId == questId);
    _tasks.addAll(saved);
    return List.unmodifiable(saved);
  }

  @override
  Future<QuestraTask> completeAtomically(
    QuestraTask task, {
    required String operationId,
  }) => save(
    task.copyWith(
      status: TaskStatus.completed,
      completedAt: task.completedAt ?? DateTime.now(),
      version: task.version + 1,
    ),
  );

  @override
  Future<QuestraTask> reopenAtomically(
    QuestraTask task, {
    required String operationId,
  }) async {
    final current = _tasks.where((item) => item.id == task.id).firstOrNull;
    if (current == null ||
        current.version != task.version ||
        current.status != TaskStatus.completed ||
        _tasks.any(
          (item) =>
              item.missionId == task.missionId &&
              item.dependencyIds.contains(task.id) &&
              {
                TaskStatus.inProgress,
                TaskStatus.completed,
              }.contains(item.status),
        )) {
      throw const TaskVersionConflictException();
    }
    return save(
      task.copyWith(
        status: TaskStatus.pending,
        clearCompletedAt: true,
        version: task.version + 1,
      ),
    );
  }

  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) => saveAll(ordered);

  @override
  Future<void> delete(String taskId) async =>
      _tasks.removeWhere((task) => task.id == taskId);
}

class SupabaseTaskRepository implements TaskRepository {
  const SupabaseTaskRepository(this.client);
  final SupabaseClient client;

  @override
  bool get supportsAtomicCompletion => true;

  @override
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = QuestraPerformanceLimits.taskListLimit,
  }) async {
    if (questIds.isEmpty) return const [];
    final rows = await client
        .from('tasks')
        .select(_taskColumns)
        .inFilter('quest_id', questIds)
        .neq('missions.route_state', 'removed')
        .order('mission_id')
        .order('order_index')
        .limit(limit);
    return rows
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<List<QuestraTask>> findByMission(
    String missionId, {
    int limit = QuestraPerformanceLimits.taskPerMissionListLimit,
  }) async {
    final rows = await client
        .from('tasks')
        .select(_taskColumns)
        .eq('mission_id', missionId)
        .order('order_index')
        .limit(limit);
    return rows
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<QuestraTask> save(QuestraTask task) async {
    final saved = await saveAll([task]);
    return saved.single;
  }

  @override
  Future<QuestraTask> updateWithVersion(
    QuestraTask task, {
    required String operationId,
  }) async {
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('Taskの保存にはログインが必要です。');
    final payload = Map<String, Object?>.from(_toRow(task, ownerId))
      ..remove('updated_at');
    final response = await client.rpc(
      'update_task_if_version',
      params: {
        'p_task_id': task.id,
        'p_expected_version': task.version,
        'p_operation_id': operationId,
        'p_payload': payload,
      },
    );
    return confirmVersionedTaskUpdate(task, response);
  }

  @override
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    if (tasks.isEmpty) return const [];
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('Taskの保存にはログインが必要です。');
    if (tasks.map((task) => task.id).toSet().length != tasks.length) {
      throw ArgumentError('同じTaskを一括保存できません。');
    }
    return _applyBatch(tasks: tasks, ownerId: ownerId);
  }

  @override
  Future<List<QuestraTask>> replaceQuestTasks(
    String questId,
    List<QuestraTask> expectedCurrent,
    List<QuestraTask> snapshot,
  ) => throw UnsupportedError('保存済みの航路は承認済みの航路RPCから復旧してください。');

  Future<List<QuestraTask>> _applyBatch({
    required List<QuestraTask> tasks,
    required String ownerId,
  }) async {
    final rows = [
      for (final task in tasks)
        Map<String, Object?>.from(_toRow(task, ownerId))..remove('updated_at'),
    ];
    final operationId =
        'task-create:${const Uuid().v5(Namespace.url.value, jsonEncode(rows))}';
    final response = await client.rpc(
      'create_tasks_if_absent',
      params: {'p_operation_id': operationId, 'p_tasks': rows},
    );
    final result = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (result['status'] == 'conflict') {
      throw const TaskVersionConflictException();
    }
    if (result['status'] != 'applied' &&
        result['status'] != 'already_applied') {
      throw StateError('Taskの保存結果を確認できませんでした。');
    }
    if (tasks.isEmpty) return const [];
    final loaded = await client
        .from('tasks')
        .select(_taskColumns)
        .inFilter('id', tasks.map((task) => task.id).toList())
        .limit(tasks.length);
    if (loaded.length != tasks.length) {
      throw StateError('保存したTaskを再確認できませんでした。');
    }
    final byId = {
      for (final row in loaded)
        row['id'] as String: _fromRow(Map<String, dynamic>.from(row)),
    };
    return [for (final task in tasks) byId[task.id]!];
  }

  @override
  Future<QuestraTask> completeAtomically(
    QuestraTask task, {
    required String operationId,
  }) async {
    final response = await client.rpc(
      'complete_task_journey',
      params: {
        'p_task_id': task.id,
        'p_operation_id': operationId,
        'p_expected_version': task.version,
      },
    );
    return confirmTaskCompletion(task, response);
  }

  @override
  Future<QuestraTask> reopenAtomically(
    QuestraTask task, {
    required String operationId,
  }) async {
    final response = await client.rpc(
      'reopen_task_journey',
      params: {
        'p_task_id': task.id,
        'p_operation_id': operationId,
        'p_expected_version': task.version,
      },
    );
    return confirmTaskReopen(task, response);
  }

  @override
  Future<List<QuestraTask>> reorderMissionTasks(
    String missionId,
    List<QuestraTask> ordered, {
    required String operationId,
  }) async {
    final response = await client.rpc(
      'reorder_mission_tasks',
      params: {
        'p_mission_id': missionId,
        'p_task_ids': ordered.map((task) => task.id).toList(growable: false),
        'p_operation_id': operationId,
        'p_expected_versions': {
          for (final task in ordered) task.id: task.version,
        },
      },
    );
    final payload = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (payload['status'] == 'conflict') {
      throw const TaskVersionConflictException();
    }
    if ((payload['status'] != 'applied' &&
            payload['status'] != 'already_applied') ||
        payload['updated_count'] != ordered.length) {
      throw StateError('Taskの並び順を保存できませんでした。');
    }
    final rows = await client
        .from('tasks')
        .select(_taskColumns)
        .eq('mission_id', missionId)
        .order('order_index');
    if (rows.length != ordered.length) {
      throw const TaskVersionConflictException();
    }
    final saved = [
      for (final row in rows) _fromRow(Map<String, dynamic>.from(row)),
    ];
    for (var index = 0; index < ordered.length; index++) {
      if (saved[index].id != ordered[index].id ||
          saved[index].orderIndex != index ||
          saved[index].version != ordered[index].version + 1) {
        throw const TaskVersionConflictException();
      }
    }
    return saved;
  }

  @override
  Future<void> delete(String taskId) async =>
      throw UnsupportedError('Taskの削除は承認済みの航路復旧処理から行ってください。');

  QuestraTask _fromRow(Map<String, dynamic> row) {
    final mission = row['missions'] is Map
        ? Map<String, dynamic>.from(row['missions'] as Map)
        : const <String, dynamic>{};
    final quest = mission['quests'] is Map
        ? Map<String, dynamic>.from(mission['quests'] as Map)
        : const <String, dynamic>{};
    final generatedBy = enumFromStorage(
      TaskGeneratedBy.values,
      row['generated_by'] as String? ?? 'user',
      TaskGeneratedBy.user,
    );
    return QuestraTask(
      id: row['id'] as String,
      questId: row['quest_id'] as String,
      missionId: row['mission_id'] as String,
      questTitle: quest['title'] as String? ?? '',
      missionTitle: mission['title'] as String? ?? '',
      title: row['title'] as String,
      action: row['action'] as String,
      purpose: row['purpose'] as String? ?? '',
      doneCondition: row['done_condition'] as String,
      expectedOutput: row['expected_output'] as String? ?? '',
      estimatedEffortMinutes: row['estimated_effort_minutes'] as int?,
      status: taskStatusFromStorage(row['status'] as String? ?? 'pending'),
      required: row['required'] as bool? ?? true,
      orderIndex: row['order_index'] as int? ?? 0,
      dependencyIds:
          (row['dependency_ids'] as List?)?.whereType<String>().toList() ??
          const [],
      scheduledDate: _parseDate(row['scheduled_date']),
      dueDate: _parseDate(row['due_date']),
      completedAt: _parseDate(row['completed_at']),
      verificationType: taskVerificationTypeFromStorage(
        row['verification_type'] as String? ?? 'self',
      ),
      generatedBy: generatedBy,
      origin: taskOriginFromStorage(
        row['origin'] as String? ?? '',
        generatedBy,
      ),
      version: row['version'] as int? ?? 1,
      generationVersion: row['generation_version'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.parse(row['created_at'] as String),
    );
  }

  Map<String, Object?> _toRow(QuestraTask task, String ownerId) => {
    'id': task.id,
    'owner_id': ownerId,
    'quest_id': task.questId,
    'mission_id': task.missionId,
    'title': task.title,
    'action': task.action,
    'purpose': task.purpose,
    'done_condition': task.doneCondition,
    'expected_output': task.expectedOutput,
    'estimated_effort_minutes': task.estimatedEffortMinutes,
    'status': task.status.storageKey,
    'required': task.required,
    'order_index': task.orderIndex,
    'dependency_ids': task.dependencyIds,
    'scheduled_date': _date(task.scheduledDate),
    'due_date': _date(task.dueDate),
    'completed_at': task.completedAt?.toIso8601String(),
    'verification_type': task.verificationType.storageKey,
    'generated_by': task.generatedBy.name,
    'origin': task.origin.storageKey,
    'version': task.version,
    'generation_version': task.generationVersion,
    'updated_at': DateTime.now().toIso8601String(),
  };

  String? _date(DateTime? value) => value?.toIso8601String().split('T').first;
  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class TaskVersionConflictException implements Exception {
  const TaskVersionConflictException();

  @override
  String toString() => 'Taskが別の端末で更新されました。最新の内容を確認してください。';
}

QuestraTask confirmVersionedTaskUpdate(QuestraTask task, Object? response) {
  final result = response is Map
      ? Map<String, dynamic>.from(response)
      : const <String, dynamic>{};
  if (result['status'] == 'conflict') {
    throw const TaskVersionConflictException();
  }
  if (result['status'] != 'applied' && result['status'] != 'already_applied') {
    throw StateError('Taskの保存結果を確認できませんでした。');
  }
  final version = result['version'];
  if (version is! int) {
    throw StateError('Taskの保存結果を確認できませんでした。');
  }
  if (version != task.version + 1) {
    throw const TaskVersionConflictException();
  }
  return task.copyWith(version: version);
}

QuestraTask confirmTaskCompletion(QuestraTask task, Object? response) {
  final result = response is Map
      ? Map<String, dynamic>.from(response)
      : const <String, dynamic>{};
  if (result['status'] == 'conflict') {
    throw const TaskVersionConflictException();
  }
  if (result['status'] != 'completed' || result['task_id'] != task.id) {
    throw StateError('Taskの完了結果を確認できませんでした。');
  }
  final version = result['version'];
  final completedAt = DateTime.tryParse(
    result['completed_at'] as String? ?? '',
  );
  if (version is! int || completedAt == null) {
    throw StateError('Taskの完了結果を確認できませんでした。');
  }
  if (version != task.version + 1) {
    throw const TaskVersionConflictException();
  }
  return task.copyWith(
    status: TaskStatus.completed,
    completedAt: completedAt,
    version: version,
  );
}

QuestraTask confirmTaskReopen(QuestraTask task, Object? response) {
  final result = response is Map
      ? Map<String, dynamic>.from(response)
      : const <String, dynamic>{};
  if (result['status'] == 'conflict') {
    throw const TaskVersionConflictException();
  }
  if ((result['status'] != 'reopened' &&
          result['status'] != 'already_applied') ||
      result['task_id'] != task.id ||
      result['completed_at'] != null) {
    throw StateError('Taskの再開結果を確認できませんでした。');
  }
  if (result['version'] != task.version + 1) {
    throw const TaskVersionConflictException();
  }
  return task.copyWith(
    status: TaskStatus.pending,
    clearCompletedAt: true,
    version: result['version'] as int,
  );
}
