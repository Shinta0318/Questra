import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class DataExportManifest {
  const DataExportManifest({
    required this.version,
    required this.generatedAt,
    required this.counts,
    required this.payload,
  });

  final int version;
  final DateTime generatedAt;
  final Map<String, int> counts;
  final Map<String, Object?> payload;
}

class TaskDeletionPreview {
  const TaskDeletionPreview({
    required this.taskId,
    required this.taskTitle,
    required this.trailCount,
    required this.memoryCount,
  });

  final String taskId;
  final String taskTitle;
  final int trailCount;
  final int memoryCount;
}

abstract interface class DataRightsRepository {
  Future<DataExportManifest> exportMyData();
  Future<TaskDeletionPreview> previewTaskDeletion(String taskId);
  Future<void> deleteTask(TaskDeletionPreview preview);
}

class SupabaseDataRightsRepository implements DataRightsRepository {
  const SupabaseDataRightsRepository(this.client);

  final SupabaseClient client;

  @override
  Future<DataExportManifest> exportMyData() async {
    final row = Map<String, dynamic>.from(
      await client.rpc<Map<String, dynamic>>('export_my_questra_data'),
    );
    return DataExportManifest(
      version: row['version'] as int? ?? 1,
      generatedAt:
          DateTime.tryParse(row['generated_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
      counts: _counts(row['counts']),
      payload: Map<String, Object?>.from(row),
    );
  }

  @override
  Future<TaskDeletionPreview> previewTaskDeletion(String taskId) async {
    final row = Map<String, dynamic>.from(
      await client.rpc<Map<String, dynamic>>(
        'preview_task_data_deletion',
        params: {'p_task_id': taskId},
      ),
    );
    return TaskDeletionPreview(
      taskId: row['task_id'] as String,
      taskTitle: row['task_title'] as String? ?? 'Task',
      trailCount: row['trail_count'] as int? ?? 0,
      memoryCount: row['memory_count'] as int? ?? 0,
    );
  }

  @override
  Future<void> deleteTask(TaskDeletionPreview preview) async {
    await client.rpc<Object?>(
      'delete_task_with_data_rights_audit',
      params: {
        'p_task_id': preview.taskId,
        'p_confirmation': 'DELETE:${preview.taskId}',
      },
    );
  }

  Map<String, int> _counts(Object? value) {
    if (value is! Map) return const {};
    return Map<String, dynamic>.from(
      value,
    ).map((key, count) => MapEntry(key, count is int ? count : 0));
  }
}

class UnavailableDataRightsRepository implements DataRightsRepository {
  const UnavailableDataRightsRepository();

  Never _unavailable() => throw StateError('データ操作にはログイン済みのBeta接続が必要です。');

  @override
  Future<void> deleteTask(TaskDeletionPreview preview) async => _unavailable();

  @override
  Future<DataExportManifest> exportMyData() async => _unavailable();

  @override
  Future<TaskDeletionPreview> previewTaskDeletion(String taskId) async =>
      _unavailable();
}

final dataRightsRepositoryProvider = Provider<DataRightsRepository>((ref) {
  return SupabaseConfig.isConfigured
      ? SupabaseDataRightsRepository(Supabase.instance.client)
      : const UnavailableDataRightsRepository();
});
