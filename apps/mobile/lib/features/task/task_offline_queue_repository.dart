import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'task_model.dart';
import 'task_mutation_state.dart';

final taskOfflineQueueRepositoryProvider = Provider<TaskOfflineQueueRepository>(
  (ref) => PersistedTaskOfflineQueueRepository(),
);

abstract interface class TaskOfflineQueueRepository {
  Future<PendingTaskMutation?> load(String ownerId);
  Future<void> save(String ownerId, PendingTaskMutation mutation);
  Future<void> clear(String ownerId);
}

class PersistedTaskOfflineQueueRepository
    implements TaskOfflineQueueRepository {
  PersistedTaskOfflineQueueRepository({
    FlutterSecureStorage? storage,
    DateTime Function()? clock,
    this._maxAge = const Duration(days: 7),
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _clock = clock ?? DateTime.now;

  static const _keyPrefix = 'questra_task_offline_queue_v2_';
  static const _maxEncodedBytes = 256 * 1024;
  final FlutterSecureStorage _storage;
  final DateTime Function() _clock;
  final Duration _maxAge;

  @override
  Future<PendingTaskMutation?> load(String ownerId) async {
    if (!_validOwner(ownerId)) return null;
    final storageKey = _key(ownerId);
    try {
      final encoded = await _storage.read(key: storageKey);
      if (encoded == null || encoded.length > _maxEncodedBytes) return null;
      final value = jsonDecode(encoded);
      if (value is! Map) return await _failClosed(storageKey);
      final row = Map<String, dynamic>.from(value);
      final storedAt = _date(row['storedAt']);
      if (row['version'] != 2 ||
          row['ownerId'] != ownerId ||
          storedAt == null ||
          _clock().toUtc().difference(storedAt.toUtc()) > _maxAge) {
        return await _failClosed(storageKey);
      }
      final desired = _taskList(row['desired']);
      final previous = _taskList(row['previous']);
      final key = row['idempotencyKey'] as String?;
      if (key == null ||
          key.isEmpty ||
          desired.isEmpty ||
          desired.length > 50) {
        return await _failClosed(storageKey);
      }
      return PendingTaskMutation(
        ownerId: ownerId,
        idempotencyKey: key,
        desired: desired,
        previous: previous,
        attempts: (row['attempts'] as int? ?? 0).clamp(0, 20),
        queuedAt: storedAt,
      );
    } catch (_) {
      return _failClosed(storageKey);
    }
  }

  @override
  Future<void> save(String ownerId, PendingTaskMutation mutation) async {
    if (!_validOwner(ownerId) ||
        ownerId != mutation.ownerId ||
        mutation.desired.isEmpty ||
        mutation.desired.length > 50) {
      throw ArgumentError('Task queue owner or batch is invalid.');
    }
    final storedAt = mutation.queuedAt ?? _clock();
    final encoded = jsonEncode({
      'version': 2,
      'ownerId': ownerId,
      'idempotencyKey': mutation.idempotencyKey,
      'attempts': mutation.attempts,
      'desired': mutation.desired.map(_taskToJson).toList(growable: false),
      'previous': mutation.previous.map(_taskToJson).toList(growable: false),
      'storedAt': storedAt.toUtc().toIso8601String(),
    });
    if (encoded.length > _maxEncodedBytes) {
      throw StateError('Task queue payload is too large.');
    }
    await _storage.write(key: _key(ownerId), value: encoded);
  }

  @override
  Future<void> clear(String ownerId) => _storage.delete(key: _key(ownerId));

  String _key(String ownerId) =>
      '$_keyPrefix${base64Url.encode(utf8.encode(ownerId))}';

  bool _validOwner(String ownerId) =>
      ownerId.isNotEmpty && ownerId.length <= 128;

  Future<PendingTaskMutation?> _failClosed(String key) async {
    await _storage.delete(key: key);
    return null;
  }

  List<QuestraTask> _taskList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => _taskFromJson(Map<String, dynamic>.from(row)))
            .toList(growable: false)
      : const [];

  Map<String, Object?> _taskToJson(QuestraTask task) => {
    'id': task.id,
    'questId': task.questId,
    'missionId': task.missionId,
    'questTitle': task.questTitle,
    'missionTitle': task.missionTitle,
    'title': task.title,
    'action': task.action,
    'purpose': task.purpose,
    'doneCondition': task.doneCondition,
    'expectedOutput': task.expectedOutput,
    'estimatedEffortMinutes': task.estimatedEffortMinutes,
    'status': task.status.storageKey,
    'required': task.required,
    'orderIndex': task.orderIndex,
    'dependencyIds': task.dependencyIds,
    'scheduledDate': task.scheduledDate?.toIso8601String(),
    'dueDate': task.dueDate?.toIso8601String(),
    'completedAt': task.completedAt?.toIso8601String(),
    'verificationType': task.verificationType.storageKey,
    'generatedBy': task.generatedBy.name,
    'generationVersion': task.generationVersion,
    'createdAt': task.createdAt.toIso8601String(),
    'updatedAt': task.updatedAt.toIso8601String(),
  };

  QuestraTask _taskFromJson(Map<String, dynamic> row) => QuestraTask(
    id: row['id'] as String,
    questId: row['questId'] as String,
    missionId: row['missionId'] as String,
    questTitle: row['questTitle'] as String? ?? '',
    missionTitle: row['missionTitle'] as String? ?? '',
    title: row['title'] as String,
    action: row['action'] as String,
    purpose: row['purpose'] as String? ?? '',
    doneCondition: row['doneCondition'] as String,
    expectedOutput: row['expectedOutput'] as String? ?? '',
    estimatedEffortMinutes: row['estimatedEffortMinutes'] as int?,
    status: taskStatusFromStorage(row['status'] as String? ?? 'pending'),
    required: row['required'] as bool? ?? true,
    orderIndex: row['orderIndex'] as int? ?? 0,
    dependencyIds:
        (row['dependencyIds'] as List?)?.whereType<String>().toList() ??
        const [],
    scheduledDate: _date(row['scheduledDate']),
    dueDate: _date(row['dueDate']),
    completedAt: _date(row['completedAt']),
    verificationType: taskVerificationTypeFromStorage(
      row['verificationType'] as String? ?? 'self',
    ),
    generatedBy: enumFromStorage(
      TaskGeneratedBy.values,
      row['generatedBy'] as String? ?? 'user',
      TaskGeneratedBy.user,
    ),
    generationVersion: row['generationVersion'] as String?,
    createdAt: _date(row['createdAt']) ?? DateTime.now(),
    updatedAt: _date(row['updatedAt']) ?? DateTime.now(),
  );

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;
}

class InMemoryTaskOfflineQueueRepository implements TaskOfflineQueueRepository {
  InMemoryTaskOfflineQueueRepository({
    DateTime Function()? clock,
    this._maxAge = const Duration(days: 7),
  }) : _clock = clock ?? DateTime.now;

  final Map<String, PendingTaskMutation> _entries = {};
  final DateTime Function() _clock;
  final Duration _maxAge;

  @override
  Future<PendingTaskMutation?> load(String ownerId) async {
    final entry = _entries[ownerId];
    if (entry?.queuedAt != null &&
        _clock().toUtc().difference(entry!.queuedAt!.toUtc()) > _maxAge) {
      _entries.remove(ownerId);
      return null;
    }
    return entry;
  }

  @override
  Future<void> save(String ownerId, PendingTaskMutation mutation) async {
    if (ownerId != mutation.ownerId) throw ArgumentError('owner mismatch');
    _entries[ownerId] = mutation;
  }

  @override
  Future<void> clear(String ownerId) async => _entries.remove(ownerId);
}
