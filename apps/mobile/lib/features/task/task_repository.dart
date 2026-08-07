import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import 'task_model.dart';

const _taskColumns =
    'id,quest_id,mission_id,title,action,purpose,done_condition,expected_output,estimated_effort_minutes,status,required,order_index,dependency_ids,scheduled_date,due_date,completed_at,verification_type,generated_by,generation_version,created_at,updated_at,missions!inner(title,quests!inner(title))';

abstract interface class TaskRepository {
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = 200,
  });
  Future<List<QuestraTask>> findByMission(String missionId, {int limit = 50});
  Future<QuestraTask> save(QuestraTask task);
  Future<void> delete(String taskId);
}

class InMemoryTaskRepository implements TaskRepository {
  final List<QuestraTask> _tasks = [];

  @override
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = 200,
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
    int limit = 50,
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
  Future<void> delete(String taskId) async =>
      _tasks.removeWhere((task) => task.id == taskId);
}

class SupabaseTaskRepository implements TaskRepository {
  const SupabaseTaskRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<QuestraTask>> findByQuestIds(
    List<String> questIds, {
    int limit = 200,
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
    int limit = 50,
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
    final ownerId = client.auth.currentUser?.id;
    if (ownerId == null) throw StateError('Taskの保存にはログインが必要です。');
    final rows = await client
        .from('tasks')
        .upsert({
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
          'generation_version': task.generationVersion,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select(_taskColumns)
        .limit(1);
    if (rows.isEmpty) throw StateError('Taskを保存できませんでした。');
    return _fromRow(Map<String, dynamic>.from(rows.first));
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
      generatedBy: enumFromStorage(
        TaskGeneratedBy.values,
        row['generated_by'] as String? ?? 'user',
        TaskGeneratedBy.user,
      ),
      generationVersion: row['generation_version'] as String?,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.parse(row['created_at'] as String),
    );
  }

  String? _date(DateTime? value) => value?.toIso8601String().split('T').first;
  DateTime? _parseDate(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}
