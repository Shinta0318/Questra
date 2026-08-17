import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../core/performance/performance_limits.dart';
import 'task_model.dart';

const _taskColumns =
    'id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,estimated_effort_minutes,status,required,order_index,dependency_ids,scheduled_date,due_date,completed_at,verification_type,generated_by,origin,version,generation_version,created_at,updated_at,missions!inner(title,quests!inner(title))';

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
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks);
  Future<QuestraTask> completeAtomically(
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
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    for (final task in tasks) {
      _tasks.removeWhere((item) => item.id == task.id);
      _tasks.add(task);
    }
    return List.unmodifiable(tasks);
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
  Future<List<QuestraTask>> saveAll(List<QuestraTask> tasks) async {
    if (tasks.isEmpty) return const [];
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('Taskの保存にはログインが必要です。');
    final rows = await client
        .from('tasks')
        .upsert(tasks.map((task) => _toRow(task, ownerId)).toList())
        .select(_taskColumns)
        .limit(tasks.length);
    if (rows.length != tasks.length) {
      throw StateError('Taskをすべて保存できませんでした。');
    }
    return rows
        .map((row) => _fromRow(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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
    final payload = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (payload['status'] != 'completed') {
      throw StateError('Taskを完了できませんでした。');
    }
    return task.copyWith(
      status: TaskStatus.completed,
      completedAt:
          DateTime.tryParse(payload['completed_at'] as String? ?? '') ??
          task.completedAt ??
          DateTime.now(),
      version: payload['version'] as int? ?? task.version + 1,
    );
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
      },
    );
    final payload = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (payload['updated_count'] != ordered.length) {
      throw StateError('Taskの並び順を保存できませんでした。');
    }
    return [
      for (var index = 0; index < ordered.length; index++)
        ordered[index].copyWith(
          orderIndex: index,
          version: ordered[index].version + 1,
        ),
    ];
  }

  @override
  Future<void> delete(String taskId) async =>
      client.from('tasks').delete().eq('id', taskId);

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
