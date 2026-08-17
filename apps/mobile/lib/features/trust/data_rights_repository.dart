import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class DataRightsRequest {
  const DataRightsRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.submittedAt,
    this.cancellableUntil,
    this.scheduledFor,
  });

  final String id;
  final String type;
  final String status;
  final DateTime submittedAt;
  final DateTime? cancellableUntil;
  final DateTime? scheduledFor;

  bool get canCancel =>
      status == 'scheduled' &&
      cancellableUntil?.isAfter(DateTime.now().toUtc()) == true;

  factory DataRightsRequest.fromJson(Map value) {
    final row = Map<String, dynamic>.from(value);
    return DataRightsRequest(
      id: row['id'] as String,
      type: row['request_type'] as String,
      status: row['status'] as String,
      submittedAt: DateTime.parse(row['submitted_at'] as String).toUtc(),
      cancellableUntil: DateTime.tryParse(
        row['cancellable_until'] as String? ?? '',
      )?.toUtc(),
      scheduledFor: DateTime.tryParse(
        row['scheduled_for'] as String? ?? '',
      )?.toUtc(),
    );
  }
}

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
  Future<List<DataRightsRequest>> listRequests();
  Future<DataRightsRequest> requestAccountDeletion({required String password});
  Future<DataRightsRequest> cancelRequest(String requestId);
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

  @override
  Future<List<DataRightsRequest>> listRequests() async {
    final rows = await client
        .from('data_rights_requests')
        .select(
          'id,request_type,status,submitted_at,cancellable_until,scheduled_for',
        )
        .order('submitted_at', ascending: false)
        .limit(20);
    return rows.map(DataRightsRequest.fromJson).toList(growable: false);
  }

  @override
  Future<DataRightsRequest> requestAccountDeletion({
    required String password,
  }) async {
    final user = client.auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) throw StateError('再ログインが必要です。');
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.session == null) throw StateError('本人確認に失敗しました。');
    final row = Map<String, dynamic>.from(
      await client.rpc<Map<String, dynamic>>(
        'submit_data_rights_request',
        params: {
          'p_request_type': 'account_deletion',
          'p_scope': {
            'retention_exceptions': ['legal', 'security_audit'],
          },
          'p_idempotency_key':
              '${user.id}:${DateTime.now().toUtc().toIso8601String()}',
        },
      ),
    );
    return DataRightsRequest.fromJson(row);
  }

  @override
  Future<DataRightsRequest> cancelRequest(String requestId) async {
    final row = Map<String, dynamic>.from(
      await client.rpc<Map<String, dynamic>>(
        'cancel_my_data_rights_request',
        params: {'p_request_id': requestId},
      ),
    );
    return DataRightsRequest.fromJson(row);
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

  @override
  Future<List<DataRightsRequest>> listRequests() async => _unavailable();

  @override
  Future<DataRightsRequest> requestAccountDeletion({
    required String password,
  }) async => _unavailable();

  @override
  Future<DataRightsRequest> cancelRequest(String requestId) async =>
      _unavailable();
}

final dataRightsRepositoryProvider = Provider<DataRightsRepository>((ref) {
  return SupabaseConfig.isConfigured
      ? SupabaseDataRightsRepository(Supabase.instance.client)
      : const UnavailableDataRightsRepository();
});
